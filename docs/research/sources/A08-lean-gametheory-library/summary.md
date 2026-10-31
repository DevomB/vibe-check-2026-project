# Summary: A08: Prior machine-checked game theory: the Lean 4 "GameTheory" library (and the gap for poker)

**Source:** elazarg. "GameTheory" (Lean 4 library, Apache-2.0). https://github.com/elazarg/GameTheory


TL;DR: There is an Apache-2.0 Lean 4 library, elazarg/GameTheory, built on Mathlib. It formalizes finite game theory: Nash equilibria, mixed-Nash existence, minimax, and extensive-form encodings. It has no poker and no Kuhn poker. A web search found no machine-checked result about any poker game.

What matters for us:
- Novelty: machine-checked equilibrium, value or exploitability results for Kuhn, Leduc or any poker variant appear to be new. I searched the web, not every proof archive, so say "we found none".
- The library pins Lean v4.33.1 (per the Reservoir page) and follows Mathlib. Our project is meant to use Lean 4.35 (CLAUDE.md, for Comparator). Mixing toolchains is not possible, and Mathlib makes builds heavy. Recommendation: do not depend on it. Write our own small definitions over ℚ, using core Lean plus Batteries if possible.
- We do not need its minimax theorem: in a finite game, two finite checks (A01) prove the value directly.
- Coq and Isabelle work on Nash existence in finite extensive games exists (seen only in search results; UNVERIFIED, not counted).

Verdict: maybe. Cite it as related work in the README. Do not take it as a dependency.


Full extraction: [notes.md](notes.md).
