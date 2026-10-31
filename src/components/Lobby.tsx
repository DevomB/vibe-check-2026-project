import { type CSSProperties, useState } from "react";
import { PERSONALITIES } from "@/ai/bot";
import { PlayingCard } from "./PlayingCard";
import { OPPONENTS } from "@/lib/roster";
import { type GameSettings, TABLE } from "@/hooks/useGame";

/** Start screen: pick the opponent, and optionally a seed to replay a game. */
export function Lobby({ onStart, onRules }: { onStart: (s: GameSettings) => void; onRules: () => void }) {
  const [opponent, setOpponent] = useState(0);
  const [seedText, setSeedText] = useState("");
  const [fast, setFast] = useState(false);

  const seedValid = /^\d{0,20}$/.test(seedText.trim());
  const start = () => {
    const trimmed = seedText.trim();
    onStart({ opponent, seed: trimmed ? BigInt(trimmed) : null, fast });
  };

  return (
    <div className="lobby">
      <div className="lobby-hero">
        <div className="hero-cards">
          <PlayingCard card="As" size="lg" />
          <PlayingCard card="Kh" size="lg" />
        </div>
        <h1>Texas Hold'em</h1>
        <p className="lobby-sub">
          Heads-up no-limit · {TABLE.startingStack} chips each · blinds {TABLE.smallBlind}/{TABLE.bigBlind}
        </p>
      </div>

      <div className="lobby-card">
        <div className="field-label">Your opponent</div>
        <div className="opponent-list" role="radiogroup" aria-label="Opponent">
          {OPPONENTS.map((o, i) => (
            <button
              key={o.name}
              type="button"
              role="radio"
              aria-checked={i === opponent}
              className={`opponent ${i === opponent ? "on" : ""}`}
              onClick={() => setOpponent(i)}
            >
              <span className="avatar avatar-sm" style={{ "--avatar": o.color } as CSSProperties}>
                {o.name[0]}
              </span>
              <span className="opponent-name">{o.name}</span>
              <span className="opponent-style">{PERSONALITIES[o.personality].label}</span>
            </button>
          ))}
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

        <label className="field">
          <span className="field-label">
            Seed <span className="muted">(optional, to replay a game)</span>
          </span>
          <input
            className={`seed-input ${seedValid ? "" : "is-invalid"}`}
            inputMode="numeric"
            placeholder="random"
            value={seedText}
            onChange={(e) => setSeedText(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && seedValid && start()}
            aria-invalid={!seedValid}
          />
        </label>

        <button className="btn btn-primary btn-big" onClick={start} disabled={!seedValid}>
          Take a seat
        </button>
        <button className="btn btn-link" onClick={onRules}>
          New to poker? Read the rules
        </button>
      </div>
    </div>
  );
}
