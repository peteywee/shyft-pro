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
