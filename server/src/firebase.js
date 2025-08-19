// server/src/firebase.ts
import admin from 'firebase-admin';
function loadServiceAccount() {
    // Prefer base64 (safer for quoting); fall back to raw JSON string
    const b64 = process.env.FIREBASE_SERVICE_ACCOUNT_B64;
    const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    if (b64) {
        try {
            const json = Buffer.from(b64, 'base64').toString('utf8');
            return JSON.parse(json);
        }
        catch (e) {
            throw new Error('FIREBASE_SERVICE_ACCOUNT_B64 is set but invalid (base64 or JSON parse failed).');
        }
    }
    if (raw) {
        try {
            return JSON.parse(raw);
        }
        catch {
            throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON is set but not valid JSON.');
        }
    }
    throw new Error('Missing service account: set FIREBASE_SERVICE_ACCOUNT_B64 (preferred) or FIREBASE_SERVICE_ACCOUNT_JSON.');
}
let app;
if (!admin.apps.length) {
    const creds = loadServiceAccount();
    app = admin.initializeApp({
        credential: admin.credential.cert(creds),
        storageBucket: process.env.FIREBASE_STORAGE_BUCKET || undefined,
    });
}
else {
    app = admin.app();
}
export const auth = admin.auth(app);
export const db = admin.firestore(app);
export const storage = admin.storage(app);
