import { type CSSProperties, useState } from "react";
import { PERSONALITIES } from "@/ai/bot";
import { PlayingCard } from "./PlayingCard";
import { OPPONENTS } from "@/lib/roster";
import type { GameSettings } from "@/hooks/useGame";

const STACKS = [500, 1000, 2500];
const BLINDS = [
  { small: 5, big: 10 },
  { small: 10, big: 20 },
  { small: 25, big: 50 },
];

/** Start screen: pick the table size, stacks and blinds. */
export function Lobby({ onStart, onRules }: { onStart: (s: GameSettings) => void; onRules: () => void }) {
  const [opponents, setOpponents] = useState(4);
  const [stack, setStack] = useState(1000);
  const [blinds, setBlinds] = useState(BLINDS[0]!);
  const [fast, setFast] = useState(false);

  return (
    <div className="lobby">
      <div className="lobby-hero">
        <div className="hero-cards">
          <PlayingCard card="As" size="lg" />
          <PlayingCard card="Kh" size="lg" />
        </div>
        <h1>Texas Hold'em</h1>
        <p className="lobby-sub">No-limit poker against AI players, each with their own style.</p>
      </div>

      <div className="lobby-card">
        <div className="field">
          <span className="field-label">Opponents</span>
          <div className="segmented">
            {[1, 2, 3, 4, 5].map((n) => (
              <button key={n} className={n === opponents ? "on" : ""} onClick={() => setOpponents(n)}>
                {n}
              </button>
            ))}
          </div>
        </div>

        <div className="opponent-list">
          {OPPONENTS.slice(0, opponents).map((o) => (
            <div key={o.name} className="opponent">
              <span className="avatar avatar-sm" style={{ "--avatar": o.color } as CSSProperties}>
                {o.name[0]}
              </span>
              <span className="opponent-name">{o.name}</span>
              <span className="opponent-style">{PERSONALITIES[o.personality].label}</span>
            </div>
          ))}
        </div>

        <div className="field">
          <span className="field-label">Starting chips</span>
          <div className="segmented">
            {STACKS.map((s) => (
              <button key={s} className={s === stack ? "on" : ""} onClick={() => setStack(s)}>
                {s.toLocaleString("en-US")}
              </button>
            ))}
          </div>
        </div>

        <div className="field">
          <span className="field-label">Blinds</span>
          <div className="segmented">
            {BLINDS.map((b) => (
              <button key={b.big} className={b === blinds ? "on" : ""} onClick={() => setBlinds(b)}>
                {b.small}/{b.big}
              </button>
            ))}
          </div>
        </div>

        <div className="field">
          <span className="field-label">Game speed</span>
          <div className="segmented">
            <button className={!fast ? "on" : ""} onClick={() => setFast(false)}>
              Normal
            </button>
            <button className={fast ? "on" : ""} onClick={() => setFast(true)}>
              Fast
            </button>
          </div>
        </div>

        <button
          className="btn btn-primary btn-big"
          onClick={() => onStart({ opponents, startingStack: stack, smallBlind: blinds.small, bigBlind: blinds.big, fast })}
        >
          Take a seat
        </button>
        <button className="btn btn-link" onClick={onRules}>
          New to poker? Read the rules
        </button>
      </div>
    </div>
  );
}
