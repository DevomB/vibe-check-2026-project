# E02: Lichess Accuracy (win% from centipawns, per-move and game accuracy)

## Summary

**Source:** Lichess. "Accuracy." https://lichess.org/page/accuracy. Code: https://github.com/lichess-org/lila/blob/master/modules/analyse/src/main/AccuracyPercent.scala (AGPL)

TL;DR: Lichess publishes its full accuracy formula and code. Win% comes from a logistic curve on centipawns; per-move accuracy is an exponential of the win% drop; game accuracy averages a volatility-weighted mean and a harmonic mean.
- Win% = 50 + 50 * (2 / (1 + exp(-0.00368208 * centipawns)) - 1).
- Move accuracy (code) = clamp(103.1668100711649 * exp(-0.04354415386753951 * winDiff) - 3.166924740191411 + 1, 0, 100); exactly 100 when win% does not drop.
- The "+1 uncertainty bonus" plus clamp means a move that loses up to about 0.224 win% points still scores 100 (our arithmetic from the constants). So "100 iff no loss" is FALSE for Lichess. Our design should avoid this on purpose.
- Game accuracy = (volatility-weighted mean + harmonic mean) / 2, with window size clamp((n-1)/10, 2, 8) and weights = std. dev. of win% clamped to [0.5, 12].
- exp and floats make this hard to prove in Lean; use a rational formula instead.

Verdict: use. It is the only fully published accuracy formula; copy the shape, fix the "100 iff no loss" gap, and use rationals.

## Citation
- Org: Lichess (lichess.org), open-source server "lila".
- Pages fetched 2026-10-31:
  1. https://lichess.org/page/accuracy (official explanation page)
  2. https://github.com/lichess-org/lila/blob/master/modules/analyse/src/main/AccuracyPercent.scala (source code; the raw.githubusercontent.com URL failed with a certificate error, the GitHub blob page worked)
  3. https://github.com/lichess-org/lila (to read the license)
- Source type: official product docs + open-source code (non-academic). Not peer-reviewed.
- Year: undated page; code read from the `master` branch on 2026-10-31 (no commit hash recorded; unsure which commit).

## Claim status
| Claim | Status |
|---|---|
| Win% and per-move accuracy formulas below | Published by Lichess (page) and confirmed in code. The constants were fitted by Lichess; how is not shown. |
| "100% means you played all the preferred Stockfish moves" (page) | Product claim. The code shows it is only approximately true (see below). |
| A move losing up to about 0.224 win% points still gets 100 | Our own arithmetic from the code constants (Python, 2026-10-31). Not machine-checked. |
| Game accuracy aggregation | Read from code (window size, weight clamp, mean of two means). |

## Setting and definitions
- Plain words: the engine scores a position in centipawns (cp, hundredths of a pawn). Lichess turns that into a "win percent" for the side to move, then asks how much win% each move gave away. Small drop = high accuracy.
- Win% (page, exact): `Win% = 50 + 50 * (2 / (1 + exp(-0.00368208 * centipawns)) - 1)`
  - Example values we computed: cp 0 -> 50.0; cp 100 -> 59.103; cp 300 -> 75.113; cp 1000 -> 97.545.
  - Whether the code clamps cp first (for example to plus or minus 1000) was not visible: WinPercent.scala was not fetched. Unsure.
- Per-move accuracy (page): `Accuracy% = 103.1668 * exp(-0.04354 * (winPercentBefore - winPercentAfter)) - 3.1669`
- Per-move accuracy (code, exact lines quoted from AccuracyPercent.scala):
  - `val raw = 103.1668100711649 * Math.exp(-0.04354415386753951 * winDiff) + -3.166924740191411`
  - `raw + 1 // uncertainty bonus (due to imperfect analysis)`
  - `}.atMost(100).atLeast(0)` (clamp to 0..100)
  - If `after.value >= before.value` (win% did not drop) the function returns 100 directly.

## Game accuracy (code)
- `val windowSize = ((cps.size - 1) / 10).squeeze(2, 8)` : window length is (number of positions - 1) / 10, integer division, clamped to between 2 and 8.
- Sliding windows over the win% list; extra leading windows are built from prefixes so early moves get a window too.
- Weight of each window = standard deviation of its win% values, clamped: `Maths.standardDeviation(WinPercent.raw(wp)).so(_.squeeze(0.5, 12))`.
- Per color: `weighted <- Maths.weightedMean`, `harmonic <- Maths.harmonicMean`, then `AccuracyPercent((weighted + harmonic) / 2)`.
- Why (page): a simple average misleads when one side dominates or when one blunder happens in an otherwise equal game. The harmonic mean punishes a single very low move; the volatility weighting gives more weight to sharp phases.
- Phases: the code also computes accuracy for opening, middlegame and endgame separately.
- How the harmonic mean treats a 0 accuracy move: not visible. Unsure.

## Is accuracy exactly 100 when no win% is lost?
- If no win% is lost: yes, the code returns 100.
- Converse fails: raw(0) = 99.99989, so raw + 1 is about 100.99989 and clamps to 100. Solving raw(d) + 1 >= 100 gives d <= about 0.2237 win% points. So any move that loses less than about 0.22 win% also scores exactly 100. Sample values (our computation): loss 0.5 -> 98.778; 1 -> 96.604; 2 -> 92.395; 5 -> 80.815; 10 -> 64.580; 20 -> 41.017; 50 -> 9.528; 100 -> 0.
- Game accuracy 100 needs every move at 100 (both means are at most 100 and equal 100 only when all inputs are 100, assuming positive weights). So for Lichess, game accuracy 100 means "no move lost more than about 0.22 win%", not "no win% lost".

## Assumptions and limitations
- Depends on engine depth (cp values change with depth).
- Constants are empirical fits; no derivation.
- Uses floating point and exp. Hard to reason about exactly.
- Win% is from the mover's side; mate scores are handled by a separate path (`WinPercent.fromScore`) we did not read.

## What is formally verified
Nothing. Open-source code, no proofs.

## Code artifacts and licenses
- lila: AGPL-3.0 ("or any later version"), per the GitHub repository page. If we port the formula, port the idea (it is a math formula on a public page), not the Scala code, or comply with AGPL. Our project licence decision belongs to the lead.

## Relevance to our project
- The only fully published "accuracy" pipeline. Good template for our review screen: per-decision score, then a game score that punishes one huge blunder (harmonic mean).
- Their "+1 bonus then clamp" is exactly the kind of gap our seed theorem "accuracy is 100 exactly when no EV was lost" would catch. We should design a formula where per-decision accuracy is 100 iff EV loss is 0, and prove it.
- Avoid exp and floats in the verified core. Options: a rational curve such as `acc(loss) = 100 * k / (k + loss)` (k > 0, in bb), which is 100 iff loss = 0 and strictly decreasing; or a piecewise-linear table. Keep exp only in the GUI if at all.
- Aggregation: a plain mean or a harmonic mean over decisions is easy to prove things about; volatility windows add little for a poker hand with only a handful of decisions.

## Candidate theorems for us
1. Per-decision accuracy is 100 iff EV loss is 0 (for our rational formula).
   - Lean shape: `theorem acc_eq_100_iff (loss : Rat) (h : 0 ≤ loss) : decisionAccuracy loss = 100 ↔ loss = 0`
   - Estimate: 1 h.
2. Per-decision accuracy is strictly decreasing in loss and stays in [0, 100].
   - Lean shape: `theorem acc_strictAnti {a b : Rat} (ha : 0 ≤ a) (hab : a < b) : decisionAccuracy b < decisionAccuracy a` and `theorem acc_bounds (h : 0 ≤ loss) : 0 ≤ decisionAccuracy loss ∧ decisionAccuracy loss ≤ 100`
   - Estimate: 1 to 2 h.
3. Game accuracy is 100 iff no decision lost EV (mean version).
   - Lean shape: `theorem gameAcc_eq_100_iff (ls : List Rat) (hne : ls ≠ []) (h : ∀ l ∈ ls, 0 ≤ l) : gameAccuracy ls = 100 ↔ ∀ l ∈ ls, l = 0`
   - Estimate: 2 to 3 h (list sums over Rat; harmonic mean version: 3 to 5 h).
4. Bad-output test: show the Lichess-style "+1 then clamp" formula violates theorem 1 (a concrete loss > 0 gets 100). Useful as a "spec rejects bad behaviour" example in the talk.
   - Lean shape: `example : lichessStyle (1/10) = 100` with a rational stand-in for exp. Estimate: 0.5 h.
