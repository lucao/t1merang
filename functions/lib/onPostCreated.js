"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.onPostCreated = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();
/**
 * Truncates content to a maximum number of characters, appending "..." if truncated.
 */
function truncateContent(content, maxLength = 200) {
    if (content.length <= maxLength) {
        return content;
    }
    return content.substring(0, maxLength) + "...";
}
/**
 * Creates a notification document in the /notifications collection.
 */
async function createNotification(params) {
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
exports.onPostCreated = functions.firestore
    .document("activities/{activityId}/posts/{postId}")
    .onCreate(async (snapshot, context) => {
    var _a, _b, _c, _d, _e, _f, _g;
    const postData = snapshot.data();
    const activityId = context.params.activityId;
    const content = (_a = postData.content) !== null && _a !== void 0 ? _a : "";
    const category = (_b = postData.category) !== null && _b !== void 0 ? _b : "";
    const authorId = (_c = postData.authorId) !== null && _c !== void 0 ? _c : "";
    const targetSectors = (_d = postData.targetSectors) !== null && _d !== void 0 ? _d : [];
    // Read parent activity document to get responsible users and title
    const activityDoc = await db
        .collection("activities")
        .doc(activityId)
        .get();
    if (!activityDoc.exists) {
        functions.logger.error(`Activity ${activityId} not found for post ${context.params.postId}`);
        return;
    }
    const activityData = activityDoc.data();
    const activityTitle = (_e = activityData.title) !== null && _e !== void 0 ? _e : "Untitled Activity";
    const responsibleUsers = (_f = activityData.responsibleUsers) !== null && _f !== void 0 ? _f : [];
    // Get the author's name for the notification
    const authorDoc = await db.collection("users").doc(authorId).get();
    const authorName = authorDoc.exists
        ? ((_g = authorDoc.data().nickname) !== null && _g !== void 0 ? _g : "Unknown User")
        : "Unknown User";
    const truncatedContent = truncateContent(content, 200);
    // Build notification title and body per Requirement 10.5:
    // Include activity title, post content (truncated to max 200 chars), and author name
    const notificationTitle = `New post in "${activityTitle}"`;
    const notificationBody = `${authorName}: ${truncatedContent}`;
    // Send in-app notifications to responsible users, excluding the author
    // (Requirement 10.3: within 10 seconds)
    const recipientUsers = responsibleUsers.filter((userId) => userId !== authorId);
    const notificationPromises = recipientUsers.map((userId) => createNotification({
        userId,
        type: "discussion",
        activityId,
        title: notificationTitle,
        body: notificationBody,
    }));
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
        const sectorNotificationPromises = [];
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
            sectorNotificationPromises.push(createNotification({
                userId,
                type: "ask_help",
                activityId,
                title: askHelpTitle,
                body: askHelpBody,
            }));
        }
        await Promise.all(sectorNotificationPromises);
    }
    functions.logger.info(`Notifications sent for post ${context.params.postId} in activity ${activityId}`);
});
//# sourceMappingURL=onPostCreated.js.map