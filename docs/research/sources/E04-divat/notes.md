# E04: DIVAT (Billings and Kan, "A Tool for the Direct Assessment of Poker Decisions")

## Summary (also in summary.md)
TL;DR: DIVAT judges each betting round of limit hold'em in hindsight (both players' cards known) by comparing the money actually put in to a "baseline" sequence that two honest bet-for-value players would have used. The per-round "DIVAT Difference" sums to a low-variance skill score. Unbiasedness of the roll-out version was proved by Zinkevich et al. 2006 (on paper).
- Skill = (equity difference between actual betting and baseline betting). Luck is what is left.
- Uses hindsight knowledge of all cards. Fine for long-run measurement, but per-decision verdicts that use the opponent's hidden cards would break our "no hidden cards" rule.
- Baseline uses simple threshold rules (fold below bs/(ps+bs) + offset), which look a lot like our rule-based bot.
- Empirical variance reductions of 5.50x to 6.34x in limit matches.
- Useful as a historical precedent and pitch line ("Alfred lost 11 sb but played +1.46 sb better").

Verdict: maybe. Good background and a good worked example; AIVAT (E03) is the method we should actually follow.

## Citation
- Darse Billings, Morgan Kan. "A Tool for the Direct Assessment of Poker Decisions." 2006.
- Journal version: ICGA Journal, vol. 29, no. 3, pp. 119-142, 2006, DOI 10.3233/ICG-2006-29302. UNVERIFIED: these journal details come from a web search summary; the IOS Press page https://content.iospress.com/articles/icga-journal/icg29302 returned HTTP 403, and the old cs.ualberta.ca PDF link redirected to a 404.
- Version we read: University of Alberta technical report TR06-07 (same title and authors, 2006), PDF headers say "ICGA Journal Submitted". Persistent DOI given on the repository page: https://doi.org/10.7939/R3PC2TC4D.
  - Fetched 2026-10-31: https://ualberta.scholaris.ca/handle/123456789/31340 (record page) and https://ualberta.scholaris.ca/bitstreams/9324a3cf-6ca9-468b-bf35-32f5672ac877/download (PDF, read as text; not saved in repo).
- Source type: technical report (submitted manuscript of a peer-reviewed journal paper). Content below is from the report; the journal version may differ slightly. Unsure.
- Citation count: not looked up.

## Claim status
| Claim | Status |
|---|---|
| The ROE (roll-out equity) DIVAT is statistically unbiased | Proved on paper by Zinkevich et al. (2006), cited by this paper (not reproved here; we did not open Zinkevich et al.). |
| DIVAT gives large variance reduction | Shown empirically (factors 5.50, 6.05, 6.34 below). |
| Baseline thresholds and offsets | Chosen by theory, then "verified and tuned empirically"; the tuning data is omitted from the paper. |
| The basic AIE (all-in equity) DIVAT | Not claimed unbiased; the paper calls ROE "better-informed and provably unbiased". |

## Setting and definitions
- Game: two-player Limit Texas Hold'em with reverse blinds (small blind 0.5 sb, big blind 1 sb; bets 1 sb in the first two rounds, doubled in the last two). Units: small bets (sb), and sb/g = small bets per game.
- Hindsight analysis: after the hand, look at both players' cards.
- All-in equity (AIE): fraction of future card outcomes a player wins, given all cards known. Net equity = AIE x pot - amount invested. Example in the paper: pot 10 sb, 11 of 44 outcomes win, 5 sb invested: Net = 0.25 x 10 - 5 = -2.50 sb.
- Roll-out equity (ROE): enumerate each future card outcome, with betting in each case set by a standard policy. Called "superior" and the version proved unbiased.
- DIVAT baseline betting sequence: what two "honest players" (no bluffs, no traps) would bet, given hand strength. Applied symmetrically to both players.
- DIVAT Difference (per round): the equity difference between the actual betting sequence and the baseline sequence. The sum over rounds gives the game total. Over many games the running total estimates the win rate difference.
- Dcash: what each player would win if both followed the baseline for the whole game; "Money minus Dcash" is another (biased-toward-baseline-style) lower-variance estimator.

## Constants and thresholds (copied)
- River fold policy: fold all hands with 7-card hand rank (7cHR) below `bs/(ps + bs)`, where bs = bet size, ps = pot size at the start of the river round. Example: pot 8 sb, bet 2 sb: fold below 0.20.
- Pre-river fold policy: `Fold Threshold = bs/(ps + bs) + offset`. Turn offset +0.10 (example becomes 0.30); flop offset +0.075 (0.275 when the initial pot is four bets); preflop no offset.
- Betting policy thresholds Make1..Make4 (bet, raise, re-raise, cap). Zero-EV equilibrium fractions for a 4-bet maximum: top 12/29, 5/12, 2/5 and 1/2 of the interval. River Make1 = 0.64 is about "top 41.4%" of the relevant interval; pre-river Make1 = 0.58 is about the top 41.4% of all holdings. The full Table 1 of thresholds per round was not in our text extract. Unsure of the other values.

## Main results (empirical)
- ALWAYS CALL vs ALWAYS RAISE, two 100,000-game matches: money SD about 6.856 sb/g; DIVAT Difference SD 2.934 and 2.917 sb/g; variance reduced by a factor of 5.50.
- PSOPTI4 self-play: money SD 4.691 sb/g; Money minus Dcash 2.825; DIVAT Difference 1.863 sb/g; 6.34-fold variance reduction.
- Another pair of matches: bankroll SD 4.750 / 4.747; Money minus Dcash 2.948 / 2.945; DIVAT 1.929 / 1.932 sb/g; 6.05-fold reduction.
- Worked example game: Alfred lost 11 sb on the hand but his decisions were worth about +1.46 sb (AIE DIVAT total +1.462 sb; ROE version +1.189 sb).

## Assumptions and limitations
- Needs all hole cards (hindsight). Hands that end without showdown hide the folder's cards: then DIVAT cannot be computed from a normal hand history. In a bot-vs-human app we log everything, so this is not a problem for data, but it is a problem for fairness of per-decision verdicts (see relevance).
- "Ignorant": ignores context and deception; a good bluff can be scored as a misplay in one round and recovered later. The paper says the per-game sum is more meaningful than single rounds.
- Limit hold'em only; no-limit bet sizing is not covered.
- Thresholds are partly empirical.

## What is formally verified
Nothing machine-checked. Unbiasedness proved on paper (by Zinkevich et al. 2006, AAAI-06, "Optimal unbiased estimators for evaluating agent performance", per the reference list of E03; not opened by us).

## Code artifacts and licenses
None found in the report.

## Relevance to our project
- Same goal as our luck-vs-skill graph; strong precedent and a nice pitch example.
- DIVAT's per-decision judgement uses the opponent's actual cards (hindsight). Our seed property says verdicts never depend on cards hidden at decision time. So we must NOT copy DIVAT's per-decision verdicts. Use AIVAT-style averaging over the bot's possible hands instead (E03). We can still show a hindsight "what if you had known" view, clearly labeled, but not as the grade.
- The baseline rules (fold below pot-odds threshold plus offset) are good inspiration for the bot's sliders and for a "simple honest player" reference.

## Candidate theorems for us
1. Hidden-card independence (the property DIVAT does not have): the label of a human decision is the same for any two deals that agree on everything the human could see.
   - Lean shape: `theorem verdict_ignores_hidden (s t : HandState) (h : s.humanView = t.humanView) (a : Action) : verdict s a = verdict t a`
   - Estimate: 1 to 3 h (near rfl if verdict is defined on `humanView`).
2. Per-round differences sum to the game total (DIVAT-style decomposition).
   - Lean shape: `theorem total_eq_sum_rounds (g : Game) : skillTotal g = (g.rounds.map roundDiff).sum`
   - Estimate: 1 h (if skillTotal is defined that way, it is a definition; make it a theorem only if the implementation computes the total differently).
3. Spec rejects a hindsight grader: a concrete example where a DIVAT-style hindsight grade differs between two deals with the same human view.
   - Lean shape: `example : ∃ s t, s.humanView = t.humanView ∧ hindsightGrade s a ≠ hindsightGrade t a := ⟨s0, t0, rfl, by decide⟩`
   - Estimate: 1 h.
