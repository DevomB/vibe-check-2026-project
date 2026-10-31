# Summary: C03: Le Roux, Coq proofs of Kuhn's theorem for sequential games (2007), and the Coq + Isabelle follow-up (2017)

TL;DR: Le Roux generalized Kuhn's 1953 theorem ("backward induction gives a Nash equilibrium in every finite game tree") to abstract outcomes and preferences, and proved in Coq when it holds. A 2017 follow-up proved a related Nash existence theorem in both Coq and Isabelle.
- This is the classic prior art for "game theory in a proof assistant". It covers perfect-information game trees (both players see everything), not poker.
- Poker has hidden cards (imperfect information), so these results do not apply to Kuhn poker or Leduc directly.
- Backward induction on a finite tree is easy to state and prove in Lean. It is a good model for our "best response by walking the game tree" code.
- No code license found; we only link to the papers.

Verdict: maybe. Cite it as prior work. The math does not cover hidden-information games.


Full extraction: [notes.md](notes.md).
