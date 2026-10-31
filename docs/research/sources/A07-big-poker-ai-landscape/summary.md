# Summary: A07: Landscape of big poker AI systems (Cepheus, DeepStack, Libratus, Pluribus, ReBeL, Student of Games)

**Source:** Moravčík et al. "DeepStack: Expert-Level Artificial Intelligence in No-Limit Poker." https://arxiv.org/abs/1701.01724. Brown, Bakhtin, Lerer, Gong. ReBeL. https://arxiv.org/abs/2007.13544. Schmid et al. Student of Games. https://arxiv.org/abs/2112.03178. Brown, Sandholm. "Safe and Nested Subgame Solving." https://arxiv.org/abs/1705.02955. Bowling et al. "Heads-up limit hold'em poker is solved." Science 2015. https://doi.org/10.1126/science.1259433


TL;DR: Since 2015, research bots have solved heads-up limit hold'em (Cepheus) and beaten professionals at heads-up no-limit (DeepStack, Libratus) and later six-player no-limit (Pluribus). ReBeL and Student of Games add learning plus search with convergence proofs on paper. I read four abstracts; Science pages were blocked, so Cepheus has metadata only and Libratus and Pluribus are unverified.

What matters for us:
- These systems are huge (deep learning, big compute) and give guarantees only on paper or as empirical exploitability. None is machine-checked. Our pitch should not compete on strength. It competes on proofs about exact, small things.
- ReBeL's abstract claims it "provably converges to a Nash equilibrium in any two-player zero-sum game". This is a paper proof about an idealized algorithm, not about deployed code.
- Libratus used "safe and nested subgame solving" (Brown and Sandholm, arXiv:1705.02955). "Safe" there means re-solving part of the game without raising exploitability. This is a different idea from A05's safe exploitation.
- Useful demo framing: "real poker AIs claim low exploitability by experiment; our mini-mode proves exploitability 0 in Lean".

Verdict: maybe. Context for the pitch and README, not a source of theorems.


Full extraction: [notes.md](notes.md).
