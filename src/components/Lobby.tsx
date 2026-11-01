import { type CSSProperties, useState } from "react";
import { ChallengePicker } from "./ChallengePicker";
import { PlayingCard } from "./PlayingCard";
import { type GameSettings, TABLE } from "@/hooks/useGame";
import { RISK_IDEAL, RISK_MAX } from "@/lean/protocol";
import type { Challenge } from "@/lib/challenges";
import { CUSTOM_BOT, OPPONENTS, presetFor } from "@/lib/roster";
import styles from "./modes.module.css";

interface SliderProps {
  label: string;
  value: number;
  max: number;
  /** How the value is shown, e.g. "33%". */
  shown: string;
  /** One plain sentence on what the slider changes. */
  help: string;
  /** Names for points on the scale, shown under the slider, like "Ideal" at 50. */
  marks?: readonly { at: number; label: string }[];
  onChange: (v: number) => void;
}

/** The names on the Risk scale: a Rock at 0, the ideal at 50, a Maniac at 100. */
export const RISK_MARKS = [
  { at: 0, label: "Rock" },
  { at: RISK_IDEAL, label: "Ideal" },
  { at: RISK_MAX, label: "Maniac" },
] as const;

/** What Risk does, in plain words; shared by the setup screen and the Mystery guess. */
export const RISK_HELP =
  "The bot's appetite for risk. At 0 (Rock) it folds unless a call clearly pays, and never bluffs. At 50 it plays the textbook way: it calls when the pot odds say so, and a third of the hands it bets on the river are bluffs. Above 50 it calls the same way but bluffs more, the most at 100 (Maniac).";

export function BotSlider({ label, value, max, shown, help, marks, onChange }: SliderProps) {
  return (
    <div className="bot-slider">
      <div className="bot-slider-head">
        <span className="field-label">{label}</span>
        <span className="bot-slider-value">{shown}</span>
      </div>
      <input
        type="range"
        min={0}
        max={max}
        step={1}
        value={value}
        onChange={(e) => onChange(Number(e.target.value))}
        aria-label={label}
        aria-valuetext={shown}
      />
      {marks && (
        <div className={styles.sliderMarks} aria-hidden>
          {marks.map((m) => (
            <span key={m.at} style={{ left: `${(m.at / max) * 100}%` }}>
              {m.label}
            </span>
          ))}
        </div>
      )}
      <p className="bot-slider-help">{help}</p>
    </div>
  );
}

/** Start screen: pick a named opponent or set the bot's Risk slider yourself, and optionally a
 * seed to replay a game. Or play a Mystery opponent, or load a practice challenge. */
export function Lobby({
  initial,
  onStart,
  onPractice,
  onRules,
}: {
  initial?: GameSettings;
  onStart: (s: GameSettings) => void;
  /** Load a rehearsed hand at its river decision, at the chosen game speed. */
  onPractice: (c: Challenge, fast: boolean) => void;
  onRules: () => void;
}) {
  const [risk, setRisk] = useState(initial?.risk ?? RISK_IDEAL);
  const [seedText, setSeedText] = useState("");
  const preset = presetFor(risk);
  const [fast, setFast] = useState(initial?.fast ?? false);
  /** Mystery opponent: the server picks Risk and the seed, so neither is shown here. */
  const [mystery, setMystery] = useState(initial?.mystery ?? false);

  const seedValid = mystery || /^\d{0,20}$/.test(seedText.trim());
  const start = () => {
    const trimmed = seedText.trim();
    onStart({ risk, seed: !mystery && trimmed ? BigInt(trimmed) : null, fast, mystery });
  };

  return (
    <div className="lobby">
      <div className="lobby-hero">
        <div className="hero-cards">
          <PlayingCard card="As" size="lg" />
          <PlayingCard card="Kh" size="lg" />
        </div>
        <h1>FoldProof</h1>
        <p className="lobby-sub">
          No-limit Texas Hold'em, one on one. You and the bot each start with {TABLE.startingStack} chips, and the blinds are{" "}
          {TABLE.smallBlind} and {TABLE.bigBlind}.
        </p>
        <button className="btn btn-link" onClick={onRules}>
          New to poker? Read the rules
        </button>
      </div>

      <div className="lobby-card">
        <h2 className="lobby-section">Your opponent</h2>
        <label className={styles.toggle}>
          <input type="checkbox" checked={mystery} onChange={(e) => setMystery(e.target.checked)} />
          <span className="field-label">Mystery opponent</span>
        </label>
        {mystery ? (
          <p className={styles.mysteryNote}>
            The server picks the bot's Risk at random and keeps it secret. Play at least 3 hands, then guess it. The reveal
            shows how close you were. Reviews open after your guess.
          </p>
        ) : (
          <>
            <div className="opponent-list" role="radiogroup" aria-label="Opponent">
              {OPPONENTS.map((o) => (
                <button
                  key={o.name}
                  type="button"
                  role="radio"
                  aria-checked={preset === o}
                  className={`opponent ${preset === o ? "on" : ""}`}
                  onClick={() => setRisk(o.risk)}
                >
                  <span className="avatar avatar-sm" style={{ "--avatar": o.color } as CSSProperties}>
                    {o.name[0]}
                  </span>
                  <span className="opponent-name">{o.name}</span>
                  <span className="opponent-style">
                    {o.tier}, Risk {o.risk}. {o.style}
                  </span>
                </button>
              ))}
              <div className={`opponent ${preset ? "" : "on"}`} role="radio" aria-checked={!preset} aria-disabled>
                <span className="avatar avatar-sm" style={{ "--avatar": CUSTOM_BOT.color } as CSSProperties}>
                  ?
                </span>
                <span className="opponent-name">Custom</span>
                <span className="opponent-style">Move the slider to build your own</span>
              </div>
            </div>

            <BotSlider
              label="Risk"
              value={risk}
              max={RISK_MAX}
              shown={String(risk)}
              marks={RISK_MARKS}
              help={RISK_HELP}
              onChange={setRisk}
            />
            <p className={styles.derivedNote}>
              Lean sets the bot's bluff share from Risk when the game starts. The table shows it at the top, next to Risk.
            </p>
          </>
        )}

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

        {!mystery && (
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
        )}

        <button className="btn btn-primary btn-big" onClick={start} disabled={!seedValid}>
          Start
        </button>

        <h2 className="lobby-section">Practice</h2>
        <ChallengePicker onPick={(c) => onPractice(c, fast)} />
      </div>
    </div>
  );
}
