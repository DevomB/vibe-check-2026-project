# E05: Poker review tools: GTO Wizard Analyzer, PokerTracker 4 All-in Equity graphs, RTA policies

## Summary

**Source:** GTO Wizard Help Center. "How To Work With Analyze Mode." https://help.gtowizard.com/how-to-use-the-hand-history-analyzer/. PokerTracker 4. "All-in Equity Graphs." https://docs.pokertracker.com/pt4/tutorials/hand-analysis-and-tools/all-in-equity-graphs/

TL;DR: GTO Wizard's analyzer reports EV loss per action in big blinds and colors actions green / yellow (inaccuracy) / red (blunder), but publishes no numeric thresholds. PokerTracker 4's "All-in Equity" line replaces the result of all-in hands by (equity x pot - amount bet), using the opponent's actual cards; it is explicitly a luck measure.
- EV loss in bb per decision is the industry unit (GTO Wizard: "lost 7.65 bb"). Good, matches our plan.
- No public tool gives label thresholds in bb. We must choose and justify our own; they are part of the spec.
- GTO Wizard grades against pre-solved GTO solutions (preflop to turn) and an exact river solve; bet sizes are snapped to the nearest solved size. Our grades are against our known bot instead: stronger claim (exact best response) for river and all-in spots.
- PokerTracker excludes hands with unknown hole cards and multiway hands with unequal stacks. Its all-in equity uses the opponent's real cards: fine for a luck graph, wrong for a decision grade.
- Real-time assistance (RTA) is banned by GTO Wizard's terms (per press report) and by sites such as ACR. Our "live hints" are fine against our own bot in our app, but say so in the pitch.

Verdict: use. It sets the units (bb), the UX (three colors, EV-loss filter) and the luck-graph convention we should match.

## Citations (all non-academic; fetched 2026-10-31)
1. GTO Wizard Help Center, "How To Work With Analyze Mode". https://help.gtowizard.com/how-to-use-the-hand-history-analyzer/ . Official product docs.
2. GTO Wizard Help Center, "Analyze Mode Overview". https://help.gtowizard.com/analyze-mode-guide/ . Official product docs.
3. GTO Wizard Help Center index: https://help.gtowizard.com/ (to list articles).
4. PokerTracker 4 docs, "All-in Equity Graphs". https://docs.pokertracker.com/pt4/tutorials/hand-analysis-and-tools/all-in-equity-graphs/ (the old URL https://www.pokertracker.com/guides/PT4/tutorials/all-in-equity-graphs redirects here). Official product docs.
5. PokerNews, "GTO Wizard Review 2026", Matthew Pitt (Senior Editor), published Apr 17, 2025, updated Sep 17, 2026. Fetched at https://www.pokernews.com/news/promotions/2025/11/pokerarena-season-5-goes-live-gto-wizard-49977.htm (the page served this review article). Press / affiliate review (non-academic, possibly commercial).
- Not opened: GTO Wizard's own Terms & Conditions (two guessed URLs returned 404). Hold'em Manager 3 docs (not reached; time). ACR's RTA statement (seen only in a search snippet from gambling911.com; UNVERIFIED, not counted).

## Claim status
| Claim | Status |
|---|---|
| GTO Wizard shows EV loss per action, in bb | Official docs (example "lost 7.65 bb", "(765 bb/100 error)"). |
| GTO Wizard colors: green = correct, yellow = inaccuracy, red = blunder | Official docs. No numeric cutoffs published. |
| GTO Wizard compares to presolved solutions preflop-turn, exact river calculation | Official docs. |
| An overall stat review vs GTO is "Coming soon" | Official docs (overview page, as of fetch date). |
| PokerTracker All-in Equity = equity in pot - total amount bet | Official docs (example: $165.20 - $100 = +$65.20). |
| PokerTracker excludes hands with unknown hole cards and unequal-stack multiway all-ins | Official docs. |
| GTO Wizard forbids RTA in its Terms & Conditions | Press report (PokerNews). Not confirmed on GTO Wizard's own T&C page. |

## Setting and definitions
- EV loss (GTO Wizard): how much less a chosen action is worth than the best action, in big blinds, against the solver's (GTO) strategy. The docs show it per action and allow filtering and sorting by EV loss. "bb/100" = big blinds per 100 hands (a win-rate unit); a single 7.65 bb loss is shown as 765 bb/100.
- GTO solution: a precomputed near-equilibrium strategy. GTO Wizard snaps your bet size to the closest solved size and shows the mismatch in parentheses. Statuses: "Analyzed", "Non-existing GTO spot", "Error". Multiway postflop hands are skipped. Some hands get partial solutions (e.g. after an action the GTO strategy never takes). Rake and stack size are read from the hand history.
- All-in Equity (PokerTracker 4): for hands where players were "effectively all-in", the graph plots equity-adjusted winnings instead of actual results. Equity is computed "at the point of the all-in" with everyone's actual cards. Formula (docs): All-in Equity = (your equity share of the pot) - (total amount you bet). Lines named on the page: "Amount Won" and "All-in Equity" (colors not stated). Non-all-in hands use actual results on both lines.
- RTA (real-time assistance): software advice during a live hand. Banned on real-money sites.

## Main results / thresholds
- GTO Wizard: no numeric thresholds for inaccuracy vs blunder found. Unsure how they are set.
- PokerTracker: the only formula is the equity line above; the docs example assumes "the blinds cover the rake to keep the math simple"; multiway is supported only if all stacks are equal.

## Assumptions and limitations
- GTO Wizard grades against GTO play, not against your actual opponent. A "mistake" vs GTO can be the best play against a weak opponent. Against our known bot, the exact best response is the right reference.
- Bet-size snapping and abstraction make GTO Wizard grades approximate.
- PokerTracker's all-in equity uses the opponent's actual hand: correct as a luck measure (the docs call it a luck measure, not forward-looking expectation), but it depends on hidden cards, so it must not be used as a decision grade.

## What is formally verified
Nothing. Commercial tools; closed source.

## Code artifacts and licenses
None (closed source).

## Relevance to our project
- Units: grade in bb, show bb/100 optional. Matches industry.
- UX: three colors are the norm in poker; chess-style five labels are our differentiator. Keep Best = 0.00 bb loss exactly.
- Luck graph: PokerTracker's "Amount Won vs All-in Equity" is the familiar picture. Ours generalizes it: luck terms at every chance and bot event (AIVAT, E03), not only at all-in, and we prove "EV line + luck = actual line".
- Our exactness claim (river and all-in spots exact, because the opponent is known code) is stronger than GTO Wizard's, which approximates sizes and uses GTO not the real opponent. Good pitch point.
- Live hints: only against our own bot in our own play-money app. State in README that it must not be used on real-money sites.

## Candidate theorems for us
1. All-in luck term matches the PokerTracker convention: at an all-in with known cards, luck = actual chips won - (equity x pot - invested).
   - Lean shape: `theorem allin_luck (pot invested won : Rat) (eq : Rat) : won = (eq * pot - invested) + allInLuck pot invested won eq` (definition-level), plus `theorem allin_luck_mean_zero` as a weighted sum over runouts: `(runouts.map fun r => prob r * (payoff r - expected)).sum = 0`.
   - Estimate: 2 to 4 h (the mean-zero part over a finite list of runouts with exact probabilities).
2. Equity by exact enumeration equals the fraction of winning runouts (no sampling in the verified core).
   - Lean shape: `theorem equity_def (s : AllInState) : equity s = (winShare s) / (runouts s).length`
   - Estimate: 2 to 6 h depending on the hand evaluator's proofs (needs ties handled as split pots).
3. EV loss is non-negative and zero for the best action (shared with E01/E03).
   - Lean shape: `theorem evLoss_nonneg (q : Action → Rat) (legal) (a ∈ legal) : 0 ≤ evLoss q legal a`
   - Estimate: 1 h.
