import * as admin from "firebase-admin";

// Initialize Firebase Admin SDK
admin.initializeApp();

// Export Cloud Functions
export { onActivityStateChange } from "./onActivityStateChange";
export { onPostCreated } from "./onPostCreated";
export { onConflictCreated } from "./onConflictCreated";
export { resolveConflict } from "./resolveConflict";
export { sendEmailNotification } from "./sendEmailNotification";
export { cleanupProductionState } from "./cleanupProductionState";
