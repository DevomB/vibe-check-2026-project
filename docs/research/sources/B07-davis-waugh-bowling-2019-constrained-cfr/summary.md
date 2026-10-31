# Summary: B07: Davis, Waugh and Bowling (2019), "Solving Large Extensive-Form Games with Strategy Constraints" (risk in imperfect-information games)

**Source:** Davis, Waugh, Bowling. "Solving Large Extensive-Form Games with Strategy Constraints." AAAI 2019. https://arxiv.org/abs/1809.07893


TL;DR: The closest game-solving paper I found on risk in imperfect-information games. It extends CFR (counterfactual regret minimization, the standard poker-solving algorithm) to **Constrained CFR**, which finds the best strategy subject to any convex constraints, such as "probability of a bad event at most b". It keeps CFR's O(1/sqrt(T)) convergence rate. Risk is handled as a **hard constraint**, not as a utility. Experiments: a security game with a risk bound, and opponent modeling in Leduc Hold'em.

- Machine-checked: no. Proofs on paper (appendix), experiments empirical. Peer-reviewed: AAAI 2019 (per arXiv comment).
- I found **no** paper on "risk-averse CFR" or a utility-based risk-averse poker bot in my arXiv searches (queries listed below). A related empirical paper (Haaf et al. 2021) fits a CRRA utility to Pluribus's play.
- For us: risk as "expected value minus r times a penalty" (B01) is simpler, exact in `Rat`, and gives a clean monotone theorem. Constrained CFR is a solver idea, too heavy for a rule-based bot.
- Its Leduc Hold'em use connects to our Kuhn/Leduc mini-mode (other group).

Verdict: ignore for implementation; cite as related work ("risk in poker solvers is usually a constraint, not a utility").


Full extraction: [notes.md](notes.md).
