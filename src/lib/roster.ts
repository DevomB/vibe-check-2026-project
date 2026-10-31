import type { PersonalityKey } from "@/ai/bot";

export interface Opponent {
  name: string;
  personality: PersonalityKey;
  color: string;
}

/** The AI players, in the order they join the table. */
export const OPPONENTS: Opponent[] = [
  { name: "Mia", personality: "pro", color: "#5b8def" },
  { name: "Dex", personality: "shark", color: "#e0624f" },
  { name: "Rook", personality: "station", color: "#3fb68b" },
  { name: "Vex", personality: "maniac", color: "#b06ce8" },
  { name: "Ivy", personality: "rock", color: "#f0a23a" },
];

/** Opponents the Lean engine can play. Its only bot checks or calls every time, which is
 * the "station" personality. */
export const PLAYABLE_OPPONENTS: Opponent[] = OPPONENTS.filter((o) => o.personality === "station");

export const HUMAN_COLOR = "#e9c46a";
