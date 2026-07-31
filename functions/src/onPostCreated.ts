import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

/**
 * Truncates content to a maximum number of characters, appending "..." if truncated.
 */
function truncateContent(content: string, maxLength: number = 200): string {
  if (content.length <= maxLength) {
    return content;
  }
  return content.substring(0, maxLength) + "...";
}

/**
 * Creates a notification document in the /notifications collection.
 */
async function createNotification(params: {
  userId: string;
  type: string;
  activityId: string;
  title: string;
  body: string;
}): Promise<void> {
  await db.collection("notifications").add({
    userId: params.userId,
    type: params.type,
    activityId: params.activityId,
    title: params.title,
    body: params.body,
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * Cloud Function triggered on Firestore document creation at
 * `activities/{activityId}/posts/{postId}`.
 *
 * Behavior:
 * - Sends in-app notification to responsible users (excluding the post author)
 *   within 10 seconds.
 * - For Ask_Help posts, additionally sends notifications to all users in the
 *   target sectors within 30 seconds.
 * - Notification body includes truncated post content (max 200 chars).
 *
 * Validates: Requirements 6.5, 10.3, 10.5
 */
export const onPostCreated = functions.firestore
  .document("activities/{activityId}/posts/{postId}")
  .onCreate(async (snapshot, context) => {
    const postData = snapshot.data();
    const activityId = context.params.activityId;

    const content: string = postData.content ?? "";
    const category: string = postData.category ?? "";
    const authorId: string = postData.authorId ?? "";
    const targetSectors: string[] = postData.targetSectors ?? [];

    // Read parent activity document to get responsible users and title
    const activityDoc = await db
      .collection("activities")
      .doc(activityId)
      .get();

    if (!activityDoc.exists) {
      functions.logger.error(
        `Activity ${activityId} not found for post ${context.params.postId}`
      );
      return;
    }

    const activityData = activityDoc.data()!;
    const activityTitle: string = activityData.title ?? "Untitled Activity";
    const responsibleUsers: string[] = activityData.responsibleUsers ?? [];

    // Get the author's name for the notification
    const authorDoc = await db.collection("users").doc(authorId).get();
    const authorName: string = authorDoc.exists
      ? (authorDoc.data()!.nickname ?? "Unknown User")
      : "Unknown User";

    const truncatedContent = truncateContent(content, 200);

    // Build notification title and body per Requirement 10.5:
    // Include activity title, post content (truncated to max 200 chars), and author name
    const notificationTitle = `New post in "${activityTitle}"`;
    const notificationBody = `${authorName}: ${truncatedContent}`;

    // Send in-app notifications to responsible users, excluding the author
    // (Requirement 10.3: within 10 seconds)
    const recipientUsers = responsibleUsers.filter(
      (userId) => userId !== authorId
    );

    const notificationPromises = recipientUsers.map((userId) =>
      createNotification({
        userId,
        type: "discussion",
        activityId,
        title: notificationTitle,
        body: notificationBody,
      })
    );

    await Promise.all(notificationPromises);

    // For Ask_Help posts, send notifications to all users in target sectors
    // (Requirement 6.5: within 30 seconds)
    if (category === "Ask_Help" && targetSectors.length > 0) {
      const askHelpTitle = `Help requested in "${activityTitle}"`;
      const askHelpBody = `${authorName}: ${truncatedContent}`;

      // Query users in target sectors
      // Firestore 'in' queries support up to 10 values, which matches our
      // constraint of 1-10 target sectors
      const usersInSectorsSnapshot = await db
        .collection("users")
        .where("sectorId", "in", targetSectors)
        .get();

      const sectorNotificationPromises: Promise<void>[] = [];

      for (const userDoc of usersInSectorsSnapshot.docs) {
        const userId = userDoc.id;

        // Skip the author (don't notify yourself)
        if (userId === authorId) {
          continue;
        }

        // Skip users who already received a notification as responsible users
        if (recipientUsers.includes(userId)) {
          continue;
        }

        sectorNotificationPromises.push(
          createNotification({
            userId,
            type: "ask_help",
            activityId,
            title: askHelpTitle,
            body: askHelpBody,
          })
        );
      }

      await Promise.all(sectorNotificationPromises);
    }

    functions.logger.info(
      `Notifications sent for post ${context.params.postId} in activity ${activityId}`
    );
  });
