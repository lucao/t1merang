import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import sgMail from "@sendgrid/mail";

// Initialize SendGrid with API key from Firebase config
const SENDGRID_API_KEY = functions.config().sendgrid?.key ?? "";
sgMail.setApiKey(SENDGRID_API_KEY);

const MAX_ATTEMPTS = 3;
const FROM_EMAIL = functions.config().sendgrid?.from ?? "noreply@t1merang.app";

interface EmailQueueDocument {
  to: string;
  subject: string;
  htmlBody: string;
  status: "pending" | "sent" | "failed";
  attempts: number;
  lastAttemptAt: admin.firestore.Timestamp | null;
  createdAt: admin.firestore.Timestamp;
}

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
export const sendEmailNotification = functions.firestore
  .document("emailQueue/{emailId}")
  .onWrite(async (change, context) => {
    const emailId = context.params.emailId;
    const snapshot = change.after;

    // If document was deleted, nothing to do
    if (!snapshot.exists) {
      return null;
    }

    const data = snapshot.data() as EmailQueueDocument;

    // Only process emails that are pending
    if (data.status !== "pending") {
      return null;
    }

    // If max attempts reached, mark as failed
    if (data.attempts >= MAX_ATTEMPTS) {
      await snapshot.ref.update({
        status: "failed",
      });
      functions.logger.error(
        `Email ${emailId} failed after ${MAX_ATTEMPTS} attempts`
      );
      return null;
    }

    // Check retry interval: if lastAttemptAt exists and less than 1 minute ago, skip
    if (data.lastAttemptAt) {
      const lastAttempt = data.lastAttemptAt.toDate();
      const now = new Date();
      const elapsedMs = now.getTime() - lastAttempt.getTime();
      if (elapsedMs < 60_000) {
        // Less than 1 minute since last attempt, skip processing
        return null;
      }
    }

    try {
      await sgMail.send({
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
    } catch (error) {
      const newAttempts = data.attempts + 1;

      const updateData: Record<string, unknown> = {
        attempts: newAttempts,
        lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      // If this was the last attempt, mark as failed
      if (newAttempts >= MAX_ATTEMPTS) {
        updateData.status = "failed";
        functions.logger.error(
          `Email ${emailId} permanently failed after ${MAX_ATTEMPTS} attempts`,
          error
        );
      } else {
        functions.logger.warn(
          `Email ${emailId} attempt ${newAttempts} failed, will retry`,
          error
        );
      }

      await snapshot.ref.update(updateData);
    }

    return null;
  });
