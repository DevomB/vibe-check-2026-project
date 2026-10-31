import { useState } from "react";
import { PlayingCard } from "./PlayingCard";
import { type GameSettings, TABLE } from "@/hooks/useGame";
import { BLUFF_PCT_MAX, RISK_MAX } from "@/lean/protocol";

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

function BotSlider({ label, value, max, shown, help, onChange }: SliderProps) {
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

/** Start screen: set the bot's Risk and Bluff sliders, and optionally a seed to replay a game. */
export function Lobby({
  initial,
  onStart,
  onRules,
}: {
  initial?: GameSettings;
  onStart: (s: GameSettings) => void;
  onRules: () => void;
}) {
  const [risk, setRisk] = useState(initial?.risk ?? 50);
  const [bluffPct, setBluffPct] = useState(initial?.bluffPct ?? 33);
  const [seedText, setSeedText] = useState("");
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
        <div className="field-label">Set up the bot</div>
        <BotSlider
          label="Risk"
          value={risk}
          max={RISK_MAX}
          shown={String(risk)}
          help="How much the bot hates to lose chips. At 0 it calls any bet that pays off on average; at 100 it needs a much stronger hand to call."
          onChange={setRisk}
        />
        <BotSlider
          label="Bluff"
          value={bluffPct}
          max={BLUFF_PCT_MAX}
          shown={`${bluffPct}%`}
          help="How many of the bot's river bets are bluffs with weak hands. At 0% it never bluffs on the river; at 60% it bluffs often."
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
        <button className="btn btn-link" onClick={onRules}>
          New to poker? Read the rules
        </button>
      </div>
    </div>
  );
}
