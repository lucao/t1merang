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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
var _a, _b, _c, _d;
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendEmailNotification = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const mail_1 = __importDefault(require("@sendgrid/mail"));
// Initialize SendGrid with API key from Firebase config
const SENDGRID_API_KEY = (_b = (_a = functions.config().sendgrid) === null || _a === void 0 ? void 0 : _a.key) !== null && _b !== void 0 ? _b : "";
mail_1.default.setApiKey(SENDGRID_API_KEY);
const MAX_ATTEMPTS = 3;
const FROM_EMAIL = (_d = (_c = functions.config().sendgrid) === null || _c === void 0 ? void 0 : _c.from) !== null && _d !== void 0 ? _d : "noreply@t1merang.app";
/**
 * Cloud Function triggered by Firestore writes to /emailQueue/{emailId}.
 * Sends email via SendGrid with retry logic (up to 3 attempts).
 *
 * On success: sets status to 'sent'
 * On failure: increments attempts, sets lastAttemptAt.
 *   If attempts >= 3, sets status to 'failed'.
 *
 * Validates: Requirements 10.1, 10.6
 */
exports.sendEmailNotification = functions.firestore
    .document("emailQueue/{emailId}")
    .onWrite(async (change, context) => {
    const emailId = context.params.emailId;
    const snapshot = change.after;
    // If document was deleted, nothing to do
    if (!snapshot.exists) {
        return null;
    }
    const data = snapshot.data();
    // Only process emails that are pending
    if (data.status !== "pending") {
        return null;
    }
    // If max attempts reached, mark as failed
    if (data.attempts >= MAX_ATTEMPTS) {
        await snapshot.ref.update({
            status: "failed",
        });
        functions.logger.error(`Email ${emailId} failed after ${MAX_ATTEMPTS} attempts`);
        return null;
    }
    // Check retry interval: if lastAttemptAt exists and less than 1 minute ago, skip
    if (data.lastAttemptAt) {
        const lastAttempt = data.lastAttemptAt.toDate();
        const now = new Date();
        const elapsedMs = now.getTime() - lastAttempt.getTime();
        if (elapsedMs < 60000) {
            // Less than 1 minute since last attempt, skip processing
            return null;
        }
    }
    try {
        await mail_1.default.send({
            to: data.to,
            from: FROM_EMAIL,
            subject: data.subject,
            html: data.htmlBody,
        });
        // Success: update status to 'sent'
        await snapshot.ref.update({
            status: "sent",
            lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
            attempts: admin.firestore.FieldValue.increment(1),
        });
        functions.logger.info(`Email ${emailId} sent successfully`);
    }
    catch (error) {
        const newAttempts = data.attempts + 1;
        const updateData = {
            attempts: newAttempts,
            lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        // If this was the last attempt, mark as failed
        if (newAttempts >= MAX_ATTEMPTS) {
            updateData.status = "failed";
            functions.logger.error(`Email ${emailId} permanently failed after ${MAX_ATTEMPTS} attempts`, error);
        }
        else {
            functions.logger.warn(`Email ${emailId} attempt ${newAttempts} failed, will retry`, error);
        }
        await snapshot.ref.update(updateData);
    }
    return null;
});
//# sourceMappingURL=sendEmailNotification.js.map