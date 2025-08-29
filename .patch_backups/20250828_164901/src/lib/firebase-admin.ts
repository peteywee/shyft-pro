// src/lib/firebase-admin.ts
// Shim adapter so legacy imports keep working.
import { adminAuth as _adminAuth } from "@/server/firebaseAdmin";
import * as dbMock from "@/lib/db-mock";

// Export the adminAuth getter
export const adminAuth = _adminAuth;

// Some parts of the app imported { db } from "@/lib/firebase-admin"
// Re-export db-mock to preserve those call sites.
export const db = dbMock;
