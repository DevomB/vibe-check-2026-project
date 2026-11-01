/** A named opponent: a preset for the Lean slider bot's Risk and Bluff sliders. Every
 * opponent is the same proven bot; only the two slider values differ. */
export interface Opponent {
  name: string;
  color: string;
  /** A few words on how it plays, from what the sliders do. */
  style: string;
  /** 0 to 100: how heavily it weighs a lost chip when deciding to call. */
  risk: number;
  /** 0 to 60: the target bluff share in its defined river betting range, in percent. */
  bluffPct: number;
}

/** The named opponents, from most careful to wildest. */
export const OPPONENTS: Opponent[] = [
  { name: "Ivy", color: "#f0a23a", style: "Careful, never bluffs", risk: 100, bluffPct: 0 },
  { name: "Rook", color: "#3fb68b", style: "Calls a lot, never bluffs", risk: 0, bluffPct: 0 },
  { name: "Mia", color: "#5b8def", style: "Balanced", risk: 50, bluffPct: 33 },
  { name: "Dex", color: "#e0624f", style: "Calls often, bluffs often", risk: 25, bluffPct: 45 },
  { name: "Vex", color: "#b06ce8", style: "Wild: calls a lot, bluffs the most", risk: 0, bluffPct: 60 },
];

/** The bot when its sliders match no named opponent. */
export const CUSTOM_BOT = { name: "Bot", color: "#8a8f98" } as const;

/** The named opponent with exactly these slider values, if there is one. */
export function presetFor(risk: number, bluffPct: number): Opponent | undefined {
  return OPPONENTS.find((o) => o.risk === risk && o.bluffPct === bluffPct);
}

/** The name and color shown for the bot at the table. */
export function botFor(risk: number, bluffPct: number): { name: string; color: string } {
  const preset = presetFor(risk, bluffPct);
  return preset ? { name: preset.name, color: preset.color } : CUSTOM_BOT;
}

export const HUMAN_COLOR = "#e9c46a";
