import { useEffect, useState } from "react";

export interface WomenQuoteEntry {
  id: number;
  quote: string;
  author: string;
  category: string;
}

export const SAKHI_ADMIN_WOMEN_QUOTES: WomenQuoteEntry[] = [
  { id: 1, quote: "Awake, arise, and educate. Smash traditions—liberate!", author: "Savitribai Phule", category: "Trailblazers & Courage" },
  { id: 2, quote: "We want deeper sincerity of motive, a greater courage in speech and earnestness in action.", author: "Sarojini Naidu", category: "Voice & Leadership" },
  { id: 3, quote: "The path from dreams to success does exist. May you have the vision to find it, the courage to get on to it, and the perseverance to follow it.", author: "Kalpana Chawla", category: "Dreams & Perseverance" },
  { id: 4, quote: "I shall not surrender my Jhansi—courage is the crown every woman wears within.", author: "Rani Lakshmibai", category: "Fearless Strength" },
  { id: 5, quote: "Each time a woman stands up for herself, without knowing it possibly, without claiming it, she stands up for all women.", author: "Maya Angelou", category: "Sisterhood & Solidarity" },
  { id: 6, quote: "Vision without action is merely a dream; action with courage changes generations.", author: "Sudha Murty", category: "Wisdom & Action" },
  { id: 7, quote: "Do not wait for someone else to come and speak for you. It's you who can change the world.", author: "Mary Kom", category: "Fearless Strength" },
  { id: 8, quote: "Empowerment begins the moment a woman knows she is never walking alone.", author: "Sakhi Sisterhood", category: "Sakhi Safety & Trust" },
  { id: 9, quote: "Women belong in all places where decisions are being made.", author: "Ruth Bader Ginsburg", category: "Voice & Leadership" },
  { id: 10, quote: "Nothing in life is to be feared, it is only to be understood. Now is the time to understand more, so that we may fear less.", author: "Marie Curie", category: "Wisdom & Fearlessness" },
  { id: 11, quote: "I measure the progress of a community by the degree of progress which women have achieved.", author: "Dr. B. R. Ambedkar", category: "Equality & Justice" },
  { id: 12, quote: "The sky is not the limit when women build the rockets.", author: "Tessy Thomas", category: "Dreams & Perseverance" },
];

export function SakhiQuoteLoader({
  statusLabel = "Preparing Sakhi workspace...",
}: {
  statusLabel?: string;
}) {
  const [idx, setIdx] = useState(0);

  useEffect(() => {
    const timer = window.setInterval(() => {
      setIdx((prev) => (prev + 1) % SAKHI_ADMIN_WOMEN_QUOTES.length);
    }, 3800);
    return () => window.clearInterval(timer);
  }, []);

  const current = SAKHI_ADMIN_WOMEN_QUOTES[idx];

  return (
    <div
      role="status"
      style={{
        maxWidth: 460,
        margin: "32px auto",
        padding: "24px 28px",
        background: "#FFFFFF",
        border: "1px solid #EFE3EE",
        borderRadius: 20,
        boxShadow: "0 10px 28px rgba(90, 24, 104, 0.08)",
        textAlign: "center",
      }}
    >
      <div
        style={{
          display: "inline-block",
          padding: "4px 12px",
          background: "#F3E8F6",
          color: "#5A1868",
          borderRadius: 999,
          fontSize: 11,
          fontWeight: 800,
          letterSpacing: "0.05em",
          marginBottom: 12,
        }}
      >
        ✨ {current.category.toUpperCase()}
      </div>
      <blockquote
        style={{
          margin: "0 0 8px 0",
          fontSize: 15,
          fontStyle: "italic",
          fontWeight: 600,
          color: "#2A1930",
          lineHeight: 1.45,
        }}
      >
        “{current.quote}”
      </blockquote>
      <div
        style={{
          fontSize: 12.5,
          fontWeight: 700,
          color: "#5A1868",
          marginBottom: 14,
        }}
      >
        — {current.author}
      </div>
      <div
        style={{
          height: 4,
          background: "#F3E8F6",
          borderRadius: 999,
          overflow: "hidden",
          marginBottom: 10,
        }}
      >
        <div
          style={{
            width: "65%",
            height: "100%",
            background: "linear-gradient(90deg, #5A1868, #C92A49)",
            borderRadius: 999,
          }}
        />
      </div>
      <div style={{ fontSize: 12, color: "#6E6275", fontWeight: 500 }}>
        {statusLabel}
      </div>
    </div>
  );
}
