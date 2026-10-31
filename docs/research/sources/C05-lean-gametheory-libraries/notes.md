# C05: Game theory libraries in Lean 4 (elazarg/GameTheory; math-xmum) and Isabelle (AFP Nash_Equilibrium)

## Summary (also in summary.md)
TL;DR: Lean 4 now has game theory libraries on Mathlib with von Neumann's minimax theorem and mixed Nash existence. elazarg/GameTheory (Apache-2.0, Lean v4.33.1) proves minimax for finite two-player zero-sum games with no `sorry` in that file. Isabelle's AFP has a 2026 Nash equilibrium entry.
- None of them mentions poker, CFR, exploitability, or Kuhn's theorem on behaviour strategies (from what I could see). Verified exploitability for a poker strategy would be new.
- Payoffs are real numbers (`ℝ`). Good for theory, but not computable. Our Kuhn/Leduc checks need exact `Rat` values to run `decide`.
- Toolchain clash: elazarg uses Lean v4.33.1 and math-xmum uses Lean/Mathlib v4.33.0. CLAUDE.md wants Lean 4.35 for Comparator. Importing either library would force a version mismatch. Read them; do not depend on them.
- Useful idea: "exploitability = 0" is the same as "this strategy guarantees the game value". Minimax says that value exists, so "unexploitable" has a clear meaning for a reviewer.

Verdict: maybe. Good to cite as prior work and as a spec reference. Do not import (toolchain mismatch, real numbers).

## Citations and URLs (all fetched 2026-10-31)
1. elazarg, "GameTheory: A comprehensive formalization of Game Theory in the Lean 4 proof assistant". Code repository. Author's name not shown in the README (points to `CITATION.cff`, not opened). License Apache-2.0. Reservoir says the latest commit 3dd93bf builds on Lean v4.33.1, updated 7 Sept 2026.
   - https://reservoir.lean-lang.org/@elazarg/GameTheory
   - https://github.com/elazarg/GameTheory (README)
   - https://github.com/elazarg/GameTheory/tree/main/GameTheory/Analysis (file list)
   - https://github.com/elazarg/GameTheory/blob/main/GameTheory/Analysis/Minimax.lean (theorem statements)
2. math-xmum (Ma Jiajun, Wang Haocheng, Zhang Xinyuan, Wang Xuhui), "GameTheory" (Lean 4). README says `GameTheory/Zerosum.lean` has "The complete proof of von Neumann's minimax theorem", strategy "via Loomis's theorem", planned "800+ lines". License inconsistent: README says MIT, sidebar says Apache-2.0.
   - https://github.com/math-xmum/GameTheory
   - A related Reservoir package by the same group, https://reservoir.lean-lang.org/@math-xmum/GameTheory , points to repo math-xmum/Brouwer (MIT, Lean 4.33.0, mathlib v4.33.0, updated 28 Oct 2026) with endpoint `ExistsNashEq : ∃ σ : G.mixedS, mixedNashEquilibrium σ` (Nash via Scarf → Brouwer).
3. Arthur Freitas Ramos, David Barros Hulak, Ruy Jose Guerra Barretto de Queiroz. "Nash Equilibria for Finite Games in Isabelle/HOL". AFP entry, 2026 (page date 7 May 2026). BSD license. Theories `Nash_Equilibrium`, `Mixed_Nash_Equilibrium`, `Nash_Equilibrium_Examples`. The authors say AI assistance was used for proof engineering and Isabelle checked the result.
   - https://www.isa-afp.org/entries/Nash_Equilibrium.html
   - https://www.isa-afp.org/topics/mathematics/games-and-economics/ (topic list: no poker, card game, chess, minimax or zero-sum entries by title; "Alpha-Beta Pruning" 2024 is the nearest to minimax search)
- Search result seen but NOT opened (UNVERIFIED): "Formalizing Scarf, Brouwer, and Nash in Lean", arXiv:2607.05987 (listed as ICML 2026).
- Bibliographic data only (abstract not shown, UNVERIFIED content): Parsert and Kaliszyk, "Towards Formal Foundations for Game Theory", ITP 2018, LNCS 10895, pp. 495–503, DOI 10.1007/978-3-319-94821-8_29 (page https://www.cs.ox.ac.uk/publications/publication16275-abstract.html fetched; it does not say which prover).
- Source type: code repositories and a formal proof archive entry. Not peer-reviewed papers (except AFP editorial review).

## Claim status
| Claim | Status |
|---|---|
| elazarg: every finite two-player zero-sum game has a value and a saddle point in mixed strategies (`exists_value`, `exists_isSaddlePoint`, `sup_lowerSecurityPayoffs_eq_inf_upperSecurityPayoffs`) | Machine-checked, Lean 4 v4.33.1 + Mathlib (file has no `sorry`; the saddle point comes from mixed Nash existence `exists_isNash_mixed`) |
| elazarg: mixed Nash existence, correlated equilibria, extensive-form encodings, backward induction, PPAD/NP-completeness | Claimed in README; not checked file by file |
| math-xmum: minimax via Loomis; Nash via Brouwer | Claimed in README; CI runs `nanoda` (an independent kernel checker) to reject `sorry`, per Reservoir |
| AFP Nash_Equilibrium: pure Nash existence for finite ordinal potential games and for games with dominant strategies; matching pennies has no pure equilibrium; mixed Nash existence via Brouwer | Machine-checked, Isabelle/HOL (Isabelle2026 release) |

## Setting and definitions
Plain words:
- Zero-sum two-player game: one player's gain is the other's loss. Heads-up poker is zero-sum (ignoring rake).
- Mixed strategy: a random choice among actions.
- Minimax theorem (von Neumann): in a finite zero-sum game there is a number v (the value) such that player 1 has a mixed strategy that guarantees at least v, and player 2 has one that holds player 1 to at most v.
- Saddle point: a pair of strategies where neither player can gain by changing alone.
- Exploitability of a strategy: how much less than the value it guarantees against a best-responding opponent. "Unexploitable" means exploitability 0.

Precise (elazarg `Minimax.lean`): `exists_value : ∃ (value : ℝ) (σ : Profile F.sig.mixed), expectedUtility utility 0 (F.mixed.play σ) = value ∧ ...` (remaining clauses not quoted by the fetch). Utility type `F.sig.Outcome → Fin 2 → ℝ`.

## Assumptions and limitations
- Strategic-form (matrix) games. Poker is an extensive-form game with hidden cards. Converting Kuhn poker to a matrix game is possible (each pure strategy = one action per information set; Kuhn has 2^6 = 64 pure strategies per player, a standard count I did not re-check against a source here), but these libraries do not do it.
- Real-number payoffs: proofs, not computation.
- Lean versions differ from ours.

## What is formally verified
See the claim table. Nothing about poker, CFR or exploitability found.

## Code artifacts and licenses
- elazarg/GameTheory: Apache-2.0. math-xmum/GameTheory: MIT or Apache-2.0 (inconsistent). math-xmum/Brouwer: MIT. AFP Nash_Equilibrium: BSD.

## Relevance to our project
- Gives a reviewer-friendly definition to copy: "strategy σ is unexploitable if for every opponent strategy τ, our expected payoff ≥ game value".
- Our cheapest honest Kuhn proof: do not prove minimax in general. Fix the known value (−1/18 for the first player in Kuhn poker, a standard result I did not re-verify here; check against a source) and prove both sides: our strategy gets at least the value against every pure opponent strategy, and some opponent strategy holds us to it. A finite check over pure strategies is enough, because the best response to a fixed strategy can always be pure (a standard fact; in our own setting we can prove it for the finite case or just check all pure strategies).

## Candidate theorems for us
| Plain English | Lean 4 shape (sketch) | Hours |
|---|---|---|
| Our Kuhn strategy guarantees the game value against every opponent | `theorem kuhn_guarantee : ∀ τ : PureStrat .p2, (-1 : ℚ)/18 ≤ ev kuhnσ τ` | 4–8 |
| No opponent mix does better than the best pure reply (so checking pure replies is enough) | `theorem mixed_le_best_pure (σ) (μ : MixedStrat .p2) : ev σ μ ≥ (pureStrats.map (ev σ)).minimum` | 3–6 |
| The value is tight: some opponent holds us to exactly −1/18 | `theorem kuhn_tight : ∃ τ, ev kuhnσ τ = -1/18` | 1 |
