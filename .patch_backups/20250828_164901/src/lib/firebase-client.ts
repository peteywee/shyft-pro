// src/lib/firebase-client.ts
// Shim adapter so legacy imports keep working.
import { auth } from "@/services/firebase";
import { GoogleAuthProvider } from "firebase/auth";

export { auth };
export const googleProvider = new GoogleAuthProvider();
