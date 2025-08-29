// Server SDK (Node). Safe for server components, route handlers, and actions.
import { cert, getApps, initializeApp, App } from "firebase-admin/app";
import { getAuth as getAdminAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";

let adminApp: App;

function getServiceAccount(): Record<string, any> {
  const b64 = process.env.FIREBASE_SERVICE_ACCOUNT_B64;
  if (b64 && b64.length > 0) {
    return JSON.parse(Buffer.from(b64, "base64").toString("utf8"));
  }
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  let privateKey = process.env.FIREBASE_PRIVATE_KEY;

  if (!projectId || !clientEmail || !privateKey) {
    throw new Error("Firebase Admin env not configured.");
  }
  privateKey = privateKey.replace(/\\n/g, "\n");
  return { project_id: projectId, client_email: clientEmail, private_key: privateKey };
}

if (!getApps().length) {
  const sa = getServiceAccount();
  adminApp = initializeApp({ credential: cert(sa as any) });
} else {
  adminApp = getApps()[0]!;
}

export const adminAuth = getAdminAuth(adminApp);
export const db = getFirestore(adminApp);
