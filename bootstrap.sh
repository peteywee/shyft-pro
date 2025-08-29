#!/usr/bin/env bash
set -euo pipefail

echo "[+] Bootstrapping Firebase + shadcn/ui environment"

# Ensure Node project exists
if [ ! -f package.json ]; then
  echo "[+] Initializing npm project"
  npm init -y
fi

# Ensure TypeScript
npm pkg set type=module
npm install -D typescript @types/node @types/react @types/react-dom

# Core deps
npm install firebase firebase-admin \
  lucide-react next-themes date-fns react-day-picker zod \
  class-variance-authority clsx tailwind-merge \
  @radix-ui/react-accordion @radix-ui/react-avatar @radix-ui/react-checkbox \
  @radix-ui/react-dialog @radix-ui/react-dropdown-menu @radix-ui/react-label \
  @radix-ui/react-popover @radix-ui/react-radio-group @radix-ui/react-slot \
  @radix-ui/react-toast \
  @cloudflare/workers-types

# Optional AI deps
npm install genkit @genkit-ai/googleai dotenv || true

# --- Create directories
mkdir -p src/lib app/lib src/components/ui src/components src/components/scheduling

# --- Firebase Admin
cat > src/lib/firebase-admin.ts <<'EOF'
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
EOF

# --- Firebase Client
cat > src/lib/firebase-client.ts <<'EOF'
// src/lib/firebase-client.ts
import { initializeApp, getApps, getApp } from "firebase/app";
import { getAuth, GoogleAuthProvider } from "firebase/auth";

const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY!,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN!,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID!,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET!,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID!,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID!,
};

const app = getApps().length ? getApp() : initializeApp(firebaseConfig);

export const auth = getAuth(app);
export const googleProvider = new GoogleAuthProvider();
export { GoogleAuthProvider };
EOF

# --- Utils
cat > src/lib/utils.ts <<'EOF'
// src/lib/utils.ts
import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
EOF

# --- Button
cat > src/components/ui/button.tsx <<'EOF'
// src/components/ui/button.tsx
import * as React from "react";
import { Slot } from "@radix-ui/react-slot";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const buttonVariants = cva(
  "inline-flex items-center justify-center rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 disabled:opacity-50",
  {
    variants: {
      variant: {
        default: "bg-primary text-primary-foreground hover:opacity-90",
        secondary: "bg-secondary text-secondary-foreground hover:opacity-90",
        outline: "border border-input hover:bg-accent hover:text-accent-foreground",
        ghost: "hover:bg-accent hover:text-accent-foreground",
        link: "text-primary underline-offset-4 hover:underline",
      },
      size: {
        default: "h-10 px-4 py-2",
        sm: "h-9 rounded-md px-3",
        lg: "h-11 rounded-md px-8",
        icon: "h-10 w-10",
      },
    },
    defaultVariants: { variant: "default", size: "default" },
  }
);

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean;
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, ...props }, ref) => {
    const Comp = asChild ? Slot : "button";
    return (
      <Comp
        className={cn(buttonVariants({ variant, size }), className)}
        ref={ref}
        {...props}
      />
    );
  }
);
Button.displayName = "Button";

export { Button, buttonVariants };
EOF

# --- Theme provider
cat > src/components/theme-provider.tsx <<'EOF'
// src/components/theme-provider.tsx
"use client";
import * as React from "react";
import { ThemeProvider as NextThemesProvider } from "next-themes";

export interface ThemeProviderProps {
  children: React.ReactNode;
  attribute?: "class" | "data-theme";
  defaultTheme?: string;
  enableSystem?: boolean;
  disableTransitionOnChange?: boolean;
}

export function ThemeProvider({ children, ...props }: ThemeProviderProps) {
  return <NextThemesProvider {...props}>{children}</NextThemesProvider>;
}
EOF

# --- Tailwind config
cat > tailwind.config.ts <<'EOF'
// tailwind.config.ts
import type { Config } from "tailwindcss";

const config: Config = {
  darkMode: "class",
  content: [
    "./app/**/*.{ts,tsx}",
    "./src/**/*.{ts,tsx}",
    "./components/**/*.{ts,tsx}"
  ],
  theme: { extend: {} },
  plugins: [],
};

export default config;
EOF

echo "[+] Bootstrap complete. Run: npx tsc && npm run dev"
