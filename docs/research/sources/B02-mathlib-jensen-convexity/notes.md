# B02: Mathlib, Jensen's inequality and convexity (official library docs)

## Summary (also in summary.md)

TL;DR: Mathlib (official docs, current master as served on 2026-10-31) has the finite Jensen inequality for concave and convex functions, strict versions, equality cases, and integral versions. The scalar type only needs to be an ordered field (`[Field 𝕜] [LinearOrder 𝕜] [IsStrictOrderedRing 𝕜]`), and `ℚ` has these instances. So Jensen works over `Rat`, which is what our bot will compute with.

- `ConcaveOn.le_map_sum` is the lemma for the discrete Pratt theorem (B01): sum of w_i * f(p_i) <= f(sum of w_i * p_i), weights >= 0 summing to 1.
- Strict and equality forms exist (`StrictConcaveOn.lt_map_sum`, `StrictConcaveOn.map_sum_eq_iff`).
- Nothing on utility, risk premium or Arrow-Pratt was found in the modules I opened.
- Mathlib is heavy. For the quadratic family (B01), Jensen reduces to E[X^2] >= 0, so we may not need Mathlib's Jensen at all.

Verdict: use (if the project already depends on Mathlib); otherwise "maybe": the quadratic-family proof can be done without it.

## Citation

- The Mathlib Community, *Mathlib4 documentation*, modules `Mathlib.Analysis.Convex.Jensen`, `Mathlib.Analysis.Convex.Integral`, `Mathlib.Algebra.Order.Ring.Rat`. Official library documentation (not peer-reviewed). Version: whatever the docs site served on 2026-10-31 (current master); I did not record a commit hash. **Pin the Mathlib rev in our `lake-manifest.json` and re-check these names there.**

## URLs fetched (fetched 2026-10-31)

- https://leanprover-community.github.io/mathlib4_docs/Mathlib/Analysis/Convex/Jensen.html (read with curl; the fetch tool hit a certificate error, curl returned HTTP 200)
- https://leanprover-community.github.io/mathlib4_docs/Mathlib/Analysis/Convex/Integral.html (HTTP 200, lemma names listed)
- https://leanprover-community.github.io/mathlib4_docs/Mathlib/Algebra/Order/Ring/Rat.html (HTTP 200)
- https://leanprover-community.github.io/mathlib4_docs/Mathlib/Algebra/Order/Module/Defs.html (HTTP 200; the self-module instance)

## Claim status

All lemmas below are **machine-checked in Lean 4 / Mathlib** (they are library theorems). The claim "they apply to `ℚ`" is my reading of the instance requirements, plus the `ℚ` instances I saw in the docs; **not tested by compiling**. The instance `IsStrictOrderedModule ℚ ℚ` comes from the general instance `IsStrictOrderedRing.toIsStrictOrderedModule` (seen in the docs, see below). Still confirm with `#synth` on our pinned Mathlib.

## Setting and definitions

- **Convex function** on a set s: the chord between two points lies on or above the graph. **Concave**: on or below. Mathlib: `ConvexOn 𝕜 s f`, `ConcaveOn 𝕜 s f`, and strict forms `StrictConvexOn`, `StrictConcaveOn`. The set s must itself be convex.
- **Jensen's inequality (concave, finite form):** for weights w_i >= 0 summing to 1 and points p_i in s, the weighted average of f(p_i) is at most f of the weighted average of the p_i. In words: for a concave utility, the expected utility of a gamble is at most the utility of its expected value. This is "risk aversion".
- **Center of mass** (`Finset.centerMass`): the weighted average when weights need not sum to 1 (only to something positive).

## Main results (exact names and hypotheses as shown in the docs)

Variables in every lemma of `Mathlib.Analysis.Convex.Jensen`:
`{𝕜 E β ι} [Field 𝕜] [LinearOrder 𝕜] [IsStrictOrderedRing 𝕜] [AddCommGroup E] [AddCommGroup β] [PartialOrder β] [IsOrderedAddMonoid β] [Module 𝕜 E] [Module 𝕜 β] [IsStrictOrderedModule 𝕜 β] {s : Set E} {f : E → β} {t : Finset ι} {w : ι → 𝕜} {p : ι → E}`

Note: this is the newer "unbundled" style. Older Mathlib wrote `[LinearOrderedField 𝕜]`. If our pinned Mathlib is older, names of the classes differ but the lemmas are the same.

| Lemma | Hypotheses | Conclusion |
|---|---|---|
| `ConvexOn.map_sum_le` | `hf : ConvexOn 𝕜 s f`, `∀ i ∈ t, 0 ≤ w i`, `∑ i ∈ t, w i = 1`, `∀ i ∈ t, p i ∈ s` | `f (∑ i ∈ t, w i • p i) ≤ ∑ i ∈ t, w i • f (p i)` |
| `ConcaveOn.le_map_sum` | same, with `ConcaveOn` | `∑ i ∈ t, w i • f (p i) ≤ f (∑ i ∈ t, w i • p i)` |
| `ConvexOn.map_centerMass_le` / `ConcaveOn.le_map_centerMass` | weights >= 0, `0 < ∑ w` | same, with `t.centerMass w p` |
| `ConvexOn.map_add_sum_le`, `ConcaveOn.map_add_sum_le` | one point singled out with weight v | Jensen with a distinguished point |
| `StrictConvexOn.map_sum_lt` / `StrictConcaveOn.lt_map_sum` | strict convexity, all weights `> 0`, sum 1, and `∃ j ∈ t, ∃ k ∈ t, p j ≠ p k` | strict inequality |
| `StrictConcaveOn.map_sum_eq_iff` (and `_of_pos`, `_of_nonneg`, primed forms) | strict concavity, weights | equality iff all points equal the average |
| `StrictConcaveOn.lt_map_sum_iff_of_pos` (and variants) | | strict iff points not all equal |
| `ConvexOn.exists_ge_of_mem_convexHull`, `ConcaveOn.exists_le_of_mem_convexHull` | | maximum / minimum principle |
| `ConvexOn.le_max_of_mem_Icc`, `ConcaveOn.min_le_of_mem_Icc` | f on an interval of 𝕜 | max/min at an endpoint |

Integral versions (module `Mathlib.Analysis.Convex.Integral`, names seen): `ConvexOn.map_integral_le`, `ConcaveOn.le_map_integral`, `ConvexOn.map_average_le`, `ConcaveOn.le_map_average`, `ConvexOn.map_set_average_le`, `ConcaveOn.le_map_set_average`, `StrictConvexOn.ae_eq_const_or_map_average_lt`, `StrictConcaveOn.ae_eq_const_or_lt_map_average`. These are about measures and real-valued integrals; **we do not need them** (our lotteries are finite).

### Does Jensen hold over `ℚ`?

- The finite lemmas need only `[Field 𝕜] [LinearOrder 𝕜] [IsStrictOrderedRing 𝕜]`, i.e. an ordered field. No completeness, no reals.
- `Mathlib.Algebra.Order.Ring.Rat` provides `Rat.instIsStrictOrderedRing : IsStrictOrderedRing ℚ` and `Rat.instIsOrderedAddMonoid : IsOrderedAddMonoid ℚ`. Its header says ℚ is a linearly ordered field and that the field instance lives in `Mathlib/Algebra/Field/Rat.lean`.
- For f : ℚ → ℚ we take 𝕜 = E = β = ℚ. That also needs `IsStrictOrderedModule ℚ ℚ`. `Mathlib.Algebra.Order.Module.Defs` has `@[instance 100] instance IsStrictOrderedRing.toIsStrictOrderedModule {α} [Semiring α] [PartialOrder α] [IsStrictOrderedRing α] : IsStrictOrderedModule α α` (docs page https://leanprover-community.github.io/mathlib4_docs/Mathlib/Algebra/Order/Module/Defs.html, fetched 2026-10-31). So ℚ gets it from `Rat.instIsStrictOrderedRing`. Confirm with `#synth IsStrictOrderedModule ℚ ℚ` on our pinned Mathlib.
- So: yes, finite Jensen should apply to `ℚ`-valued utilities on `ℚ` chip amounts. The integral versions are for real-valued functions and measures, so they do not apply to `ℚ`.

## Assumptions and limitations

- The lemmas use `Finset` sums with an index type ι. Our lottery will likely be a `List (ℚ × ℚ)`. We need a small bridge (index by `Fin n`, or prove a list version of Jensen by induction).
- Concavity in Mathlib is on a set s that must be convex (`Convex 𝕜 s`). For chips we would use `Set.Icc 0 M` (an interval of ℚ, convex).
- Mathlib is a big dependency (build cache needed). CLAUDE.md says core plus Batteries is often enough. For the quadratic family the needed "Jensen" is just E[X^2] >= 0, provable by hand.

## What is formally verified

All listed lemmas are machine-checked in Lean 4 Mathlib (version as served on 2026-10-31). No Mathlib content on expected utility, risk premium, Arrow-Pratt, CARA/CRRA or certainty equivalents was seen in these modules. I did not search the whole library; "none found in the modules opened" only.

## Code artifacts and licenses

Mathlib is released under the Apache 2.0 license (my knowledge; I did not open the license file today: **unsure** as a fetched fact).

## Relevance to our project

- This is the proof engine for the general discrete Pratt theorem (B01, candidate 3).
- It confirms we can keep exact `Rat` arithmetic in the bot and still use library Jensen.

## Candidate theorems for us

1. **Jensen for list lotteries over ℚ** (bridge lemma): "the expected utility of a gamble is at most the utility of its average outcome, for a concave utility."
   ```lean
   theorem lottery_jensen {f : ℚ → ℚ} {M : ℚ} (hf : ConcaveOn ℚ (Set.Icc 0 M) f)
       (L : Lottery) (hL : L.WellFormed) (hmem : ∀ x ∈ L.outcomes, x ∈ Set.Icc 0 M) :
       L.expect f ≤ f (L.expect id)
   ```
   With Mathlib: 2-3 h (bridge `List` to `Finset`). Without Mathlib, by induction on the list for a hand-rolled `IsConcave` definition: 3-5 h.
2. **Discrete Pratt** (B01 candidate 3) on top of it: 2-3 h more.
3. **Sanity check** that the instance search works: `example : ConcaveOn ℚ (Set.Icc 0 1000) (fun x : ℚ => x - x^2 / 2000) := ...`. About 1 h (prove concavity of a quadratic directly from the definition).
