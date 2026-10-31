import { useEffect, useState } from "react";
import { type Action, type LegalActions, potTotal, type HandState } from "@/engine";
import { chips } from "@/lib/format";

interface Props {
  hand: HandState;
  legal: LegalActions | null;
  /** Shown while it is not the human's turn, e.g. "Dex is thinking…". */
  waiting: string | null;
  handStrength: string;
  onAct: (action: Action) => void;
}

const PRESETS = [
  { label: "½ Pot", fraction: 0.5 },
  { label: "¾ Pot", fraction: 0.75 },
  { label: "Pot", fraction: 1 },
];

/** Fold / check-call / bet-raise controls for the human, with sizing presets and keyboard shortcuts. */
export function ActionBar({ hand, legal, waiting, handStrength, onAct }: Props) {
  const raise = legal?.raise ?? null;
  const [raiseTo, setRaiseTo] = useState(raise?.min ?? 0);

  // Reset the raise size whenever the options change (new turn).
  useEffect(() => {
    setRaiseTo(raise?.min ?? 0);
  }, [raise?.min, raise?.max]);

  const clamp = (v: number) => (raise ? Math.round(Math.min(raise.max, Math.max(raise.min, v))) : 0);
  const potSized = (fraction: number) => {
    const call = legal?.call ?? 0;
    return clamp(hand.currentBet + fraction * (potTotal(hand) + call));
  };

  const isBet = hand.currentBet === 0;
  const allIn = raise !== null && raiseTo === raise.max;
  const check = () => onAct(legal?.check ? { type: "check" } : { type: "call" });
  const doRaise = () => raise && onAct({ type: "raise", to: clamp(raiseTo) });

  useEffect(() => {
    if (!legal) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.target instanceof HTMLInputElement && e.target.type === "number") return;
      const key = e.key.toLowerCase();
      if (key === "f" && legal.call > 0) onAct({ type: "fold" });
      else if (key === "c" || key === "k") onAct(legal.check ? { type: "check" } : { type: "call" });
      else if (key === "r" && raise) onAct({ type: "raise", to: clamp(raiseTo) });
      else return;
      e.preventDefault();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  });

  return (
    <div className={`action-bar ${legal ? "is-active" : ""}`}>
      <div className="action-info">
        <span className="strength-label">Your hand</span>
        <span className="strength-value">{handStrength || "—"}</span>
        {!legal && <span className="waiting">{waiting}</span>}
      </div>

      {legal && (
        <>
          <div className="action-buttons">
            <button className="btn btn-fold" onClick={() => onAct({ type: "fold" })} disabled={legal.call === 0} title="Fold (F)">
              Fold <kbd>F</kbd>
            </button>
            <button className="btn btn-call" onClick={check} title="Check / Call (C)">
              {legal.check ? "Check" : legal.call >= (hand.players[hand.toAct!]?.stack ?? 0) ? `Call all-in ${chips(legal.call)}` : `Call ${chips(legal.call)}`}
              <kbd>C</kbd>
            </button>
            <button className="btn btn-raise" onClick={doRaise} disabled={!raise} title="Bet / Raise (R)">
              {!raise ? (isBet ? "Bet" : "Raise") : allIn ? `All-in ${chips(raiseTo)}` : `${isBet ? "Bet" : "Raise to"} ${chips(raiseTo)}`}
              <kbd>R</kbd>
            </button>
          </div>

          {raise && (
            <div className="raise-controls">
              <div className="presets">
                <button className="chip-btn" onClick={() => setRaiseTo(raise.min)}>
                  Min
                </button>
                {PRESETS.map((p) => (
                  <button key={p.label} className="chip-btn" onClick={() => setRaiseTo(potSized(p.fraction))}>
                    {p.label}
                  </button>
                ))}
                <button className="chip-btn chip-btn-allin" onClick={() => setRaiseTo(raise.max)}>
                  All-in
                </button>
              </div>
              <div className="slider-row">
                <input
                  type="range"
                  min={raise.min}
                  max={raise.max}
                  step={1}
                  value={raiseTo}
                  onChange={(e) => setRaiseTo(Number(e.target.value))}
                  aria-label="Raise amount"
                />
                <input
                  type="number"
                  min={raise.min}
                  max={raise.max}
                  value={raiseTo}
                  onChange={(e) => setRaiseTo(Number(e.target.value))}
                  onBlur={() => setRaiseTo(clamp(raiseTo))}
                  onKeyDown={(e) => e.key === "Enter" && doRaise()}
                  aria-label="Raise amount in chips"
                />
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}
