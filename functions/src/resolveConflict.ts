import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { determineWinner } from "./conflictResolutionLogic";

// Re-export for backwards compatibility
export { determineWinner } from "./conflictResolutionLogic";

/**
 * Scheduled function that runs every minute to check and resolve pending conflicts.
 *
 * Resolution logic:
 * - Check all pending conflicts where the voting deadline has passed OR quorum is reached
 * - Quorum = more than 50% of responsible users have voted
 * - Apply the version with the most votes (majority wins)
 * - If no votes cast, apply the version with the most recent modification timestamp (fallback)
 * - If tied votes, apply the tied version with the most recent modification timestamp
 * - Unlock the activity (set isConflicted = false)
 * - Notify all responsible users of the resolution
 * - Log the resolution to auditLog
 *
 * Requirements: 13.7, 13.8, 13.9, 13.11, 13.12
 */
export const resolveConflict = functions.pubsub
  .schedule("every 1 minutes")
  .onRun(async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    // Query all pending conflicts
    const pendingConflictsSnap = await db
      .collection("conflicts")
      .where("status", "==", "pending")
      .get();

    if (pendingConflictsSnap.empty) {
      functions.logger.info("No pending conflicts to resolve");
      return;
    }

    const resolutionPromises = pendingConflictsSnap.docs.map(
      async (conflictDoc) => {
        const conflictId = conflictDoc.id;
        const conflictData = conflictDoc.data();

        try {
          const shouldResolve = await checkShouldResolve(
            db,
            conflictData,
            now
          );

          if (shouldResolve) {
            await performResolution(db, conflictId, conflictData);
          }
        } catch (error) {
          functions.logger.error("Error resolving conflict", {
            conflictId,
            error,
          });
        }
      }
    );

    await Promise.all(resolutionPromises);
  });

/**
 * Determines whether a conflict should be resolved based on quorum or deadline.
 */
async function checkShouldResolve(
  db: admin.firestore.Firestore,
  conflictData: admin.firestore.DocumentData,
  now: admin.firestore.Timestamp
): Promise<boolean> {
  const { activityId, votingDeadline, votes } = conflictData;

  // Check if deadline has passed
  const deadline = votingDeadline as admin.firestore.Timestamp;
  if (deadline && now.toMillis() >= deadline.toMillis()) {
    return true;
  }

  // Check if quorum is reached (>50% of responsible users voted)
  const activityRef = db.collection("activities").doc(activityId);
  const activitySnap = await activityRef.get();

  if (!activitySnap.exists) {
    // Activity no longer exists, resolve to clean up
    return true;
  }

  const activityData = activitySnap.data()!;
  const responsibleUsers: string[] = activityData.responsibleUsers || [];
  const voteCount = votes ? Object.keys(votes).length : 0;
  const quorum = Math.floor(responsibleUsers.length / 2) + 1;

  return voteCount >= quorum;
}

/**
 * Performs the actual conflict resolution:
 * - Determines the winning version
 * - Applies the winning value to the activity
 * - Unlocks the activity
 * - Notifies responsible users
 * - Logs to auditLog
 */
async function performResolution(
  db: admin.firestore.Firestore,
  conflictId: string,
  conflictData: admin.firestore.DocumentData
): Promise<void> {
  const { activityId, fieldPath, versions, votes } = conflictData;

  // Determine the winning version
  const { winningVersion, resolutionMethod } = determineWinner(
    versions || [],
    votes || {}
  );

  if (!winningVersion) {
    functions.logger.error("Could not determine winning version", {
      conflictId,
    });
    return;
  }

  // Apply resolution in a transaction
  await db.runTransaction(async (transaction) => {
    const conflictRef = db.collection("conflicts").doc(conflictId);
    const activityRef = db.collection("activities").doc(activityId);

    // Update the conflict document as resolved
    transaction.update(conflictRef, {
      status: "resolved",
      resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
      resolutionMethod,
    });

    // Apply the winning version to the activity and unlock it
    const activityUpdate: Record<string, unknown> = {
      isConflicted: false,
      lastModifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    // Apply the winning value to the specific field
    if (fieldPath) {
      activityUpdate[fieldPath] = winningVersion.value;
    }

    transaction.update(activityRef, activityUpdate);
  });

  // Notify responsible users about the resolution (Req 13.11)
  const activitySnap = await db.collection("activities").doc(activityId).get();
  const activityData = activitySnap.data();
  const responsibleUsers: string[] = activityData?.responsibleUsers || [];
  const activityTitle: string = activityData?.title || "Untitled Activity";

  const notificationPromises = responsibleUsers.map((userId) => {
    return db.collection("notifications").add({
      userId,
      type: "conflict_resolved",
      activityId,
      title: "Conflict Resolved",
      body: buildResolutionNotificationBody(
        activityTitle,
        fieldPath,
        resolutionMethod,
        winningVersion.authorId
      ),
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  await Promise.all(notificationPromises);

  // Log the resolution to auditLog (Req 13.12)
  await db.collection("auditLog").add({
    type: "conflict_resolved",
    conflictId,
    activityId,
    userId: null,
    details: {
      fieldPath,
      resolutionMethod,
      winningVersionId: winningVersion.versionId,
      winningAuthorId: winningVersion.authorId,
      totalVotes: votes ? Object.keys(votes).length : 0,
    },
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  functions.logger.info("Conflict resolved", {
    conflictId,
    activityId,
    resolutionMethod,
    winningVersionId: winningVersion.versionId,
  });
}

/**
 * Builds notification body text for conflict resolution.
 */
function buildResolutionNotificationBody(
  activityTitle: string,
  fieldPath: string,
  resolutionMethod: "consensus" | "fallback",
  winningAuthorId: string
): string {
  const methodDescription =
    resolutionMethod === "consensus"
      ? "majority vote (consensus)"
      : "most recent timestamp (fallback)";

  return (
    `The conflict on "${activityTitle}" for field "${fieldPath}" ` +
    `has been resolved by ${methodDescription}. ` +
    `The version by user "${winningAuthorId}" was applied.`
  );
}
