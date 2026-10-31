# C08: Verified game-tree search (Nipkow's Alpha-Beta, Isabelle AFP 2024), a published CFR+ proof error (JAIR 2019), and the chess / CFR gap

## Summary

**Source:** T. Nipkow. "Alpha-Beta Pruning." Archive of Formal Proofs, 2024. https://www.isa-afp.org/entries/Alpha_Beta_Pruning.html. Burch, Moravčík, Schmid. "Revisiting CFR+ and Alternating Updates." JAIR 64, 2019. https://arxiv.org/abs/1810.11542

TL;DR: Minimax search with alpha-beta pruning is machine-checked in Isabelle (Nipkow, 2024). Poker solving (CFR) has no machine-checked proof I could find. One published CFR+ bound had a wrong proof step that later work fixed (Burch, Moravcik, Schmid, JAIR 2019). For chess, I found only small projects (a Coq retrograde-analysis line, a Lean hackathon checker), not a verified move generator.
- Gap = novelty: no verified CFR, no verified exploitability or best-response computation, no verified poker engine.
- Good message for judges: "even the published proof for a top poker algorithm had a hole; we machine-check ours" (we check our Kuhn/Leduc strategy, not CFR itself).
- For our bot and review: computing a best response in Kuhn/Leduc is a finite tree walk. That is the same kind of proof as Nipkow's minimax work, but with information sets.
- Do not try to verify CFR convergence in 34 hours. Verify the output strategy instead (certificate check, see C04 and C05).

Verdict: maybe. Use it for novelty claims and the pitch; it gives no code for us to use.

## Citations and URLs (fetched 2026-10-31)
1. Tobias Nipkow. "Alpha-Beta Pruning". Isabelle AFP entry, 13 June 2024. BSD license. Theories: `Alpha_Beta_Linear`, `Alpha_Beta_Lattice`, `LaTeXsugar2`, `Alpha_Beta_Overview`, `TicTacToe`. Detailed presentation in the chapter "Alpha-Beta Pruning" of the forthcoming book "Functional Data Structures and Algorithms: A Proof Assistant Approach".
   - https://www.isa-afp.org/entries/Alpha_Beta_Pruning.html
2. Neil Burch, Matej Moravcik, Martin Schmid. "Revisiting CFR+ and Alternating Updates". Journal of Artificial Intelligence Research 64 (2019) 429–443. arXiv:1810.11542 (v1 26 Oct 2018, v2 19 Feb 2019). Peer-reviewed journal.
   - https://arxiv.org/abs/1810.11542
3. aastha-guptaa, "Lean-Hackathon" (a Lean 4 chess checker). Code repository, MIT license.
   - https://github.com/aastha-guptaa/Lean-Hackathon
- Seen in search results only, NOT opened (UNVERIFIED): Maliković and coauthors' Coq work on retrograde chess problems (CECIIS 2008, 2010); a 2012 CECIIS paper on the KRK chess ending in Coq (Janičić's page); a Dafny verification of minimax search with alpha-beta and transposition tables; Parsert and Kaliszyk, ITP 2018 (bibliographic data only, see C05).
- Citation counts: not looked up.

## Claim status
| Claim | Status |
|---|---|
| Fail-hard and fail-soft alpha-beta variants verified, over linear orders, distributive lattices, and domains with negative values | Machine-checked, Isabelle/HOL (AFP). The exact theorem statements were not on the page; I assume "alpha-beta returns the minimax value (in the fail-hard/fail-soft sense)" but that is unsure |
| The original CFR+ paper's bound had a flaw in one proof step; Burch et al. give corrected proofs that recover the bound | Proved on paper (peer-reviewed, JAIR) |
| Lean-Hackathon: Lean 4 checks that each move in an LLM-suggested sequence is legal and that the final position is checkmate | Stated in README; theorems not listed |
| No machine-checked CFR or exploitability computation exists | My search result (WebSearch, 2026-10-31); absence of evidence, not proof of absence |

## Setting and definitions
Plain words:
- Minimax search: in a two-player game where one player's gain is the other's loss, find the best move by assuming both sides play best. Alpha-beta pruning skips branches that cannot change the answer.
- CFR (counterfactual regret minimization): the standard algorithm that computes near-equilibrium poker strategies by repeated self-play updates. Its average strategy approaches an equilibrium; the "bound" says how fast.
- Exploitability: how much a best-responding opponent can win against a strategy, compared with the game value.
- Fail-hard / fail-soft: two ways alpha-beta reports a value when it cuts a branch (clamped to the search window, or a tighter bound outside it).

## Assumptions and limitations
- Alpha-beta work is for perfect-information trees (no hidden cards).
- The CFR+ paper is a paper proof, not machine-checked.

## What is formally verified
- Isabelle/HOL: alpha-beta variants (Nipkow). Nothing for CFR or poker.

## Code artifacts and licenses
- AFP Alpha_Beta_Pruning: BSD. Lean-Hackathon: MIT.

## Relevance to our project
- Novelty statement we can make (with "to our knowledge"): no prior machine-checked poker engine, hand evaluator, or poker strategy exploitability result.
- The game review grades moves by EV loss. If the review uses exact enumeration (see C06 counts), the property "the review's EV for each action equals the exact average over all runouts" is a finite-tree statement like minimax, and is provable.

## Candidate theorems for us
| Plain English | Lean 4 shape (sketch) | Hours |
|---|---|---|
| Our best-response routine for Kuhn/Leduc gives the highest expected value among all pure replies | `theorem br_optimal (σ : Strategy) : ∀ τ : PureStrat, ev σ τ ≥ ev σ (bestResponse σ)` (opponent minimizes our EV) | 4–8 |
| Exploitability of our strategy is zero: best response gets exactly the game value | `theorem exploitability_zero : ev kuhnσ (bestResponse kuhnσ) = -1/18` | 1–3 after the above |
| The review's EV for an action equals the exact average over all runouts | `theorem reviewEV_exact (s : Spot) (a : Action) : reviewEV s a = (runouts s).sum (payoff s a) / (runouts s).length` | 3–6 |
