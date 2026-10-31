# C04: Ramos and Soria, "From Rules to Nash Equilibria: A Lean 4 Case Study ... Trading Card Game" (2026)

## Summary (also in summary.md)
TL;DR: A 2026 preprint that checks, in Lean 4, Nash equilibrium claims about the Pokémon Trading Card Game's tournament "metagame" (which decks to bring). It is the closest prior work to ours: a card game plus game theory in Lean. It is not poker, and it does not verify a game engine.
- Their method matches ours: an untrusted solver (Python `linprog`) finds a candidate equilibrium, and Lean checks it by testing every pure-strategy deviation. We can do the same for Kuhn/Leduc: compute the strategy outside the proof, then prove "no deviation helps" in Lean.
- They use `native_decide` for the headline results (145 of 2,627 theorems). That trusts the compiler. Comparator / `lake check` may reject it, so we must decide early.
- They formalize only a "strategic layer" of the rules (deck legality, some card-flow facts), not a full rules engine. A verified poker engine (chip conservation, legal actions, side pots) is still open ground.
- No public repo or license yet ("anonymized supplementary material").

Verdict: use. Cite it as the nearest prior work, and copy its "untrusted solver, Lean checks the certificate" pattern.

## Citation
- Arthur F. Ramos, Tulio Soria. "From Rules to Nash Equilibria: A Lean 4 Case Study in Game-Theoretic Analysis of a Competitive Trading Card Game". arXiv:2607.08692 [cs.GT; cross-list cs.FL], v1 9 July 2026. 13 pages, 3 figures, 10 tables. Paper license CC BY 4.0.
- Preprint (no journal reference shown).
- Source type: academic preprint with a Lean artifact.
- Note: Arthur Freitas Ramos is also an author of the AFP entry "Nash Equilibria for Finite Games in Isabelle/HOL" (2026), see C05.
- URLs fetched 2026-10-31: https://arxiv.org/abs/2607.08692 ; https://arxiv.org/html/2607.08692 (full text, first 100,000 of 105,495 characters read)
- Citation count: not looked up.

## Claim status
| Claim | Status |
|---|---|
| A Nash equilibrium of the 14×14 raw matchup game, with the top deck (Dragapult) at 0% weight | Machine-checked in Lean 4, via `native_decide` (trusts the compiler) |
| Unique symmetric Nash equilibrium of the constant-sum symmetrized game, 7 decks in its support | Machine-checked, by enumerating all 2^14 − 1 = 16,383 supports, via `native_decide` |
| Replicator dynamics push Dragapult down and Grimmsnarl up | Machine-checked statements about a fixed computation (`native_decide`) |
| "Popularity paradox": Dragapult has 15.5% share but 46.7% expected win rate; Grimmsnarl 5.1% share, 52.7% | Data facts checked in Lean; the data itself (Trainer Hill, Jan–Feb 2026, events with at least 50 players) is not verified |
| 10,000-iteration sensitivity analysis is qualitatively stable | Shown empirically |
| Artifact: 87 files, about 31,900 lines, 2,627 theorems, no `sorry`/`admit`/custom axioms; 145 theorems use `native_decide`, 2,482 kernel-checked; `lake build` about 10 minutes | Stated by the authors |

## Setting and definitions
Plain words:
- The "game" is choosing a deck for a tournament. The payoff of deck A against deck B is A's win rate against B, measured from real tournaments.
- A mixed strategy is a probability mix of decks. A Nash equilibrium mix: no single deck does better against the mix than the mix does against itself.
- Constant-sum symmetrization: they adjust the matrix so that the two win rates in each matchup add to a constant (game value 500 on a 0–1000 scale).
- Replicator dynamics: a simple model of how deck shares change over time (decks that win more grow).

Precise: a 14×14 matrix of win rates stored as exact numbers (the text says both Lean `Rat` and "natural numbers on a 0–1000 scale", which is inconsistent; unsure which is used where). A predicate `NashEquilibrium` is applied to the matrix. Lean checks the best-response condition against all 14 pure strategies.

Key theorem names in the paper: `real_nash_equilibrium_verified`, `symmetric_nash_equilibrium_verified`, `symmetric_nash_dragapult_strict_gap` (40.4‰ below the value 500), `dragapult_strictly_suboptimal`, `full_replicator_dragapult_decline`, `full_replicator_grimmsnarl_fittest`, `rat_replicator_sign_independent_of_dt`, `checkDeckLegal_iff`, `professorsResearchEffect_preserves_cards`, `the_complete_story`.

## Main algorithm (certificate checking)
1. Solve for a candidate equilibrium outside Lean (Python `scipy.optimize.linprog`, untrusted).
2. Write the candidate as exact fractions in Lean.
3. Prove in Lean that no pure strategy beats the candidate (a finite check, 14 cases), using `native_decide`.
4. For uniqueness: check all 16,383 possible supports.

## Assumptions and limitations
- The game is a small matrix game (one simultaneous choice). Not an extensive-form game with hidden cards like poker.
- The data is trusted. The rules are only partly formalized.
- `native_decide` adds a compiler-trust axiom to 145 theorems. Our CLAUDE.md allows it only if we accept it early; `lake check` may reject it.
- Lean version not stated in the text. No repo link or code license.

## What is formally verified
- Lean 4 (version unknown): equilibrium certificates, replicator facts, deck legality checker correctness (`checkDeckLegal_iff`), some card-flow invariants. Mathlib is mentioned only as future work for interval arithmetic.

## Code artifacts and licenses
- Artifact said to be supplementary material; data on IEEE DataPort. No license found for the code. Paper text CC BY 4.0.

## Related work they cite (not opened by me, UNVERIFIED)
- Li, Parsert, Eisenhofer (2023), "Towards formal verification of card game mechanics" (extended abstract). My search could not find it.
- AI poker papers (Bowling et al. 2015; Brown and Sandholm 2018, 2019): empirical, not formal verification.

## Relevance to our project
- Novelty check: this is a card game in Lean, but not poker, and not a verified engine. Our claims (chip conservation, legal actions, verified shuffle, verified evaluator, Kuhn/Leduc unexploitability) are not covered.
- The "solver outside, certificate inside" pattern fits Kuhn poker: Kuhn poker's equilibrium family is known in closed form (a parameter α in [0, 1/3]), so we can write the strategy as exact fractions and prove a best-response check in Lean.
- Kuhn poker is small (12 deals, a handful of information sets), so the check may run under kernel `decide` on `Rat` without `native_decide`. Unsure; test early.

## Candidate theorems for us
| Plain English | Lean 4 shape (sketch) | Hours |
|---|---|---|
| Against our Kuhn strategy, no opponent strategy wins more than the game value (−1/18 for player 1) | `theorem kuhn_unexploitable : ∀ τ : PureStrategy P2, value kuhnStrategy τ ≥ -1/18` (finite: enumerate all pure strategies of the opponent) | 4–8 (if `decide` works on `Rat`), more if a general proof is needed |
| Same for the other seat | `theorem kuhn_unexploitable_p2 : ∀ σ : PureStrategy P1, value σ kuhnStrategyP2 ≤ -1/18` | 2–4 after the first |
| The spec rejects a bad strategy: "always bet" is exploitable | `theorem alwaysBet_exploitable : ∃ τ, value alwaysBet τ < -1/18` | 1 |
