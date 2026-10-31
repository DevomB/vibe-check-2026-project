# C03: Le Roux, Coq proofs of Kuhn's theorem for sequential games (2007), and the Coq + Isabelle follow-up (2017)

## Summary (also in summary.md)
TL;DR: Le Roux generalized Kuhn's 1953 theorem ("backward induction gives a Nash equilibrium in every finite game tree") to abstract outcomes and preferences, and proved in Coq when it holds. A 2017 follow-up proved a related Nash existence theorem in both Coq and Isabelle.
- This is the classic prior art for "game theory in a proof assistant". It covers perfect-information game trees (both players see everything), not poker.
- Poker has hidden cards (imperfect information), so these results do not apply to Kuhn poker or Leduc directly.
- Backward induction on a finite tree is easy to state and prove in Lean. It is a good model for our "best response by walking the game tree" code.
- No code license found; we only link to the papers.

Verdict: maybe. Cite it as prior work. The math does not cover hidden-information games.

## Citation
1. Stéphane Le Roux (LIP, ENS Lyon). "Acyclicity of Preferences, Nash Equilibria, and Subgame Perfect Equilibria: a Formal and Constructive Equivalence". arXiv:0705.3316, v1 23 May 2007. Categories cs.DM (primary), cs.GT, cs.LO. The arXiv page shows no journal reference. A search result says a version appeared as a 2009 Springer chapter ("Acyclic preferences and existence of sequential Nash equilibria..."); I did not open it, so the peer-reviewed venue is unsure. Treat as preprint / tech report (search results also list LIP research report RR-2007-18, not opened).
2. Stéphane Le Roux (Université Libre de Bruxelles), Érik Martin-Dorel and Jan-Georg Smaus (IRIT, Université de Toulouse). "An Existence Theorem of Nash Equilibrium in Coq and Isabelle". In Proceedings GandALF 2017, EPTCS 256, 2017, pp. 46–60. DOI 10.4204/EPTCS.256.4. arXiv:1709.02096. Peer-reviewed workshop proceedings.
- Source type: academic papers.
- URLs fetched 2026-10-31: https://arxiv.org/abs/0705.3316 ; https://arxiv.org/abs/1709.02096
- Citation counts: not looked up (Semantic Scholar rate-limited).

## Claim status
| Claim | Status |
|---|---|
| (2007) For abstract outcomes and preferences, three statements are equivalent: preferences are acyclic; every sequential game has a Nash equilibrium; every sequential game has a subgame perfect equilibrium | Machine-checked in Coq ("fully computer-certified", per the abstract; Coq version not stated on the page) |
| (2007) Backward induction and subgame perfect equilibrium coincide for total orders but not in general | Stated in the paper (a search summary); I did not read the full text, so the formal status of this side remark is unsure |
| (2017) If every derived win/lose game has a winning strategy for one player, a game with finitely many outcomes has a Nash equilibrium | Machine-checked in Coq and in Isabelle |
| (2017) The proof also gives "secure equilibria", and computes them for priority games in quasi-polynomial time | Stated in the abstract; whether the complexity claim is formalized is unsure |
| Earlier Coq work (Vestergaard 2006, binary trees with real payoffs) | Mentioned in search results only; UNVERIFIED, not opened |

## Setting and definitions
Plain words:
- A sequential game is a game tree. At each node one player picks a branch. Leaves are outcomes.
- A strategy says what a player picks at each of their nodes.
- A Nash equilibrium is a choice of strategies where no player can do better by changing only their own strategy.
- Subgame perfect: the strategies are also a Nash equilibrium in every subtree, not only from the root.
- Backward induction: solve the tree from the leaves up; at each node the mover picks the child that is best for them.
- Kuhn (1953): with real-number payoffs, backward induction always gives a Nash equilibrium.
- Le Roux replaces numbers with abstract outcomes and an arbitrary "prefers" relation. "Acyclic" means no chain of strict preferences loops back to its start.

Precise: as stated in the abstract of 0705.3316: (1) acyclic preferences ⇔ (2) every sequential game has a Nash equilibrium ⇔ (3) every sequential game has a subgame perfect equilibrium.

## Assumptions and limitations
- Perfect information only: every player sees the whole history. Poker has hidden cards, so poker equilibria need imperfect-information games and mixed (random) strategies. These results do not cover that.
- Pure strategies, finite trees.
- The pages do not give Coq version, file sizes or a code link.

## What is formally verified
- 2007: the three-way equivalence, in Coq (version unknown).
- 2017: the existence theorem, in Coq and Isabelle.

## Code artifacts and licenses
- None found from the abstract pages. No license known.

## Relevance to our project
- Prior art for game theory in proof assistants. It shows that a backward-induction equilibrium proof on finite trees is a well-trodden, feasible task.
- For our Kuhn/Leduc mode: computing a best response against a fixed opponent strategy is backward induction over the tree, except that the responder must pick one action per information set (what they can see), not per node. That twist is not in these papers.
- Novelty for us: these papers do not touch poker, hidden information, or exploitability.

## Candidate theorems for us
| Plain English | Lean 4 shape (sketch) | Hours |
|---|---|---|
| Our best-response routine returns the highest value the responder can get against a fixed strategy, on any finite game tree with full information | `theorem bestResponse_optimal (t : Tree) (σ : Strategy) (τ : Strategy) : value t σ τ ≤ value t σ (bestResponse t σ)` | 4–8 |
| Backward induction gives a profile where no single player gains by switching (perfect-information trees, payoffs in ℚ) | `theorem backwardInduction_isNash (t : Tree) : IsNash t (backwardInduction t)` | 6–12 |
