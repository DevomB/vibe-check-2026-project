# Summary: C04: Ramos and Soria, "From Rules to Nash Equilibria: A Lean 4 Case Study ... Trading Card Game" (2026)

**Source:** A. F. Ramos, T. Soria. "From Rules to Nash Equilibria: A Lean 4 Case Study in Game-Theoretic Analysis of a Competitive Trading Card Game." arXiv preprint, 2026. https://arxiv.org/abs/2607.08692

TL;DR: A 2026 preprint that checks, in Lean 4, Nash equilibrium claims about the Pokémon Trading Card Game's tournament "metagame" (which decks to bring). It is the closest prior work to ours: a card game plus game theory in Lean. It is not poker, and it does not verify a game engine.
- Their method matches ours: an untrusted solver (Python `linprog`) finds a candidate equilibrium, and Lean checks it by testing every pure-strategy deviation. We can do the same for Kuhn/Leduc: compute the strategy outside the proof, then prove "no deviation helps" in Lean.
- They use `native_decide` for the headline results (145 of 2,627 theorems). That trusts the compiler. Comparator / `lake check` may reject it, so we must decide early.
- They formalize only a "strategic layer" of the rules (deck legality, some card-flow facts), not a full rules engine. A verified poker engine (chip conservation, legal actions, side pots) is still open ground.
- No public repo or license yet ("anonymized supplementary material").

Verdict: use. Cite it as the nearest prior work, and copy its "untrusted solver, Lean checks the certificate" pattern.


Full extraction: [notes.md](notes.md).
