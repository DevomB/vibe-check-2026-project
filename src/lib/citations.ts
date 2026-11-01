/**
 * The sources behind the numbers the bot and the review use, for "where does this come
 * from?" links in the UI.
 *
 * Data only: no imports, no logic. Each entry says what one source supports here, and
 * nothing more. Ids are folders under `docs/research/sources/` (listed in
 * `docs/research/INDEX.md`). `docs/THEORY.md` gives each formula, the Lean function that
 * computes it, and the exact conditions under which the source applies.
 */

/** The formulas and choices a citation can be attached to. */
export type CitationKey =
  | "pot-odds" | "bluff-ratio" | "min-defense" | "risk-weight" | "exact-equity" | "grade-bands";

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
    {
      id: "F02",
      short: "Glosten & Milgrom (1985)",
      claim:
        "A trader facing a possibly informed counterparty should price the trade on what the counterparty's willingness to trade reveals; the review grades a call against the hands the bot would bet with, for that reason.",
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
  "risk-weight": [
    {
      id: "B01",
      short: "Pratt (1964)",
      claim:
        "A more risk-averse decision maker turns down every risky-or-sure choice a less risk-averse one turns down; the loss weight is our one-number version of that ordering, proved for one decision at a time.",
    },
    {
      id: "F03",
      short: "Avellaneda & Stoikov (2008)",
      claim:
        "A dealer's risk-aversion parameter moves its indifference price away from the risk-neutral one and disappears at zero; the loss weight plays the same role for a call, by a different formula.",
    },
    {
      id: "F01",
      short: "Kyle (1985)",
      claim:
        "Market makers who cannot tell informed orders from noise price at the expected value and earn zero on average; the bot at Risk 50 is that risk-neutral pricer.",
    },
  ],
  "exact-equity": [
    {
      id: "C06",
      short: "PokerHandEvaluator (Lee); Cactus Kev",
      claim:
        "Fast hand evaluators are checked by exhaustive comparison with each other, not by proof; our ranking is the spec's own bestScore, and the river and turn counts are proved to count every outcome once (T6).",
    },
    {
      id: "E05",
      short: "PokerTracker 4, All-in Equity",
      claim:
        "Poker tools measure a hand by its equity, the share of the pot it expects to win over the remaining deals; our equity is that share, counted exactly on the turn and river.",
    },
  ],
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
