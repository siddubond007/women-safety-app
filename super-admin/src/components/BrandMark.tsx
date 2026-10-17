import { HeartHandshake, ShieldCheck } from "lucide-react";

interface BrandMarkProps {
  compact?: boolean;
}

export function BrandMark({ compact = false }: BrandMarkProps) {
  return (
    <div className={compact ? "brand-lockup brand-lockup--compact" : "brand-lockup"}>
      <span className="brand-symbol" aria-hidden="true">
        <HeartHandshake size={22} strokeWidth={2.15} />
        <span className="brand-symbol__shield"><ShieldCheck size={12} strokeWidth={2.6} /></span>
      </span>
      {!compact && (
        <span className="brand-wordmark">
          <span className="brand-name">sakhi</span>
          <span className="brand-subtitle">ADMIN CONTROL CENTER</span>
        </span>
      )}
    </div>
  );
}