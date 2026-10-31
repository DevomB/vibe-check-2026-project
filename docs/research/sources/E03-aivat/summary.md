# Summary: E03: AIVAT (Burch, Schmid, Moravčík, [Morrill,] Bowling)

**Source:** Burch, Schmid, Moravčík, Morrill, Bowling. "AIVAT: A New Variance Reduction Technique for Agent Evaluation in Imperfect Information Games." AAAI 2018. https://arxiv.org/abs/1612.06915. DOI 10.1609/aaai.v32i1.11481

TL;DR: AIVAT scores a played hand as "base value + one correction term per chance event and per known-strategy player action". Each correction is "expected value before the choice minus value after the observed choice", using ANY fixed value function. The proved theorem: every correction term has expected value 0, so the estimate is unbiased. Nothing else (variance) is proved.
- What must be known: the chance probabilities (public) and the strategy of the players whose actions get corrections. Our bot is known code, so its actions and the deal qualify; the human's actions do not.
- The value function can be arbitrary (any fixed heuristic). It only affects variance, not unbiasedness.
- The mean-zero fact is a finite weighted sum identity. We can prove it in Lean over rationals without measure theory.
- "Result = baseline + luck terms + skill terms" is a telescoping sum on one recorded hand. Exact, no probability needed.
- Results: about 10x fewer hands needed in no-limit hold'em (shown empirically, 1 million games, one-sided).

Verdict: use. It is the theory behind our luck-vs-skill graph and tells us exactly which terms have mean zero and why.


Full extraction: [notes.md](notes.md).
