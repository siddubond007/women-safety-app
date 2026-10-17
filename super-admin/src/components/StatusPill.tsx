import type { ReactNode } from "react";

type StatusTone = "demo" | "rose" | "amber" | "green" | "neutral" | "urgent";

interface StatusPillProps {
  tone?: StatusTone;
  children: ReactNode;
  dot?: boolean;
}

export function StatusPill({ tone = "neutral", children, dot = false }: StatusPillProps) {
  return (
    <span className={"status-pill status-pill--" + tone}>
      {dot && <span className="status-pill__dot" aria-hidden="true" />}
      {children}
    </span>
  );
}