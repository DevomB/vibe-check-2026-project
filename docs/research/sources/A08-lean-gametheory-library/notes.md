# A08: Prior machine-checked game theory: the Lean 4 "GameTheory" library (and the gap for poker)

## Summary

**Source:** elazarg. "GameTheory" (Lean 4 library, Apache-2.0). https://github.com/elazarg/GameTheory

TL;DR: There is an Apache-2.0 Lean 4 library, elazarg/GameTheory, built on Mathlib. It formalizes finite game theory: Nash equilibria, mixed-Nash existence, minimax, and extensive-form encodings. It has no poker and no Kuhn poker. A web search found no machine-checked result about any poker game.

What matters for us:
- Novelty: machine-checked equilibrium, value or exploitability results for Kuhn, Leduc or any poker variant appear to be new. I searched the web, not every proof archive, so say "we found none".
- The library pins Lean v4.33.1 (per the Reservoir page) and follows Mathlib. Our project is meant to use Lean 4.35 (CLAUDE.md, for Comparator). Mixing toolchains is not possible, and Mathlib makes builds heavy. Recommendation: do not depend on it. Write our own small definitions over ℚ, using core Lean plus Batteries if possible.
- We do not need its minimax theorem: in a finite game, two finite checks (A01) prove the value directly.
- Coq and Isabelle work on Nash existence in finite extensive games exists (seen only in search results; UNVERIFIED, not counted).

Verdict: maybe. Cite it as related work in the README. Do not take it as a dependency.

## Citation

- elazarg. "GameTheory: Formalized game theory" (Lean 4 library). Code repository, Apache License 2.0.
- URLs fetched: https://reservoir.lean-lang.org/@elazarg/GameTheory and https://github.com/elazarg/GameTheory (both fetched 2026-10-31).
- Source type: code repository / package registry page.
- Citation count: not applicable.

## Claim status

| Claim | Status |
|---|---|
| Formalizes pure and mixed Nash, CE/CCE, Bayesian games; mixed-Nash existence; minimax; extensive-form encodings (EFG, FOSG, MAID, others); SPE and backward induction; behavioural-policy semantics; auctions; repeated and stochastic games; cooperative games | Machine-checked in Lean 4 (per the README; I did not build it or audit for `sorry`). The README mentions a "transitive axiom audit" and a "delivery ledger" listing partial or planned theorem families. |
| Toolchain leanprover/lean4:v4.33.1 | Stated on the Reservoir page. The GitHub README says only that the version is in `lean-toolchain` and that release tags match Lean versions. |
| Poker, Kuhn poker, Kuhn's theorem | Not mentioned on either page. |
| No machine-checked poker result exists anywhere | Opinion based on one web search (2026-10-31). Not proved. |

## Setting and definitions

Plain words: a Lean library where standard game-theory definitions and theorems are written and checked by Lean.

## Main results

As listed above. I did not read the source files.

## Assumptions and limitations

- Depends on Mathlib. Heavy build; needs `lake exe cache get`.
- Lean version (v4.33.1) differs from our planned Lean 4.35.
- Maturity: some theorem families are marked partial or planned by the authors.

## What is formally verified

The library's own theorems (per the README). Nothing about poker.

## Code artifacts

https://github.com/elazarg/GameTheory, Apache-2.0.

## Relevance to our project

- Related work for the README and pitch: "general game theory has been formalized in Lean; poker strategies and their exploitability have not, as far as we found".
- A design reference for how to state strategies and expected payoffs in Lean, if someone has time to look.
- A dependency risk if adopted: toolchain mismatch and Mathlib weight.

## Candidate theorems for us

None from this library directly. Our Kuhn theorems (A01) should be self-contained:
```lean
-- self-contained, core Lean + ℚ (Batteries or Mathlib's ℚ: decide early which)
theorem kuhn_value : evP1 (p1Eq (1/2)) p2Eq = -1/18
```
Note (unsure): ℚ is in core Lean (`Std`/`Lean` `Rat`) in recent versions, but lemma support such as `linarith` over ℚ comes with Mathlib. Check what the team's Lean 4.35 setup has before choosing between ℚ and scaled integers.
