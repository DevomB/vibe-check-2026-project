import table from "../../../data/preflop.json";
import type { Card } from "../../engine/cards";
import { type Counts, total } from "./counts";
import { STARTING_HANDS, startingHand } from "./startingHands";

/** Where data/preflop.json came from: its seed, deals per hand and the command that rebuilds it. */
export const PREFLOP_SOURCE = { seed: table.seed, samplesPerHand: table.samplesPerHand, command: table.command } as const;

/** The table by hand name, checked once on load: every starting hand in order, counts adding up. */
const BY_HAND: ReadonlyMap<string, Counts> = (() => {
  if (table.hands.length !== STARTING_HANDS.length) {
    throw new Error(`data/preflop.json has ${table.hands.length} entries, expected ${STARTING_HANDS.length}`);
  }
  const byHand = new Map<string, Counts>();
  table.hands.forEach((row, i) => {
    const counts = { win: row.win, tie: row.tie, loss: row.loss };
    if (row.hand !== STARTING_HANDS[i]) throw new Error(`data/preflop.json entry ${i} is ${row.hand}, expected ${STARTING_HANDS[i]}`);
    if (![row.win, row.tie, row.loss].every((n) => Number.isSafeInteger(n) && n >= 0) || total(counts) !== table.samplesPerHand) {
      throw new Error(`data/preflop.json entry ${row.hand} has bad counts`);
    }
    byHand.set(row.hand, counts);
  });
  return byHand;
})();

/** Preflop counts for two hole cards, looked up by their kind of starting hand. */
export function preflopCounts(hole: readonly Card[]): Counts {
  return { ...BY_HAND.get(startingHand(hole))! };
}
