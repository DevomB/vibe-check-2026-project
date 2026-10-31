# Summary: B02: Mathlib, Jensen's inequality and convexity (official library docs)

**Source:** Mathlib4 documentation, Mathlib.Analysis.Convex.Jensen. https://leanprover-community.github.io/mathlib4_docs/Mathlib/Analysis/Convex/Jensen.html


TL;DR: Mathlib (official docs, current master as served on 2026-10-31) has the finite Jensen inequality for concave and convex functions, strict versions, equality cases, and integral versions. The scalar type only needs to be an ordered field (`[Field 𝕜] [LinearOrder 𝕜] [IsStrictOrderedRing 𝕜]`), and `ℚ` has these instances. So Jensen works over `Rat`, which is what our bot will compute with.

- `ConcaveOn.le_map_sum` is the lemma for the discrete Pratt theorem (B01): sum of w_i * f(p_i) <= f(sum of w_i * p_i), weights >= 0 summing to 1.
- Strict and equality forms exist (`StrictConcaveOn.lt_map_sum`, `StrictConcaveOn.map_sum_eq_iff`).
- Nothing on utility, risk premium or Arrow-Pratt was found in the modules I opened.
- Mathlib is heavy. For the quadratic family (B01), Jensen reduces to E[X^2] >= 0, so we may not need Mathlib's Jensen at all.

Verdict: use (if the project already depends on Mathlib); otherwise "maybe": the quadratic-family proof can be done without it.


Full extraction: [notes.md](notes.md).
