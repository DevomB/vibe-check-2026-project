/**
 * A stand-in for lane 1's `src/lib/citations.ts`, with the same type and the entries the review
 * uses, until that file reaches main. Then point the import in `src/components/WhyChip.tsx` at
 * `@/lib/citations` and delete this file.
 */

export type CitationKey = "pot-odds" | "bluff-ratio" | "min-defense" | "risk-weight" | "exact-equity" | "grade-bands";

export interface Citation {
  /** Source id from docs/research/INDEX.md, e.g. "A03". */
  id: string;
  /** Short reference, e.g. "von Neumann & Morgenstern (1944)". */
  short: string;
  /** One sentence: what this source supports here, and nothing more. */
  claim: string;
}

export const CITATIONS: Record<CitationKey, Citation[]> = {
  "pot-odds": [
    {
      id: "A03",
      short: "Ferguson & Ferguson, on von Neumann's poker model",
      claim:
        "Calling a bet S into a pot P breaks even at equity S / (P + 2S); the review's equity needed is this number, written as cost / (prize + cost).",
    },
  ],
  "bluff-ratio": [
    {
      id: "A03",
      short: "Ferguson & Ferguson, after von Neumann & Morgenstern (1944)",
      claim:
        "In the one-bet poker model a pot-sized bet is balanced when one third of the bets are bluffs; the 33% setting matches this textbook ratio under that model's conditions, and nothing more.",
    },
  ],
  "min-defense": [
    {
      id: "A03",
      short: "Ferguson & Ferguson, on von Neumann's poker model",
      claim:
        "Against a bet S into a pot P the caller must continue with share P / (P + S) of its hands for a pure bluff to break even; the engine does not compute this number anywhere.",
    },
  ],
  "risk-weight": [],
  "exact-equity": [],
  "grade-bands": [
    {
      id: "E01",
      short: "Chess.com Game Review",
      claim:
        "Grading a move by what it lost against the best move, with fixed bands, is a product convention; our bands at 0.5, 2 and 5 big blinds are our own choice, set by no source.",
    },
    {
      id: "E05",
      short: "GTO Wizard Analyzer",
      claim:
        "Poker review tools report EV lost per action in big blinds and colour it by band without publishing their thresholds; ours are published in labelFor.",
    },
  ],
};
