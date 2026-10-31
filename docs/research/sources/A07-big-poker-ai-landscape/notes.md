# A07: Landscape of big poker AI systems (Cepheus, DeepStack, Libratus, Pluribus, ReBeL, Student of Games)

## Summary (also in summary.md)

TL;DR: Since 2015, research bots have solved heads-up limit hold'em (Cepheus) and beaten professionals at heads-up no-limit (DeepStack, Libratus) and later six-player no-limit (Pluribus). ReBeL and Student of Games add learning plus search with convergence proofs on paper. I read four abstracts; Science pages were blocked, so Cepheus has metadata only and Libratus and Pluribus are unverified.

What matters for us:
- These systems are huge (deep learning, big compute) and give guarantees only on paper or as empirical exploitability. None is machine-checked. Our pitch should not compete on strength. It competes on proofs about exact, small things.
- ReBeL's abstract claims it "provably converges to a Nash equilibrium in any two-player zero-sum game". This is a paper proof about an idealized algorithm, not about deployed code.
- Libratus used "safe and nested subgame solving" (Brown and Sandholm, arXiv:1705.02955). "Safe" there means re-solving part of the game without raising exploitability. This is a different idea from A05's safe exploitation.
- Useful demo framing: "real poker AIs claim low exploitability by experiment; our mini-mode proves exploitability 0 in Lean".

Verdict: maybe. Context for the pitch and README, not a source of theorems.

## Citations (only what I opened)

1. Matej Moravcik, Martin Schmid, Neil Burch, Viliam Lisy, Dustin Morrill, Nolan Bard, Trevor Davis, Kevin Waugh, Michael Johanson, Michael Bowling. "DeepStack: Expert-Level Artificial Intelligence in No-Limit Poker." arXiv:1701.01724 (v1 6 Jan 2017; v3 3 Mar 2017). Related DOI 10.1126/science.aam6960 (Science, 2017). Source read: arXiv abstract page only.
   - URL fetched: https://arxiv.org/abs/1701.01724 (fetched 2026-10-31).
2. Noam Brown, Anton Bakhtin, Adam Lerer, Qucheng Gong. "Combining Deep Reinforcement Learning and Search for Imperfect-Information Games" (ReBeL). arXiv:2007.13544 (v1 27 Jul 2020; v2 29 Nov 2020). The arXiv page shows no venue (I believe NeurIPS 2020; unverified). Abstract only.
   - URL fetched: https://arxiv.org/abs/2007.13544 (fetched 2026-10-31).
3. Martin Schmid, Matej Moravcik, Neil Burch, Rudolf Kadlec, Josh Davidson, Kevin Waugh, Nolan Bard, Finbarr Timbers, Marc Lanctot, G. Zacharias Holland, Elnaz Davoodi, Alden Christianson, Michael Bowling. "Student of Games: A unified learning algorithm for both perfect and imperfect information games." Science Advances 9, eadg3256 (2023), DOI 10.1126/sciadv.adg3256. arXiv:2112.03178. Peer-reviewed. Abstract only.
   - URL fetched: https://arxiv.org/abs/2112.03178 (fetched 2026-10-31).
4. Noam Brown, Tuomas Sandholm. "Safe and Nested Subgame Solving for Imperfect-Information Games." arXiv:1705.02955 (v1 8 May 2017; v3 16 Nov 2017). The arXiv page shows no venue. Abstract only.
   - URL fetched: https://arxiv.org/abs/1705.02955 (fetched 2026-10-31).
5. Michael Bowling, Neil Burch, Michael Johanson, Oskari Tammelin. "Heads-up limit hold'em poker is solved." Science, 2015. DOI 10.1126/science.1259433. Citation count 576 (Semantic Scholar, 2026-10-31). A CACM 2017 version exists (DBLP key journals/cacm/BowlingBJT17).
   - URL fetched: https://api.semanticscholar.org/graph/v1/paper/DOI:10.1126/science.1259433?fields=title,year,venue,authors,abstract,citationCount,externalIds (fetched 2026-10-31). METADATA ONLY: the abstract was not provided, and https://www.science.org/doi/10.1126/science.1259433 returned HTTP 403. Content claims (for example the exploitability bound) are UNVERIFIED and not stated here.

Not opened (UNVERIFIED, not counted): Libratus (Brown and Sandholm, Science 2018); Pluribus (Brown and Sandholm, Science 2019); MCCFR (Lanctot et al. 2009).

## Claim status

| Claim | Source | Status |
|---|---|---|
| DeepStack beat professional players over 44,000 hands of heads-up no-limit, with statistical significance | DeepStack abstract | Shown empirically. |
| DeepStack is "theoretically sound" and its strategies are harder to exploit than prior approaches | DeepStack abstract | Comparative claim; I did not see the proof or numbers. |
| ReBeL provably converges to a Nash equilibrium in any two-player zero-sum game | ReBeL abstract | Proved on paper (claimed in abstract; proof not read). |
| ReBeL is superhuman at heads-up no-limit with far less domain knowledge | ReBeL abstract | Shown empirically. |
| Student of Games is sound: converges toward perfect play as computation and approximation capacity grow | SoG abstract | Proved on paper (claimed; proof not read). |
| SoG: strong in chess and Go, beats the strongest openly available heads-up no-limit agent, beats the state of the art in Scotland Yard | SoG abstract | Shown empirically. |
| Safe subgame solving beats prior methods; repeated (nested) solving greatly lowers exploitability; key part of Libratus | Subgame solving abstract | Theory claims on paper plus empirical results. |
| Heads-up limit hold'em is solved | Cepheus | Title only seen; content UNVERIFIED. |
| Anything machine-checked | all | Nothing. |

## Setting and definitions

- Heads-up = two players. Limit = fixed bet sizes. No-limit = any bet size up to your stack.
- Subgame solving: when play reaches a part of the game, compute a better strategy for just that part during play. "Safe" subgame solving means the new part does not make the whole strategy more exploitable.
- Self-play learning with search: learn a value estimate from games against itself, then look ahead using it.

## Main results and algorithms

Only the abstract-level facts above. I did not read the methods.

## Assumptions and limitations

- Guarantees cover two-player zero-sum games. Pluribus (six players) has no equilibrium guarantee of this kind (general knowledge; not verified here).
- Neural networks and approximations: guarantees are "in the limit" of capacity and compute.

## What is formally verified

Nothing in any of these.

## Code artifacts

Not checked. License unknown.

## Relevance to our project

- Pitch and README context: name what the big systems do and what they do not prove.
- Our 3-6 player mode: the multi-player result (Pluribus) is empirical. Do not promise "unexploitable" there.
- Our game review: commercial "solvers" give estimated EVs. Our review is exact on river and all-in spots against a known bot. This contrast is fair to state.

## Candidate theorems for us

None directly. The useful theorems are in A01, A03, A05, A06.
