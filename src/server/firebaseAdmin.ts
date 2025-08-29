// src/server/firebaseAdmin.ts
import { cert, getApps, initializeApp, App } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

let app: App | null = null;

export function getAdminApp(): App {
  if (getApps().length) return getApps()[0]!;
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  let privateKey = process.env.FIREBASE_PRIVATE_KEY;
  if (privateKey && privateKey.startsWith("-----BEGIN")) {
    // ok
  } else if (privateKey) {
    // handle escaped newlines from env
    privateKey = privateKey.replace(/\\n/g, "\n");
  }

  if (!projectId || !clientEmail || !privateKey) {
    throw new Error("Missing Firebase Admin env: FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY");
  }

  app = initializeApp({
    credential: cert({ projectId, clientEmail, privateKey })
  });
  return app!;
}

export const adminAuth = () => getAuth(getAdminApp());
