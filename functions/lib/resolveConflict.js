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
exports.resolveConflict = void 0;
exports.determineWinner = determineWinner;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
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
exports.resolveConflict = functions.pubsub
    .schedule("every 1 minutes")
    .onRun(async () => {
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
    const resolutionPromises = pendingConflictsSnap.docs.map(async (conflictDoc) => {
        const conflictId = conflictDoc.id;
        const conflictData = conflictDoc.data();
        try {
            const shouldResolve = await checkShouldResolve(conflictData, now);
            if (shouldResolve) {
                await performResolution(conflictId, conflictData);
            }
        }
        catch (error) {
            functions.logger.error("Error resolving conflict", {
                conflictId,
                error,
            });
        }
    });
    await Promise.all(resolutionPromises);
});
/**
 * Determines whether a conflict should be resolved based on quorum or deadline.
 */
async function checkShouldResolve(conflictData, now) {
    const { activityId, votingDeadline, votes } = conflictData;
    // Check if deadline has passed
    const deadline = votingDeadline;
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
    const activityData = activitySnap.data();
    const responsibleUsers = activityData.responsibleUsers || [];
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
async function performResolution(conflictId, conflictData) {
    const { activityId, fieldPath, versions, votes } = conflictData;
    // Determine the winning version
    const { winningVersion, resolutionMethod } = determineWinner(versions || [], votes || {});
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
        const activityUpdate = {
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
    const responsibleUsers = (activityData === null || activityData === void 0 ? void 0 : activityData.responsibleUsers) || [];
    const activityTitle = (activityData === null || activityData === void 0 ? void 0 : activityData.title) || "Untitled Activity";
    const notificationPromises = responsibleUsers.map((userId) => {
        return db.collection("notifications").add({
            userId,
            type: "conflict_resolved",
            activityId,
            title: "Conflict Resolved",
            body: buildResolutionNotificationBody(activityTitle, fieldPath, resolutionMethod, winningVersion.authorId),
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
 * Determines the winning version based on vote counts and timestamps.
 *
 * Resolution rules (Req 13.7, 13.8, 13.9):
 * - Version with the most votes wins (consensus)
 * - If no votes cast, version with most recent timestamp wins (fallback)
 * - If tied votes, version with most recent timestamp among tied wins (consensus)
 */
function determineWinner(versions, votes) {
    if (!versions || versions.length === 0) {
        return { winningVersion: null, resolutionMethod: "fallback" };
    }
    const voteEntries = Object.values(votes);
    // If no votes cast, apply fallback: most recent modification timestamp
    if (voteEntries.length === 0) {
        const sorted = [...versions].sort((a, b) => {
            return getTimestampMillis(b.modifiedAt) - getTimestampMillis(a.modifiedAt);
        });
        return { winningVersion: sorted[0], resolutionMethod: "fallback" };
    }
    // Count votes per version
    const voteCounts = {};
    for (const versionId of voteEntries) {
        voteCounts[versionId] = (voteCounts[versionId] || 0) + 1;
    }
    // Find the maximum vote count
    const maxVotes = Math.max(...Object.values(voteCounts));
    // Get all versions with the max vote count
    const tiedVersionIds = Object.entries(voteCounts)
        .filter(([, count]) => count === maxVotes)
        .map(([versionId]) => versionId);
    // If only one version has the max votes, it wins (consensus)
    if (tiedVersionIds.length === 1) {
        const winner = versions.find((v) => v.versionId === tiedVersionIds[0]);
        return { winningVersion: winner || null, resolutionMethod: "consensus" };
    }
    // Tie-break: among tied versions, pick the one with most recent timestamp
    const tiedVersions = versions.filter((v) => tiedVersionIds.includes(v.versionId));
    const sorted = [...tiedVersions].sort((a, b) => {
        return getTimestampMillis(b.modifiedAt) - getTimestampMillis(a.modifiedAt);
    });
    return { winningVersion: sorted[0], resolutionMethod: "consensus" };
}
/**
 * Extracts milliseconds from a Firestore Timestamp or plain object.
 */
function getTimestampMillis(ts) {
    if (ts instanceof admin.firestore.Timestamp) {
        return ts.toMillis();
    }
    // Handle serialized timestamp objects
    if (ts && typeof ts === "object" && "_seconds" in ts) {
        const obj = ts;
        return obj._seconds * 1000 + Math.floor(obj._nanoseconds / 1000000);
    }
    // Handle Date objects or numeric timestamps
    if (ts instanceof Date) {
        return ts.getTime();
    }
    if (typeof ts === "number") {
        return ts;
    }
    return 0;
}
/**
 * Builds notification body text for conflict resolution.
 */
function buildResolutionNotificationBody(activityTitle, fieldPath, resolutionMethod, winningAuthorId) {
    const methodDescription = resolutionMethod === "consensus"
        ? "majority vote (consensus)"
        : "most recent timestamp (fallback)";
    return (`The conflict on "${activityTitle}" for field "${fieldPath}" ` +
        `has been resolved by ${methodDescription}. ` +
        `The version by user "${winningAuthorId}" was applied.`);
}
//# sourceMappingURL=resolveConflict.js.map