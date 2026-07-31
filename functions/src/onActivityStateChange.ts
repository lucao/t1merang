import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Initialize admin SDK if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

interface ActivityData {
  title: string;
  currentStateId: string;
  sectorId: string;
  createdAt: admin.firestore.Timestamp;
  createdBy: string;
  lastModifiedAt: admin.firestore.Timestamp;
  lastModifiedBy: string;
  stateEnteredAt: admin.firestore.Timestamp;
  responsibleUsers: string[];
  isConflicted: boolean;
  version: number;
}

interface TimelineEntryData {
  fromStateId: string;
  toStateId: string;
  transitionedAt: admin.firestore.Timestamp;
  transitionedBy: string;
  durationMinutes: number;
}

interface NotificationData {
  userId: string;
  type: string;
  activityId: string;
  title: string;
  body: string;
  read: boolean;
  createdAt: admin.firestore.Timestamp;
}

interface EmailQueueData {
  to: string;
  subject: string;
  htmlBody: string;
  status: string;
  attempts: number;
  lastAttemptAt: admin.firestore.Timestamp | null;
  createdAt: admin.firestore.Timestamp;
}

interface ConflictData {
  activityId: string;
  fieldPath: string;
  status: string;
  createdAt: admin.firestore.Timestamp;
  votingDeadline: admin.firestore.Timestamp;
  versions: ConflictVersionData[];
  votes: Record<string, string>;
}

interface ConflictVersionData {
  versionId: string;
  value: unknown;
  authorId: string;
  modifiedAt: admin.firestore.Timestamp;
}

/**
 * Cloud Function triggered on Firestore `activities/{activityId}` update.
 *
 * Responsibilities:
 * - Detect state changes by comparing before/after snapshots
 * - Calculate duration for the previous state and create a timeline entry
 * - Check for version conflicts (optimistic concurrency violation)
 * - Create in-app notifications for responsible users (within 10 seconds)
 * - Queue email notifications (within 5 minutes)
 *
 * Requirements: 3.2, 3.4, 3.5, 5.1, 10.1, 10.2, 10.4
 */
export const onActivityStateChange = functions.firestore
  .document("activities/{activityId}")
  .onUpdate(async (change, context) => {
    const activityId = context.params.activityId;
    const beforeData = change.before.data() as ActivityData;
    const afterData = change.after.data() as ActivityData;

    // Check for version conflict (optimistic concurrency violation)
    if (detectVersionConflict(beforeData, afterData)) {
      await handleConflict(activityId, beforeData, afterData);
      return;
    }

    // Detect if currentStateId changed
    if (beforeData.currentStateId === afterData.currentStateId) {
      // No state change — nothing to do for this function
      return;
    }

    const now = admin.firestore.Timestamp.now();

    // Calculate duration for the previous state (Requirement 5.1)
    const durationMinutes = calculateDurationMinutes(
      beforeData.stateEnteredAt,
      afterData.lastModifiedAt
    );

    // Create timeline entry (Requirement 3.2)
    const timelineEntry: TimelineEntryData = {
      fromStateId: beforeData.currentStateId,
      toStateId: afterData.currentStateId,
      transitionedAt: afterData.lastModifiedAt,
      transitionedBy: afterData.lastModifiedBy,
      durationMinutes,
    };

    await db
      .collection("activities")
      .doc(activityId)
      .collection("timeline")
      .add(timelineEntry);

    // Determine notification recipients: all responsible users except the mover
    // (Requirements 3.4, 10.1, 10.2)
    const actingUser = afterData.lastModifiedBy;
    const recipients = afterData.responsibleUsers.filter(
      (userId) => userId !== actingUser
    );

    if (recipients.length === 0) {
      return;
    }

    // Fetch state names for notification content
    const [fromStateName, toStateName, actingUserName] = await Promise.all([
      getStateName(beforeData.currentStateId),
      getStateName(afterData.currentStateId),
      getUserName(actingUser),
    ]);

    // Build notification content (Requirement 10.4)
    const notificationTitle = `Activity moved: ${afterData.title}`;
    const notificationBody =
      `${actingUserName} moved "${afterData.title}" ` +
      `from ${fromStateName} to ${toStateName}`;

    // Create in-app notifications for all recipients (Requirement 3.4, 10.2)
    const notificationBatch = db.batch();
    for (const recipientId of recipients) {
      const notificationRef = db.collection("notifications").doc();
      const notification: NotificationData = {
        userId: recipientId,
        type: "state_change",
        activityId,
        title: notificationTitle,
        body: notificationBody,
        read: false,
        createdAt: now,
      };
      notificationBatch.set(notificationRef, notification);
    }
    await notificationBatch.commit();

    // Queue email notifications for all recipients (Requirement 3.5, 10.1)
    const emailBatch = db.batch();
    for (const recipientId of recipients) {
      const email = await getUserEmail(recipientId);
      if (!email) continue;

      const emailRef = db.collection("emailQueue").doc();
      const emailData: EmailQueueData = {
        to: email,
        subject: notificationTitle,
        htmlBody: buildEmailHtml(
          afterData.title,
          fromStateName,
          toStateName,
          actingUserName
        ),
        status: "pending",
        attempts: 0,
        lastAttemptAt: null,
        createdAt: now,
      };
      emailBatch.set(emailRef, emailData);
    }
    await emailBatch.commit();

    functions.logger.info(
      `State change processed for activity ${activityId}: ` +
        `${fromStateName} -> ${toStateName}, ` +
        `${recipients.length} users notified`
    );
  });

/**
 * Calculate duration in minutes (floor) between two timestamps.
 * Implements: floor((exit - entry) / 60 seconds)
 * Requirement 5.1
 */
function calculateDurationMinutes(
  entryTimestamp: admin.firestore.Timestamp,
  exitTimestamp: admin.firestore.Timestamp
): number {
  const entrySeconds = entryTimestamp.seconds;
  const exitSeconds = exitTimestamp.seconds;
  const diffSeconds = exitSeconds - entrySeconds;
  return Math.floor(diffSeconds / 60);
}

/**
 * Detect version conflict (optimistic concurrency violation).
 * A conflict is detected when the version increment is greater than 1,
 * indicating another write happened concurrently.
 */
function detectVersionConflict(
  before: ActivityData,
  after: ActivityData
): boolean {
  // A version conflict occurs when the version jumps by more than 1,
  // or when two writers both wrote to the same version
  return after.version - before.version > 1;
}

/**
 * Handle a detected conflict by creating a conflict document
 * and marking the activity as conflicted.
 */
async function handleConflict(
  activityId: string,
  before: ActivityData,
  after: ActivityData
): Promise<void> {
  const now = admin.firestore.Timestamp.now();

  // Default voting window: 24 hours
  const votingDeadline = admin.firestore.Timestamp.fromMillis(
    now.toMillis() + 24 * 60 * 60 * 1000
  );

  const conflictData: ConflictData = {
    activityId,
    fieldPath: "currentStateId",
    status: "pending",
    createdAt: now,
    votingDeadline,
    versions: [
      {
        versionId: `v${before.version}`,
        value: before.currentStateId,
        authorId: before.lastModifiedBy,
        modifiedAt: before.lastModifiedAt,
      },
      {
        versionId: `v${after.version}`,
        value: after.currentStateId,
        authorId: after.lastModifiedBy,
        modifiedAt: after.lastModifiedAt,
      },
    ],
    votes: {},
  };

  // Create conflict document
  await db.collection("conflicts").add(conflictData);

  // Mark activity as conflicted
  await db.collection("activities").doc(activityId).update({
    isConflicted: true,
  });

  // Notify responsible users about the conflict
  const recipients = after.responsibleUsers;
  const notificationBatch = db.batch();
  for (const recipientId of recipients) {
    const notificationRef = db.collection("notifications").doc();
    const notification: NotificationData = {
      userId: recipientId,
      type: "conflict",
      activityId,
      title: `Conflict detected: ${after.title}`,
      body: `A conflict has been detected on "${after.title}". Please vote to resolve.`,
      read: false,
      createdAt: now,
    };
    notificationBatch.set(notificationRef, notification);
  }
  await notificationBatch.commit();

  functions.logger.warn(
    `Version conflict detected for activity ${activityId}. ` +
      `Conflict document created.`
  );
}

/**
 * Fetch a state name by its ID.
 */
async function getStateName(stateId: string): Promise<string> {
  const stateDoc = await db.collection("states").doc(stateId).get();
  if (stateDoc.exists) {
    return stateDoc.data()?.name || stateId;
  }
  return stateId;
}

/**
 * Fetch a user's display name (nickname) by their ID.
 */
async function getUserName(userId: string): Promise<string> {
  const userDoc = await db.collection("users").doc(userId).get();
  if (userDoc.exists) {
    return userDoc.data()?.nickname || userId;
  }
  return userId;
}

/**
 * Fetch a user's email by their ID.
 */
async function getUserEmail(userId: string): Promise<string | null> {
  const userDoc = await db.collection("users").doc(userId).get();
  if (userDoc.exists) {
    return userDoc.data()?.email || null;
  }
  return null;
}

/**
 * Build HTML content for email notification.
 * Includes activity title, previous state, new state, and acting user name.
 * Requirement 10.4
 */
function buildEmailHtml(
  activityTitle: string,
  fromState: string,
  toState: string,
  actingUserName: string
): string {
  return `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
      <h2 style="color: #333;">Activity State Changed</h2>
      <p><strong>Activity:</strong> ${escapeHtml(activityTitle)}</p>
      <p><strong>Moved by:</strong> ${escapeHtml(actingUserName)}</p>
      <p><strong>From:</strong> ${escapeHtml(fromState)}</p>
      <p><strong>To:</strong> ${escapeHtml(toState)}</p>
      <hr style="border: none; border-top: 1px solid #eee;" />
      <p style="color: #666; font-size: 12px;">
        This notification was sent by Activity Tracker.
      </p>
    </div>
  `.trim();
}

/**
 * Escape HTML special characters to prevent XSS in email content.
 */
function escapeHtml(text: string): string {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}
