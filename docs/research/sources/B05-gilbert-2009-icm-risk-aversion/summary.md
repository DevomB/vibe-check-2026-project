# Summary: B05: Gilbert (2009), "The Independent Chip Model and Risk Aversion"


TL;DR: A short open math paper (arXiv preprint, math.PR, not peer-reviewed as far as I saw). Under ICM (B04), with prizes that do not increase by place and at least one player who will get less than 2nd prize, **any chip-fair bet against one opponent lowers your expected prize money**, and **every player not in the bet gains**. Both can fail for bets among three or more players; the paper gives a numeric counterexample.

- This is the rigorous reason risk aversion is *correct* in multi-player sit-and-gos with multi-place payouts.
- The proof is "split the payout into sub-tournaments, each term is linear or concave in your chip share, then Jensen". It fits Lean well, over exact `Rat`.
- In winner-takes-all, the money value is linear in chips, so there is no ICM risk aversion. Our heads-up MVP is this case.
- "Bystanders gain when two players gamble" is a fun, explainable fact for the GUI, and a possible theorem.

Verdict: use (for the 3-6 player story and as a stretch theorem). Ignore for the heads-up MVP.


Full extraction: [notes.md](notes.md).
