#!/usr/bin/env bash
set -euo pipefail

echo "[+] Patching use-toast to TSX and valid JSX"

# Ensure directory
mkdir -p src/hooks src/components/ui src/lib

# Write corrected TSX file
cat > src/hooks/use-toast.tsx <<'TSX'
// src/hooks/use-toast.tsx
"use client";

import * as React from "react";
import {
  ToastProvider,
  ToastViewport,
  Toast,
  ToastTitle,
  ToastDescription,
  ToastClose,
} from "@/components/ui/toast";

type ToastOpts = { title?: string; description?: string; duration?: number };

type ToastCtx = { toast: (t: ToastOpts) => void };

const ToastContext = React.createContext<ToastCtx | null>(null);

export function Toaster(): JSX.Element {
  const [items, setItems] = React.useState<Array<{ id: number } & ToastOpts>>([]);

  const toast = React.useCallback((t: ToastOpts) => {
    setItems((cur) => [...cur, { id: Date.now(), ...t }]);
  }, []);

  const remove = React.useCallback((id: number) => {
    setItems((cur) => cur.filter((x) => x.id !== id));
  }, []);

  return (
    <ToastContext.Provider value={{ toast }}>
      <ToastProvider>
        {items.map((t) => (
          <Toast key={t.id} duration={t.duration ?? 3000}>
            <div className="col-span-2">
              {t.title && <ToastTitle>{t.title}</ToastTitle>}
              {t.description && (
                <ToastDescription>{t.description}</ToastDescription>
              )}
            </div>
            <ToastClose onClick={() => remove(t.id)} />
          </Toast>
        ))}
        <ToastViewport />
      </ToastProvider>
    </ToastContext.Provider>
  );
}

export function useToast(): ToastCtx {
  const ctx = React.useContext(ToastContext);
  if (!ctx) throw new Error("useToast must be used within <Toaster />");
  return ctx;
}
TSX

# Remove the incorrect .ts file if it exists
if [ -f src/hooks/use-toast.ts ]; then
  rm -f src/hooks/use-toast.ts
  echo "[+] Removed src/hooks/use-toast.ts"
fi

# Ensure tsconfig has JSX enabled
if [ -f tsconfig.json ]; then
  node - <<'NODE'
const fs = require("fs");
const path = "tsconfig.json";
const json = JSON.parse(fs.readFileSync(path, "utf8"));

json.compilerOptions ||= {};
if (!json.compilerOptions.jsx) {
  json.compilerOptions.jsx = "react-jsx";
}
if (!json.include) {
  json.include = ["next-env.d.ts", "**/*.ts", "**/*.tsx"];
} else if (!json.include.includes("**/*.tsx")) {
  json.include.push("**/*.tsx");
}
fs.writeFileSync(path, JSON.stringify(json, null, 2));
console.log("[+] Ensured tsconfig.json has jsx:'react-jsx' and includes TSX");
NODE
else
  echo "[!] tsconfig.json not found. Create one with jsx:'react-jsx' if needed."
fi

echo "[✓] Done. Rebuild types: npx tsc -p tsconfig.json"
