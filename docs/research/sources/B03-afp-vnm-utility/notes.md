# B03: Isabelle AFP, "Von-Neumann-Morgenstern Utility Theorem" (Parsert and Kaliszyk, 2018)

## Summary

**Source:** Parsert, Kaliszyk. "Von-Neumann-Morgenstern Utility Theorem." Archive of Formal Proofs, 2018. https://www.isa-afp.org/entries/Neumann_Morgenstern_Utility.html

TL;DR: The only proof-assistant formalization of expected utility I found is this Isabelle/HOL entry in the Archive of Formal Proofs. It proves the von Neumann-Morgenstern theorem: for a finite, non-empty set of outcomes, a preference over lotteries is rational, independent and continuous exactly when it is ranked by expected utility. It has **no risk aversion, no concavity, no Arrow-Pratt, no Pratt theorem**.

- Machine-checked (Isabelle/HOL, AFP). License LGPL. Utilities are `real`-valued; lotteries are `pmf`s.
- It justifies "the bot ranks options by expected utility" as a sensible model of a rational player, but we would not port it.
- So a Lean proof of a discrete Pratt theorem would be, as far as I found, new in a proof assistant. That is a good line for the pitch, but say "we found no prior formalization", not "first ever".
- Lean Reservoir and Coq/Rocq: **not checked** (Reservoir search is rendered by JavaScript and did not answer my query; no time for Rocq).

Verdict: maybe. Good for the related-work slide and the "no prior formal Pratt" claim; nothing to reuse in code.

## Citation

- Julian Parsert and Cezary Kaliszyk, "Von-Neumann-Morgenstern Utility Theorem", *Archive of Formal Proofs*, July 4, 2018. AFP entry (refereed formal-proof archive, not a journal paper). Topic: Mathematics/Games and economics. License: GNU LGPL (as shown on the entry page).

## URLs fetched (fetched 2026-10-31)

- https://www.isa-afp.org/entries/Neumann_Morgenstern_Utility.html (entry page: title, authors, date, abstract, license, theory list)
- https://isa-afp.org/browser_info/current/AFP/Neumann_Morgenstern_Utility/Expected_Utility.html (theory text)
- https://isa-afp.org/browser_info/current/AFP/Neumann_Morgenstern_Utility/Neumann_Morgenstern_Utility_Theorem.html (theory text)
- https://isa-afp.org/topics/mathematics/games-and-economics/ (topic listing)
- Tried and failed: Lean Reservoir search (https://reservoir.lean-lang.org/..., page is JavaScript; API path returned 404).

## Claim status

- vNM theorem for finite outcomes: **machine-checked, Isabelle/HOL** (AFP "current" release as served on 2026-10-31; exact Isabelle version not recorded).
- "No risk-aversion content": my reading of the lemma names in `Expected_Utility` and `Neumann_Morgenstern_Utility_Theorem` (no lemma mentions concavity or risk). **Shown by inspection, not exhaustive** (I listed the definitions and lemmas, not every line).

## Setting and definitions (plain words, then precise)

- A **lottery** is a probability distribution over a set of outcomes. Here: `'a pmf` (probability mass function), restricted to `lotteries_on outcomes`.
- A **preference** is a relation "p is at least as good as q", written `p ≽[P] q`.
- **Rational**: complete and transitive (`rational_preference`).
- **Independence** (`independent_vnm`): mixing both lotteries with the same third lottery r, with weight α in (0, 1], does not change which one you prefer.
- **Continuity** (`continuous_vnm`): if p ≽ q ≽ r, then some mix of p and r (weight α in [0, 1]) is exactly as good as q.
- **vNM utility** (`locale vNM_utility`): a function u : 'a → real with p ≽ q iff E_p[u] >= E_q[u].

## Main result (as stated in the theory file)

`theorem Von_Neumann_Morgenstern_Utility_Theorem`: assuming `finite outcomes` and `outcomes ≠ {}`,
rational ∧ independent ∧ continuous (on `lotteries_on outcomes`) **iff** there exists u such that the preference is an ordinal utility given by `λx. measure_pmf.expectation x u`.

Other named results seen: `vNM_utility_implies_independence`, `is_linear`, `expected_utilty_theorem_form_vnm_utility` (spelling as in the source), `vnm_utility_is_ordinal_utility`, `expected_utility_weak_preference`, `expected_utility_strict_preference`, `strict_alt_def_utility_g`.

## Assumptions and limitations

- Finite outcome set. Utilities and weights are `real`.
- Nothing about money, wealth, concavity or risk premia. No comparative statements between two decision makers.

## What is formally verified

The full vNM representation theorem (both directions), machine-checked in Isabelle/HOL.

## Related entries seen in the topic listing (listing only, entries not opened)

"Actuarial Mathematics" (Ito and Hirata, 2026), "Nash Equilibria for Finite Games in Isabelle/HOL" (Ramos, Hulak and de Queiroz, 2026), "Risk-Free Lending" (Doty, 2022), "Arbitrage Opportunities Correspond to Probability Inequality Identities" (Doty, 2026), "Pricing in discrete financial models" (Echenim, 2018), "Microeconomics and the First Welfare Theorem" (Parsert and Kaliszyk, 2017). The Nash-equilibrium entry may interest whoever covers Kuhn/Leduc unexploitability.

## Code artifacts and licenses

Isabelle theories, LGPL. Not reusable from Lean directly.

## Relevance to our project

- Related work only. It supports the modeling choice "the bot maximizes expected utility" and our claim that formal Pratt-style results are not yet in proof assistants (as far as we searched).

## Candidate theorems for us

1. **Expected-utility ranking respects dominance** (Lean analogue of a small part of this entry, specialized to chips): "If one gamble pays at least as much as another in every outcome, an increasing-utility bot never prefers the worse one."
   ```lean
   theorem eu_monotone {u : ℚ → ℚ} (hu : Monotone u) (L : Lottery) (f g : ℚ → ℚ)
       (hL : L.WellFormed) (hfg : ∀ x, f x ≤ g x) :
       L.expect (u ∘ f) ≤ L.expect (u ∘ g)
   ```
   1-2 h. Useful as the "spec rejects bad behaviour" partner to the mean-variance counterexample (B01).
2. Porting the full vNM theorem: not worth it in 34 hours (estimate 20+ h).
