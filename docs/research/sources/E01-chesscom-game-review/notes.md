# E01: Chess.com Game Review: move labels and Accuracy (CAPS2)

## Summary (also in summary.md)
TL;DR: Chess.com labels each move by "expected points" lost (0.00 to 1.00 scale, from engine eval plus player rating) using a fixed table. Accuracy (CAPS2) is 0 to 100 but its formula is not published.
- The label table: Best 0.00; Excellent 0.00-0.02; Good 0.02-0.05; Inaccuracy 0.05-0.10; Mistake 0.10-0.20; Blunder 0.20-1.00 (expected points lost).
- Best means exactly zero loss. We can copy this and prove `label = Best ↔ loss = 0`.
- Their ranges share endpoints and the page does not say which label a boundary value gets. Use half-open ranges in bb; prove the labeling is total and monotone.
- Great, Brilliant and Miss use extra verbal rules; skip them or define them precisely.
- Accuracy formula is secret, so "100 iff no loss" cannot be checked for chess.com. For us it can be a theorem.

Verdict: use. It defines the UX we copy and shows which parts (labels, 100 = no loss) we can make exact.

## Citation
- Org: Chess.com (support / help center articles). No named authors.
- Pages (all three fetched 2026-10-31):
  1. "How are moves classified? What is a blunder or brilliant, etc.?" https://support.chess.com/en/articles/8572705-how-are-moves-classified-what-is-a-blunder-or-brilliant-and-etc
  2. "What is Accuracy in Analysis? How is it measured?" https://support.chess.com/en/articles/8708970-what-is-accuracy-in-analysis-how-is-it-measured
  3. "How does Game Review work?" https://support.chess.com/en/articles/8584089-how-does-game-review-work
- Source type: official product docs (non-academic). No citation count (not applicable).
- Year: pages are undated in what we saw. Treat as "current as of 2026-10-31".

## Claim status
| Claim | Status |
|---|---|
| Move labels come from "Expected Points" lost, with the fixed ranges in the table below | Product documentation (vendor's own description). Not checked by us. |
| Expected Points depends on player rating and engine evaluation | Product documentation. The model itself is not published. |
| Accuracy (CAPS2) of 100 means engine-perfect play | Product documentation. Formula not published. |
| Great / Brilliant / Miss use extra rules, not just points lost | Product documentation. No numeric rules given. |

## Setting and definitions
- Plain words: after a game, an engine looks at each move and asks "how much did this move lower your chance of scoring?" The answer, in "expected points", picks a label.
- Expected Points: a number from 0.00 to 1.00. 1.00 = certain win, 0.00 = certain loss, 0.50 = even. It is computed from the engine evaluation and the player's rating (page 1). So the same engine evaluation can map to different expected points for players of different ratings.
- Expected points lost by a move = expected points before the move minus expected points after it (our reading of "how expected points changed").

## Main results / thresholds (copied from page 1)
| Label | Expected points lost |
|---|---|
| Best | 0.00 to 0.00 |
| Excellent | 0.00 to 0.02 |
| Good | 0.02 to 0.05 |
| Inaccuracy | 0.05 to 0.10 |
| Mistake | 0.10 to 0.20 |
| Blunder | 0.20 to 1.00 |

- Units: expected points (a fraction of one game point). Not centipawns, not win percent.
- Boundaries: the page lists closed ranges that share endpoints (for example 0.02 is in both Excellent and Good). It does not say which label a value exactly on a boundary gets. Unsure.
- Special labels (page 1), with no numeric cutoffs:
  - Great: a move critical to the outcome (turns losing into equal, equal into winning, or is the only good move). Labeling is "more generous" for new players.
  - Brilliant: best or nearly best, and a good piece sacrifice; the player must not be in a bad position afterwards and must not already be completely winning. Also more generous for new players.
  - Miss: failing to punish the opponent's mistake.
- Page 3 lists ten labels with one-line descriptions, in this order: Brilliant, Great, Best, Excellent, Good, Book ("A conventional opening move"), Inaccuracy, Mistake, Miss, Blunder.
- Page 3: the quick summary shown at game end uses faster analysis, so a label "may later be classified differently after the full review". Analysis settings vary by device and chosen engine strength; paid members can pick "Deep and Maximum".

## Accuracy (CAPS2), from page 2 and page 3
- Scale 0 to 100. 100 corresponds to engine-perfect play "against your opponent's specific moves".
- CAPS2 replaced the original "Computer Accuracy Precision Score" (CAPS). The page says "the math on how these are calculated has changed", but gives no formula and no constants.
- Design intent stated: scores should feel like a school test grade, most between roughly 50 and 95.
- Page 3: Accuracy "represents how accurately you played according to the engine's evaluations"; it is not your rating. A separate "Game Rating" estimates how well you played in one game.
- Is Accuracy exactly 100 when no expected points were lost? Not stated. Unsure. Because the formula is secret we cannot check it.

## Assumptions and limitations
- The Expected Points model (rating to win chance) is not published. Labels are only as good as that model and the engine depth.
- Labels depend on rating, so they are not a pure function of the position.
- The special labels (Great, Brilliant, Miss) use rules the page describes only in words.
- Results can change between the quick summary and the full review (different analysis depth).

## What is formally verified
Nothing. These are product docs. No proofs, no published code.

## Code artifacts and licenses
None published.

## Relevance to our project
- This is the user-facing model we are copying: a fixed table from "loss" to label. Our loss is EV loss in big blinds (bb), not expected points.
- Lesson 1: chess.com uses loss ranges, with Best = exactly zero loss. We can do the same and prove it.
- Lesson 2: their boundary rule is ambiguous. We should use half-open ranges (for example Good = loss > 0 and loss <= 0.5 bb) and prove the label function is total (every loss gets one label) and monotone (more loss never gets a better label).
- Lesson 3: their Accuracy formula is secret, so "100 means no loss" cannot be checked for chess.com. Ours can be a theorem.
- Our labels can be exact (not engine-depth dependent) for all-in and river spots because our opponent is known code.
- Thresholds in bb are our choice. Chess.com's ratios (Good up to 5% of a game point, Blunder from 20%) do not transfer directly; pick bb cutoffs and maybe scale by pot size. Decide this as a team; it is part of the spec.

## Candidate theorems for us
1. Label is Best exactly when no EV was lost.
   - Lean shape: `theorem label_best_iff (loss : Rat) (h : 0 ≤ loss) : label loss = .best ↔ loss = 0`
   - Estimate: 0.5 to 1 h.
2. Labels are monotone: losing more never earns a better label.
   - Lean shape: `theorem label_monotone {a b : Rat} (h : a ≤ b) : (label b).rank ≤ (label a).rank`
   - Estimate: 1 to 2 h (case split on the threshold comparisons).
3. Every non-negative loss gets exactly one label, and the label matches the published table (spec as a table, implementation as nested ifs).
   - Lean shape: `theorem label_matches_table (loss : Rat) (h : 0 ≤ loss) : inRange (label loss) loss` plus `theorem ranges_disjoint ...`
   - Estimate: 1 to 2 h.
4. Bad-output check (CLAUDE.md section 4): `example : label 3 ≠ .best := by decide`, `example : ¬ inRange .good 5 := by decide`.
   - Estimate: 0.25 h.
