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
exports.onConflictCreated = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
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
exports.onConflictCreated = functions.firestore
    .document("conflicts/{conflictId}")
    .onCreate(async (snapshot, context) => {
    const conflictId = context.params.conflictId;
    const conflictData = snapshot.data();
    if (!conflictData) {
        functions.logger.error("No data in conflict document", { conflictId });
        return;
    }
    const { activityId, fieldPath, versions, votingDeadline, } = conflictData;
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
        const activityData = activitySnap.data();
        const responsibleUsers = activityData.responsibleUsers || [];
        const activityTitle = activityData.title || "Untitled Activity";
        const notificationPromises = responsibleUsers.map((userId) => {
            return db.collection("notifications").add({
                userId,
                type: "conflict",
                activityId,
                title: "Conflict Detected",
                body: buildConflictNotificationBody(activityTitle, fieldPath, versions),
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
    }
    catch (error) {
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
function buildConflictNotificationBody(activityTitle, fieldPath, versions) {
    const versionCount = versions ? versions.length : 0;
    return (`A conflict has been detected on "${activityTitle}" ` +
        `for field "${fieldPath}" with ${versionCount} conflicting version(s). ` +
        `Please review and cast your vote.`);
}
//# sourceMappingURL=onConflictCreated.js.map