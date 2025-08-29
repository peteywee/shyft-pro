// src/services/firebase.ts
// Client-side Firebase initialization for Auth.
// NOTE: Only import this module from client components or client code paths.

import { initializeApp, getApps, getApp, type FirebaseApp } from "firebase/app";
import { getAuth, type Auth } from "firebase/auth";

// Defensive config loader to catch missing envs early in dev.
function requireEnv(name: string): string {
  const v = process.env[name];
  if (!v) {
    // Fail loudly in development; in production you typically want this set by your hosting env.
    if (process.env.NODE_ENV !== "production") {
      throw new Error(`Missing required env var: ${name}`);
    }
  }
  return v as string;
}

const firebaseConfig = {
  apiKey: requireEnv("NEXT_PUBLIC_FIREBASE_API_KEY"),
  authDomain: requireEnv("NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN"),
  projectId: requireEnv("NEXT_PUBLIC_FIREBASE_PROJECT_ID"),
  storageBucket: requireEnv("NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET"),
  messagingSenderId: requireEnv("NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID"),
  appId: requireEnv("NEXT_PUBLIC_FIREBASE_APP_ID"),
};

// Ensure singleton app to avoid "Firebase App named '[DEFAULT]' already exists" in HMR.
const app: FirebaseApp = getApps().length ? getApp() : initializeApp(firebaseConfig);

// Export the Auth instance expected by legacy imports.
export const auth: Auth = getAuth(app);

// Optional: named exports if you want to expand later without changing imports.
// export { app };
