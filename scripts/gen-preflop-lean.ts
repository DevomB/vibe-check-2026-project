/**
 * Builds engine/Engine/PreflopData.lean from data/preflop.json: the preflop win/tie/loss table
 * the Lean bot looks up by starting-hand name (MVP §5). Run from the repo root:
 *
 *   npx --yes tsx@4.20.6 scripts/gen-preflop-lean.ts
 *
 * The Lean file is generated. Never edit it by hand; change data/preflop.json (with
 * scripts/gen-preflop.ts) and run this again. The same JSON always gives the same file.
 */
import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { STARTING_HANDS } from "../src/ai/slider/startingHands";

const COMMAND = "npx --yes tsx@4.20.6 scripts/gen-preflop-lean.ts";
const jsonPath = fileURLToPath(new URL("../data/preflop.json", import.meta.url));
const leanPath = fileURLToPath(new URL("../engine/Engine/PreflopData.lean", import.meta.url));

interface Row {
  hand: string;
  win: number;
  tie: number;
  loss: number;
}
const table = JSON.parse(readFileSync(jsonPath, "utf8")) as { seed: number; samplesPerHand: number; hands: Row[] };

// The same checks as src/ai/slider/preflopTable.ts: every starting hand once, in order, counts adding up.
if (table.hands.length !== STARTING_HANDS.length) {
  throw new Error(`data/preflop.json has ${table.hands.length} entries, expected ${STARTING_HANDS.length}`);
}
table.hands.forEach((row, i) => {
  if (row.hand !== STARTING_HANDS[i]) throw new Error(`entry ${i} is ${row.hand}, expected ${STARTING_HANDS[i]}`);
  const counts = [row.win, row.tie, row.loss];
  if (!counts.every((n) => Number.isSafeInteger(n) && n >= 0) || row.win + row.tie + row.loss !== table.samplesPerHand) {
    throw new Error(`entry ${row.hand} has bad counts`);
  }
});

const rows = table.hands.map((r) => `  ("${r.hand}", ${r.win}, ${r.tie}, ${r.loss})`).join(",\n");
const lean = `-- Generated from data/preflop.json by scripts/gen-preflop-lean.ts. Do not edit by hand.
-- To rebuild, run from the repo root: ${COMMAND}

/-!
# Preflop table (generated)

Win, tie and loss counts for each of the 169 starting hands against one random hand, from
${table.samplesPerHand.toLocaleString("en-US")} seeded random deals per hand (seed ${table.seed}). These are estimates, and
trusted data (MVP section 5). \`Engine/StartingHands.lean\` looks hands up in this table.
-/

/-- The seed the table was made from. Entry \`i\` used seed \`preflopSeed + i\`. -/
def preflopSeed : Nat := ${table.seed}

/-- Random deals per starting hand. Each entry's counts add up to this. -/
def preflopSamplesPerHand : Nat := ${table.samplesPerHand}

/-- One entry per starting hand: name, wins, ties, losses. Order: "AA", "AKs", "AKo", ..., "22". -/
def preflopTable : List (String × Nat × Nat × Nat) := [
${rows}
]
`;

writeFileSync(leanPath, lean);
console.log(`Wrote ${leanPath} (${table.hands.length} hands)`);
