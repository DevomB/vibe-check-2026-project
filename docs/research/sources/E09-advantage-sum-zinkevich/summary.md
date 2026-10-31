# Summary: E09: Optimal Unbiased Estimators for Evaluating Agent Performance (Zinkevich, Bowling, Bard, Kan, Billings; AAAI 2006): the "advantage sum"

**Source:** Zinkevich, Bowling, Bard, Kan, Billings. "Optimal Unbiased Estimators for Evaluating Agent Performance." AAAI 2006. https://cdn.aaai.org/AAAI/2006/AAAI06-092.pdf

TL;DR: This is the clean theory under DIVAT, MIVAT and AIVAT. Take ANY value function V. At every event whose probabilities are known (cards, and any agent whose strategy is known), add "expected value of the next step (one-step lookahead Q) minus the value after the step that happened". The result (the "advantage sum") is unbiased for every possible behaviour of the unknown agents (Theorem 1). With V = true conditional expectation it is the minimum-variance unbiased estimator (Theorem 3).
- Exact formula: `u^(h) = u(h) + sum over known steps t of ( Q(h(t)) - V(h(t+1)) )`, with `Q(h) = sum_e V(h·e) k(e|h)`.
- Theorem 1 proof is three lines of finite-sum algebra (uses only `sum_e k(e|h) = 1`). Very Lean-friendly.
- This is our luck/skill split: luck term at a known step = `V(after) - Q(before)`; skill steps are the human's steps. Then "actual result = V(start) + luck + skill" is a telescoping identity, provided V equals Q at known nodes.
- The unknown agent (our human) can do anything; unbiasedness still holds.
- Empirical: limit hold'em, 7.2x and 5.7x fewer hands needed than money counting.

Verdict: use. Best single source for the exact identity we want to prove; simpler notation than AIVAT.


Full extraction: [notes.md](notes.md).
