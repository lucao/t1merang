import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

/**
 * Scheduled Cloud Function that runs daily to archive activities
 * that have been in a Production-type state longer than the
 * configured threshold.
 *
 * - Queries /states/ for states with `productionThresholdDays` configured
 * - For each such state, queries activities where `stateEnteredAt` is older
 *   than the threshold
 * - Archives expired activities by moving them to an `archivedActivities`
 *   collection and removing them from `activities`
 *
 * Validates: Requirement 4.7
 */
export const cleanupProductionState = functions.pubsub
  .schedule("every 24 hours")
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();

    // 1. Query all states that have a productionThresholdDays configured
    const statesSnapshot = await db
      .collection("states")
      .where("productionThresholdDays", ">", 0)
      .get();

    if (statesSnapshot.empty) {
      functions.logger.info(
        "No production-type states with threshold configured. Skipping cleanup."
      );
      return null;
    }

    let totalArchived = 0;

    for (const stateDoc of statesSnapshot.docs) {
      const stateData = stateDoc.data();
      const stateId = stateDoc.id;
      const thresholdDays = getValidThreshold(stateData.productionThresholdDays);

      // Calculate the cutoff timestamp
      const cutoffDate = new Date(
        now.toDate().getTime() - thresholdDays * 24 * 60 * 60 * 1000
      );
      const cutoffTimestamp = admin.firestore.Timestamp.fromDate(cutoffDate);

      functions.logger.info(
        `Processing state "${stateData.name}" (${stateId}) ` +
        `with threshold ${thresholdDays} days. ` +
        `Archiving activities entered before ${cutoffDate.toISOString()}.`
      );

      // 2. Query activities in this state that are older than the threshold
      const expiredActivitiesSnapshot = await db
        .collection("activities")
        .where("currentStateId", "==", stateId)
        .where("stateEnteredAt", "<", cutoffTimestamp)
        .get();

      if (expiredActivitiesSnapshot.empty) {
        functions.logger.info(
          `No expired activities found for state "${stateData.name}".`
        );
        continue;
      }

      // 3. Archive expired activities in batches (Firestore limit: 500 per batch)
      const batchSize = 500;
      const docs = expiredActivitiesSnapshot.docs;

      for (let i = 0; i < docs.length; i += batchSize) {
        const batch = db.batch();
        const chunk = docs.slice(i, i + batchSize);

        for (const activityDoc of chunk) {
          const activityData = activityDoc.data();

          // Write to archive collection
          const archiveRef = db
            .collection("archivedActivities")
            .doc(activityDoc.id);
          batch.set(archiveRef, {
            ...activityData,
            archivedAt: now,
            archivedFromStateId: stateId,
          });

          // Remove from activities collection
          batch.delete(activityDoc.ref);
        }

        await batch.commit();
        totalArchived += chunk.length;

        functions.logger.info(
          `Archived ${chunk.length} activities from state "${stateData.name}".`
        );
      }
    }

    functions.logger.info(
      `Cleanup complete. Total activities archived: ${totalArchived}.`
    );
    return null;
  });

/**
 * Validates and clamps the threshold value to the allowed range (1-365 days).
 * Defaults to 30 if the value is invalid.
 */
function getValidThreshold(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return 30;
  }
  const clamped = Math.floor(value);
  if (clamped < 1) return 1;
  if (clamped > 365) return 365;
  return clamped;
}
