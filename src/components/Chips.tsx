import { chips } from "@/lib/format";

const CHIP_COLORS = ["#d64545", "#2f6fdf", "#1f9d6a", "#222831", "#8e44ad"];

/** A small stack of casino chips with the amount next to it. */
export function ChipStack({ amount, label }: { amount: number; label?: string }) {
  if (amount <= 0) return null;
  const count = Math.min(5, 1 + Math.floor(Math.log10(amount)));
  return (
    <div className="chip-stack">
      <div className="chips">
        {Array.from({ length: count }, (_, i) => (
          <span key={i} className="chip" style={{ background: CHIP_COLORS[i % CHIP_COLORS.length], bottom: i * 3 }} />
        ))}
      </div>
      <span className="chip-amount">
        {label ? `${label} ` : ""}
        {chips(amount)}
      </span>
    </div>
  );
}
