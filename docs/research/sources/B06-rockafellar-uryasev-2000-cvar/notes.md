# B06: Rockafellar and Uryasev (2000), "Optimization of Conditional Value-at-Risk"

## Summary

**Source:** Rockafellar, Uryasev. "Optimization of Conditional Value-at-Risk." The Journal of Risk 2(3), 2000, pp. 21-41. https://doi.org/10.21314/JOR.2000.038

TL;DR: The standard paper on CVaR (Journal of Risk 2(3), 2000, pp. 21-41; peer-reviewed; I read the authors' own preprint copy dated September 5, 1999). CVaR at level a is the average loss in the worst (1 - a) share of cases. Their Theorem 1: CVaR equals the minimum over t of F(t) = t + E[(loss - t)+] / (1 - a), and the smallest minimizer is VaR. For finite lotteries this is exact rational arithmetic.

- A "mean-CVaR" score, (1 - l) * E[X] + l * (average of the worst outcomes), is exact in `Rat`, monotone in the slider l by construction, and never rejects a gamble that dominates another. Mean-variance fails that last test (B01).
- But mean-CVaR is not expected utility, so it does not give the Pratt theorem. It gives only the weaker (and easy) "bigger slider accepts fewer gambles".
- Caveat: Theorem 1 here assumes the loss has a density. For discrete (finite) lotteries the same formula is the standard one, but I did not open the authors' 2002 follow-up that treats general distributions (**UNVERIFIED**).
- The UI story ("the bot looks at its worst 25% of outcomes") is very easy to explain to non-experts.

Verdict: maybe. Best backup if we want a tail-risk slider; quadratic utility (B01) is better because it supports the real Pratt-style theorem.

## Citation

R. Tyrrell Rockafellar and Stanislav Uryasev, "Optimization of conditional value-at-risk", *The Journal of Risk* 2(3), 2000, pp. 21-41. DOI 10.21314/JOR.2000.038. Peer-reviewed journal. Crossref "is-referenced-by-count": 5590 (looked up 2026-10-31).

## URLs fetched (fetched 2026-10-31)

- https://api.crossref.org/works/10.21314/JOR.2000.038 (metadata, citation count)
- https://doi.org/10.21314/JOR.2000.038 (redirects to risk.net; the risk.net page did not load for the fetch tool)
- https://sites.math.washington.edu/~rtr/papers/rtr179-CVaR1.pdf (authors' preprint, dated September 5, 1999; read as text in a temp folder outside the repo). The journal version may differ in details.

## Claim status

| Claim | Status |
|---|---|
| Theorem 1: F(x, t) = t + (1 - a)^(-1) E[(f(x, y) - t)+] is convex and continuously differentiable in t; CVaR = min over t of F; the set of minimizers is a non-empty closed bounded interval; VaR = its left endpoint | Proved on paper, under the paper's assumption that the loss has a density p(y) |
| Theorem 2: minimizing CVaR over decisions x equals minimizing F jointly over (x, t); F is jointly convex if the loss is convex in x | Proved on paper |
| With finitely many scenarios, F becomes convex and piecewise linear in t and reduces to linear programming | Proved on paper (stated as a consequence; eq. 9 in the preprint) |
| VaR is not subadditive or convex (citing Artzner et al.); CVaR is coherent (citing Pflug 2000) | Cited results, not proved here |
| Portfolio and hedging examples (CPLEX on a 300 MHz Pentium II) | Shown empirically |
| Machine-checked | No |

## Setting and definitions

- Think of a **loss** L (chips lost). Pick a level a, e.g. a = 0.95 or 0.75.
- **VaR_a** (value at risk): the smallest amount t such that the loss is at most t with probability at least a. In words: "the loss you exceed only (1 - a) of the time."
- **CVaR_a** (conditional value at risk, also "mean excess loss", "tail VaR", "mean shortfall"): the average loss in that worst (1 - a) tail. CVaR >= VaR always.
- **Key formula:** CVaR_a = min over t of [ t + E[max(L - t, 0)] / (1 - a) ].
- For a finite lottery, this minimum is reached at one of the outcome values, so CVaR is the minimum of finitely many rational numbers. Equivalent "sort" form: sort outcomes from worst to best, take probability mass (1 - a) from the worst end (splitting one atom if needed), and average.

## Main results with conditions

- Theorem 1 as in the table, assuming the loss distribution has a density (continuous). Common levels mentioned: a = 0.90, 0.95, 0.99.
- With scenarios y_1..y_q (equal weights 1/q in their sampling approximation), F~(x, t) = t + (1/(q(1 - a))) * sum_k (f(x, y_k) - t)+ is convex and piecewise linear in t.

## Assumptions and limitations

- Theorem 1's proof uses a density. For finite lotteries with atoms, the "left endpoint" and the tail split need care; the authors' later paper on general loss distributions handles this (not opened: **UNVERIFIED**).
- CVaR is a risk measure, not a utility. A CVaR-based bot does not maximize expected utility, so the Pratt framework (B01) does not apply.

## What is formally verified

Nothing here. I found no Lean formalization of CVaR (I did not search Mathlib specifically for it: **not checked**).

## Code artifacts and licenses

None in the paper. They used CPLEX and MATHEMATICA (commercial).

## Relevance to our project

A possible Risk slider design, exact in `Rat`:

  score_l(X) = (1 - l) * E[X] + l * TailMean_a(X),  l in [0, 1], a fixed (e.g. worst 25%).

- TailMean_a(X) <= E[X], so score_l = E[X] - l * (E[X] - TailMean_a(X)) falls as l rises: **a bigger slider accepts fewer gambles** (versus folding, which has score equal to the sure outcome). One-line proof.
- Both E[X] and TailMean_a are monotone under "never worse in any outcome", so the score respects dominance for l in [0, 1]. Mean-variance does not (free-roll example in B01).
- It does not support the Pratt "concave transform" theorem. If the pitch says "Arrow-Pratt", use quadratic utility (B01) instead.

## Candidate theorems for us

1. **Rockafellar-Uryasev formula for finite lotteries:** "the tail average equals the minimum over cut points t of t + expected excess / (1 - a)."
   ```lean
   theorem cvar_eq_min (L : Lottery) (hL : L.WellFormed) (a : ℚ) (ha : 0 ≤ a ∧ a < 1) :
       cvarSorted L a = (L.outcomes.map (fun t => t + L.expect (fun x => max (x - t) 0) / (1 - a))).minimum?.get! 
   ```
   (sign conventions: write it for losses). 6-10 h; the atom-splitting case is fiddly. Only worth it if CVaR is chosen.
2. **Slider monotonicity for mean-CVaR:** "raising the slider never makes the bot accept a gamble it rejected before." 1-2 h (needs only TailMean <= mean).
3. **Dominance:** "if gamble Y pays at least X in every outcome (same probabilities), score(Y) >= score(X)." 2-3 h.
