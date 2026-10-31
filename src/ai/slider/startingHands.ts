import { type Card, RANKS, rankOf, suitOf } from "../../engine/cards";
import { type Counts, checkCards, sampledCounts } from "./counts";

/**
 * The 169 kinds of starting hand: 13 pairs ("AA"), 78 suited ("AKs") and 78 offsuit ("AKo").
 * Against a random hand, every hand of one kind has the same win chance, so the preflop
 * table needs one entry per kind. Order: higher first card first, then higher second card;
 * suited before offsuit. So "AA", "AKs", "AKo", "AQs", ... "32s", "32o", "22".
 */
export const STARTING_HANDS: readonly string[] = (() => {
  const names: string[] = [];
  for (let hi = RANKS.length - 1; hi >= 0; hi--) {
    names.push(RANKS[hi]! + RANKS[hi]!);
    for (let lo = hi - 1; lo >= 0; lo--) names.push(`${RANKS[hi]}${RANKS[lo]}s`, `${RANKS[hi]}${RANKS[lo]}o`);
  }
  return names;
})();

/** The kind of starting hand two cards make. Example: ["Kd", "As"] is "AKo". */
export function startingHand(hole: readonly Card[]): string {
  checkCards(hole, [], 0);
  const [a, b] = rankOf(hole[0]!) >= rankOf(hole[1]!) ? [hole[0]!, hole[1]!] : [hole[1]!, hole[0]!];
  const name = a[0]! + b[0]!;
  if (a[0] === b[0]) return name;
  return name + (suitOf(a) === suitOf(b) ? "s" : "o");
}

/** One pair of cards of a kind: pairs and offsuit hands use clubs and diamonds, suited hands clubs. */
export function exampleCards(name: string): [Card, Card] {
  if (!STARTING_HANDS.includes(name)) throw new Error(`Unknown starting hand "${name}"`);
  const hi = name[0]!;
  const lo = name[1]!;
  return [`${hi}c` as Card, `${lo}${name[2] === "s" ? "c" : "d"}` as Card];
}

/**
 * The seed for entry `index` of the preflop table: the table's seed plus the index.
 * Each entry has its own seed so any one entry can be recomputed alone.
 */
export function startingHandSeed(tableSeed: number, index: number): number {
  return (tableSeed + index) >>> 0;
}

/** Counts for entry `index` of the preflop table: `samples` random deals against one random hand. */
export function simulateStartingHand(index: number, samples: number, tableSeed: number): Counts {
  const name = STARTING_HANDS[index];
  if (name === undefined) throw new Error(`No starting hand at index ${index}`);
  return sampledCounts(exampleCards(name), [], samples, startingHandSeed(tableSeed, index));
}
