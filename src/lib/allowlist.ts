// src/lib/allowlist.ts
export const ALLOWLIST = new Set<string>([
  "topshelfservicepros.com",
  "topshelfservicepros.net",
  "peteywee@outlook.com",
  "peteywee@gmail.com"
]);

export function isAllowed(email: string): boolean {
  const lower = email.toLowerCase().trim();
  if (ALLOWLIST.has(lower)) return true;
  const at = lower.lastIndexOf("@");
  if (at > 0) {
    const domain = lower.slice(at + 1);
    return ALLOWLIST.has(domain);
  }
  return false;
}
