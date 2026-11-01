/** A named opponent: a preset for the Lean slider bot's one setting, Risk. Every opponent is
 * the same proven bot; only the Risk value differs, and Lean derives the rest from it. */
export interface Opponent {
  name: string;
  color: string;
  /** A few words on how it plays, from what its Risk does. */
  style: string;
  /** Where it sits on the Risk scale, like "Rock" or "Ideal". */
  tier: string;
  /** 0 to 100: its appetite for risk. 50 is the ideal. */
  risk: number;
}

/** The named opponents, from most careful to wildest. */
export const OPPONENTS: Opponent[] = [
  { name: "Ivy", color: "#f0a23a", style: "Folds unless a call clearly pays, never bluffs", tier: "Rock", risk: 0 },
  { name: "Rook", color: "#3fb68b", style: "Folds more than the odds say, bluffs a little", tier: "Tight", risk: 25 },
  { name: "Dex", color: "#e0624f", style: "A little careful", tier: "Solid", risk: 40 },
  { name: "Mia", color: "#5b8def", style: "The textbook setting", tier: "Ideal", risk: 50 },
  { name: "Vex", color: "#b06ce8", style: "Calls like Mia, bluffs the most", tier: "Maniac", risk: 100 },
];

/** The bot when its Risk matches no named opponent. */
export const CUSTOM_BOT = { name: "Bot", color: "#8a8f98" } as const;

/** The named opponent with exactly this Risk, if there is one. */
export function presetFor(risk: number): Opponent | undefined {
  return OPPONENTS.find((o) => o.risk === risk);
}

/** The name and color shown for the bot at the table. */
export function botFor(risk: number): { name: string; color: string } {
  const preset = presetFor(risk);
  return preset ? { name: preset.name, color: preset.color } : CUSTOM_BOT;
}

export const HUMAN_COLOR = "#e9c46a";
