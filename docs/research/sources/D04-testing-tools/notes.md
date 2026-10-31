# D04: Testing tools: plausible, Specimen, LSpec

## Citation / identity (all fetched 2026-10-31)
| Tool | URL(s) fetched | Type | Pinned Lean seen | License | Stars |
|---|---|---|---|---|---|
| plausible (leanprover-community/plausible) | https://github.com/leanprover-community/plausible ; lean-toolchain and tags via GitHub API | code repo | `main` (commit 129d1ba9) = **v4.36.0-rc2**; tag **`v4.35.0`** exists (dfa4f381) | Apache-2.0 | 118 |
| Specimen (strata-org/specimen) | https://reservoir.lean-lang.org/@strata-org/specimen ; lean-toolchain via GitHub API (commit d688e1e5); README text via web search snippet of https://raw.githubusercontent.com/strata-org/specimen/main/Specimen/README.md (that raw file itself NOT opened: UNVERIFIED) | Reservoir package page + code repo | **leanprover/lean4:v4.34.0** | Apache 2.0 | 13 |
| LSpec (argumentcomputer/LSpec) | https://github.com/argumentcomputer/LSpec ; lean-toolchain via GitHub API (commit d8eb3e0d) | code repo | **leanprover/lean4:v4.34.1** | MIT | 86 |

Note: https://github.com/leanprover/plausible returned 404; the live repo is under leanprover-community.

## plausible (documented behavior)
- "A property testing framework for Lean 4 that integrates into the tactic framework." It tries random inputs to find a counterexample to a statement.
- Uses seen in README:
```lean
import Plausible
example (xs ys : Array Nat) : xs.size = ys.size → xs = ys := by
  plausible
-- reports a counterexample: xs := #[0], ys := #[1]
#eval Plausible.Testable.check <| ∀ (xs ys : Array Nat), xs.size = ys.size → xs = ys
```
- Custom types need `Repr` plus `Plausible.Shrinkable` and `Plausible.SampleableExt` (or `Plausible.Arbitrary`). You can write `deriving Arbitrary` on an inductive, or `deriving instance Arbitrary for T1, ..., Tn`.
- The `plausible` tactic never proves anything; if it finds no counterexample it leaves the goal failing (it is a test, not a proof). Exact behavior on "no counterexample found": not re-checked today (unsure).
- Maturity: 151 commits; the community's standard property tester (successor of Mathlib's SlimCheck; background knowledge, not checked today).

## Specimen (documented behavior, Reservoir page + search snippet of README)
- Derives generators, enumerators and checkers for **inductive relations**, to complement plausible. Commands named in the README (via search snippet): `derive_generator`, `derive_enumerator`, `derive_checker`, `derive_mutual`. Instances: `ArbitrarySizedSuchThat`, `EnumSizedSuchThat`, `DecOpt`. Options: `specimen.autoDeriveDeps`, `specimen.fuel`, `specimen.scoreType`.
- Inspired by Coq/Rocq QuickChick and papers "Generating Good Generators for Inductive Relations" (POPL 2018, peer-reviewed), "Computing Correctly with Inductive Relations" (PLDI 2022, peer-reviewed), "Testing Theorems, Fully Automatically" (OOPSLA 2026; status as given in README snippet, not checked).
- Version 0.1.0; 3 dependencies (names not shown); last updated 2026-10-29.
- **Pinned to v4.34.0**: not a matching tag for v4.35.0. Might build on v4.35.0 but untested; v4.35.0 has breaking changes (for example `Decidable` is now a structure, #8309), which could break derive code. Risky.

## LSpec (documented behavior)
- Hspec-style unit-test framework. `TestSeq`, `test "desc" prop next`, `group`, `Testable` class. `#lspec` runs tests inside a file and fails the build on failure. `lspecIO` in a compiled `main`, marked `@[test_driver]` in the lakefile, for runtime tests.
- Property tests via SlimCheck (`check`, `checkIO`) and plausible (`checkPlausible'`, `checkPlausibleIO'`; plausible tests are skipped by `#lspec`).
- No releases; pinned to v4.34.1. 92 commits.

## Fit for a poker engine
- plausible: great fit. Before proving "chips are conserved" or "side pots pay out exactly the pot", run `plausible` on the statement over random action sequences. Write our own generator of **legal** action sequences (random inputs rarely meet "legal state" preconditions; CLAUDE.md says the same).
- LSpec: not needed. Core `#guard` and `example ... := by decide` do the same job for unit tests with zero dependencies, and `lake test` with a plain `main` is enough for runtime tests.
- Specimen: version mismatch (v4.34.0) and very new (13 stars). Our preconditions ("this action is legal in this state") are easier to meet with a hand-written generator: pick a random action from `legalActions s`.

## Recommendations
1. Add plausible at `rev = "v4.35.0"` in a separate test library so the engine itself has no test dependency.
2. Write `genGame : Gen (List Action)` that plays random legal actions from the start state. Reuse it for all property tests (chip conservation, pot settlement, "bot only picks legal actions").
3. Use core `#guard` for concrete hand-ranking unit tests (e.g. royal flush beats four of a kind).
4. Skip LSpec and Specimen.

## Candidate checks
- Property test: after any random legal action sequence, sum of stacks + pot = 1000 (heads-up). 1 to 2 h including generator.
- Property test: `bestHand` of 7 cards is the max over all 21 five-card subsets (compare fast evaluator vs reference). 1 to 2 h.
- Differential test: our evaluator vs a known table of hand-class counts over all C(52,5) five-card hands (take the per-class counts from a cited source; not checked today). 1 h.
