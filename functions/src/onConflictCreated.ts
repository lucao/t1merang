import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

/**
 * Triggered when a new conflict document is created in /conflicts/{conflictId}.
 *
 * Responsibilities:
 * - Lock the conflicting activity field (set isConflicted = true)
 * - Notify all responsible users of the affected activity
 * - Log the conflict creation to the auditLog collection
 *
 * Requirements: 13.4, 13.5, 13.10, 13.12
 */
export const onConflictCreated = functions.firestore
  .document("conflicts/{conflictId}")
  .onCreate(async (snapshot, context) => {
    const db = admin.firestore();
    const conflictId = context.params.conflictId;
    const conflictData = snapshot.data();

    if (!conflictData) {
      functions.logger.error("No data in conflict document", { conflictId });
      return;
    }

    const {
      activityId,
      fieldPath,
      versions,
      votingDeadline,
    } = conflictData;

    if (!activityId) {
      functions.logger.error("Missing activityId in conflict", { conflictId });
      return;
    }

    try {
      // 1. Lock the activity field by setting isConflicted = true (Req 13.10)
      const activityRef = db.collection("activities").doc(activityId);
      const activitySnap = await activityRef.get();

      if (!activitySnap.exists) {
        functions.logger.error("Activity not found for conflict", {
          conflictId,
          activityId,
        });
        return;
      }

      await activityRef.update({ isConflicted: true });

      // 2. Notify responsible users of the conflict (Req 13.5)
      const activityData = activitySnap.data()!;
      const responsibleUsers: string[] = activityData.responsibleUsers || [];
      const activityTitle: string = activityData.title || "Untitled Activity";

      const notificationPromises = responsibleUsers.map((userId) => {
        return db.collection("notifications").add({
          userId,
          type: "conflict",
          activityId,
          title: "Conflict Detected",
          body: buildConflictNotificationBody(
            activityTitle,
            fieldPath,
            versions
          ),
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      await Promise.all(notificationPromises);

      // 3. Log the conflict creation to auditLog (Req 13.12)
      await db.collection("auditLog").add({
        type: "conflict_created",
        conflictId,
        activityId,
        userId: null,
        details: {
          fieldPath,
          versionsCount: versions ? versions.length : 0,
          votingDeadline,
          responsibleUsersNotified: responsibleUsers.length,
        },
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      functions.logger.info("Conflict created and processed", {
        conflictId,
        activityId,
        notifiedUsers: responsibleUsers.length,
      });
    } catch (error) {
      functions.logger.error("Error processing conflict creation", {
        conflictId,
        error,
      });
      throw error;
    }
  });

/**
 * Builds the notification body for a conflict notification.
 */
function buildConflictNotificationBody(
  activityTitle: string,
  fieldPath: string,
  versions: Array<{ authorId: string; modifiedAt: unknown }> | undefined
): string {
  const versionCount = versions ? versions.length : 0;
  return (
    `A conflict has been detected on "${activityTitle}" ` +
    `for field "${fieldPath}" with ${versionCount} conflicting version(s). ` +
    `Please review and cast your vote.`
  );
}
