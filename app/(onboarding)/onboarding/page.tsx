"use client";

import { useEffect, useState } from "react";
import { auth } from "@/lib/firebase-client";
import { onAuthStateChanged } from "firebase/auth";
import { useRouter } from "next/navigation";

export default function OnboardingPage() {
  const router = useRouter();
  const [role, setRole] = useState("staff");
  const [orgId, setOrgId] = useState("");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (user) => {
      if (!user) {
        router.replace("/login");
        return;
      }
      setLoading(false);
    });
    return () => unsub();
  }, [router]);

  const complete = async (e: React.FormEvent) => {
    e.preventDefault();
    const user = auth.currentUser;
    if (!user) { router.replace("/login"); return; }
    const idToken = await user.getIdToken();

    const r = await fetch("/api/onboarding", {
      method: "POST",
      headers: { authorization: `Bearer ${idToken}` },
      body: JSON.stringify({ role, orgId }),
    });
    if (!r.ok) {
      alert("Failed to save onboarding.");
      return;
    }
    router.replace("/dashboard");
  };

  if (loading) return null;

  return (
    <main className="max-w-md mx-auto p-6 space-y-6">
      <h1 className="text-2xl font-semibold">Finish onboarding</h1>
      <form onSubmit={complete} className="space-y-3">
        <input
          type="text"
          placeholder="Organization ID"
          className="w-full border rounded-xl px-3 py-2"
          value={orgId}
          onChange={(e) => setOrgId(e.target.value)}
          required
        />
        <select
          className="w-full border rounded-xl px-3 py-2"
          value={role}
          onChange={(e) => setRole(e.target.value)}
        >
          <option value="staff">Staff</option>
          <option value="manager">Manager</option>
          <option value="admin">Admin</option>
        </select>
        <button className="w-full rounded-xl bg-black text-white px-4 py-3">
          Complete
        </button>
      </form>
    </main>
  );
}
