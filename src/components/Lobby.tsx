import { type CSSProperties, useState } from "react";
import { ChallengePicker } from "./ChallengePicker";
import { PlayingCard } from "./PlayingCard";
import { type GameSettings, TABLE } from "@/hooks/useGame";
import { BLUFF_PCT_MAX, RISK_MAX } from "@/lean/protocol";
import type { Challenge } from "@/lib/challenges";
import { CUSTOM_BOT, OPPONENTS, presetFor } from "@/lib/roster";

interface SliderProps {
  label: string;
  value: number;
  max: number;
  /** How the value is shown, e.g. "33%". */
  shown: string;
  /** One plain sentence on what the slider changes. */
  help: string;
  onChange: (v: number) => void;
}

export function BotSlider({ label, value, max, shown, help, onChange }: SliderProps) {
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
      <p className="bot-slider-help">{help}</p>
    </div>
  );
}

/** Start screen: pick a named opponent or set the bot's Risk and Bluff sliders yourself, and
 * optionally a seed to replay a game. Or load a practice challenge. */
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
  const [risk, setRisk] = useState(initial?.risk ?? 50);
  const [bluffPct, setBluffPct] = useState(initial?.bluffPct ?? 33);
  const [seedText, setSeedText] = useState("");
  const preset = presetFor(risk, bluffPct);
  const pick = (risk: number, bluffPct: number) => {
    setRisk(risk);
    setBluffPct(bluffPct);
  };
  const [fast, setFast] = useState(initial?.fast ?? false);

  const seedValid = /^\d{0,20}$/.test(seedText.trim());
  const start = () => {
    const trimmed = seedText.trim();
    onStart({ risk, bluffPct, seed: trimmed ? BigInt(trimmed) : null, fast });
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
          {OPPONENTS.map((o) => (
            <button
              key={o.name}
              type="button"
              role="radio"
              aria-checked={preset === o}
              className={`opponent ${preset === o ? "on" : ""}`}
              onClick={() => pick(o.risk, o.bluffPct)}
            >
              <span className="avatar avatar-sm" style={{ "--avatar": o.color } as CSSProperties}>
                {o.name[0]}
              </span>
              <span className="opponent-name">{o.name}</span>
              <span className="opponent-style">{o.style}</span>
            </button>
          ))}
          <div className={`opponent ${preset ? "" : "on"}`} role="radio" aria-checked={!preset} aria-disabled>
            <span className="avatar avatar-sm" style={{ "--avatar": CUSTOM_BOT.color } as CSSProperties}>
              ?
            </span>
            <span className="opponent-name">Custom</span>
            <span className="opponent-style">Move a slider to build your own</span>
          </div>
        </div>

        <div className="field-label">Set up the bot</div>
        <BotSlider
          label="Risk"
          value={risk}
          max={RISK_MAX}
          shown={String(risk)}
          help="How much the bot hates losing chips: at 0 it calls whenever calling pays off on average, and at 100 it needs a much stronger hand to call."
          onChange={setRisk}
        />
        <BotSlider
          label="Bluff"
          value={bluffPct}
          max={BLUFF_PCT_MAX}
          shown={`${bluffPct}%`}
          help="Target bluff share in the bot's river betting range, from 0% to 60%. The share in played hands can differ."
          onChange={setBluffPct}
        />

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
          Start
        </button>
        <div className="field-label">Practice</div>
        <ChallengePicker onPick={(c) => onPractice(c, fast)} />

        <button className="btn btn-link" onClick={onRules}>
          New to poker? Read the rules
        </button>
      </div>
    </div>
  );
}
