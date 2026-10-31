# Summary: B06: Rockafellar and Uryasev (2000), "Optimization of Conditional Value-at-Risk"


TL;DR: The standard paper on CVaR (Journal of Risk 2(3), 2000, pp. 21-41; peer-reviewed; I read the authors' own preprint copy dated September 5, 1999). CVaR at level a is the average loss in the worst (1 - a) share of cases. Their Theorem 1: CVaR equals the minimum over t of F(t) = t + E[(loss - t)+] / (1 - a), and the smallest minimizer is VaR. For finite lotteries this is exact rational arithmetic.

- A "mean-CVaR" score, (1 - l) * E[X] + l * (average of the worst outcomes), is exact in `Rat`, monotone in the slider l by construction, and never rejects a gamble that dominates another. Mean-variance fails that last test (B01).
- But mean-CVaR is not expected utility, so it does not give the Pratt theorem. It gives only the weaker (and easy) "bigger slider accepts fewer gambles".
- Caveat: Theorem 1 here assumes the loss has a density. For discrete (finite) lotteries the same formula is the standard one, but I did not open the authors' 2002 follow-up that treats general distributions (**UNVERIFIED**).
- The UI story ("the bot looks at its worst 25% of outcomes") is very easy to explain to non-experts.

Verdict: maybe. Best backup if we want a tail-risk slider; quadratic utility (B01) is better because it supports the real Pratt-style theorem.


Full extraction: [notes.md](notes.md).
