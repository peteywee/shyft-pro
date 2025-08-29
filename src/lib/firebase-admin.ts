// src/lib/firebase-admin.ts
import * as admin from "firebase-admin";

function getServiceAccount(): admin.ServiceAccount | undefined {
  const b64 = process.env.FIREBASE_SERVICE_ACCOUNT_B64;
  const json = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (b64) {
    const parsed = JSON.parse(Buffer.from(b64, "base64").toString("utf8"));
    return {
      projectId: parsed.project_id,
      clientEmail: parsed.client_email,
      privateKey: parsed.private_key?.replace(/\\n/g, "\n"),
    };
  }
  if (json) {
    const parsed = JSON.parse(json);
    return {
      projectId: parsed.project_id,
      clientEmail: parsed.client_email,
      privateKey: parsed.private_key?.replace(/\\n/g, "\n"),
    };
  }
}

if (!admin.apps.length) {
  const svc = getServiceAccount();
  if (!svc) throw new Error("Missing FIREBASE_SERVICE_ACCOUNT(_B64).");
  admin.initializeApp({ credential: admin.credential.cert(svc) });
}

export const adminAuth = admin.auth();
export const db = admin.firestore();
