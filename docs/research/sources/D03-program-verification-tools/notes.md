# D03: Program-verification tools: core `vcgen` (Std.WP / Std.Do), Velvet, iris-lean, Veil

## Summary

**Source:** Lean reference manual, "The vcgen tactic". https://lean-lang.org/doc/reference/4.35.0/The--vcgen--tactic/. Velvet: https://github.com/verse-lab/velvet. Veil: https://github.com/verse-lab/veil. iris-lean: https://github.com/leanprover-community/iris-lean

**TL;DR.** Core `vcgen`, Velvet, iris-lean and Veil are built for imperative or concurrent code. Our engine is pure functions, so ordinary Lean proofs are enough.

- `vcgen` (core v4.35) is experimental; at most try it on one loop as a stretch.
- Velvet is young. Veil pins v4.32.0, and it targets protocols, not game engines.
- iris-lean (separation logic) does not fit pure code.
- Writing the engine as pure functions over a state record is the design choice that keeps proofs cheap.

Verdict: maybe. `vcgen` is a stretch only; skip the rest.

## Citation / identity (all fetched 2026-10-31)
| Tool | URL(s) fetched | Type | Pinned Lean (lean-toolchain read today) | License | Stars |
|---|---|---|---|---|---|
| core `vcgen` | https://lean-lang.org/doc/reference/4.35.0/The--vcgen--tactic/ ; https://lean-lang.org/doc/reference/latest/releases/v4.35.0/ | official reference manual + release notes | part of v4.35.0 | Lean core | n/a |
| Velvet (verse-lab/velvet) | https://github.com/verse-lab/velvet ; lean-toolchain via GitHub API (commit 836ed5a1) | code repo | **leanprover/lean4:v4.35.0** | Apache-2.0 | 134 |
| iris-lean (leanprover-community/iris-lean) | https://github.com/leanprover-community/iris-lean ; Iris/lean-toolchain via GitHub API (commit fb21a8af); tag list | code repo | **leanprover/lean4:v4.35.0** (Iris subproject); tag `v4.35.0` exists | Apache-2.0 | 244 |
| Veil (verse-lab/veil) | https://github.com/verse-lab/veil ; lean-toolchain via GitHub API (commit 0a9f0730) | code repo | **leanprover/lean4:v4.32.0** | Apache-2.0 | 347 |

## Core `vcgen` (documented behavior)
- What: a verification-condition generator. You state a Hoare triple ("if P holds before running `prog`, then Q holds after") about a monadic `do` program. `vcgen` breaks it into plain logic goals ("verification conditions").
- New in v4.35.0; replaces `mvcgen`, which is deprecated (#14874). Breaking change: replace `mvcgen` / `mvcgen?` with `vcgen`.
- **Experimental**: the manual says "`vcgen` is experimental and subject to change". `set_option experimental.vcgen true` silences the warning.
- Setup (manual): import `Std.WP` and `Std.Tactic.Do`; open namespaces `Std.WP` and `Lean.Order` (the `Lean.Order` need is said to be temporary).
- Every function the program calls needs a spec registered with `@[spec]` (a Hoare triple or an equation). Example from the manual:
```lean
@[spec] theorem mkFreshNat_spec :
    ⦃fun s => ⌜s.1 = n⌝⦄ mkFreshNat ⦃fun r s => ⌜r = n ∧ s.1 = n + 1⌝⦄
```
- Loop invariants: `vcgen [...] invariants · I1 · I2 with try finish`, or labelled `invariants | inv1 _ acc _ => I1 acc | _ => I2`.
- The `with` clause runs one step of `grind` mode (such as `finish`) on all generated goals, sharing the E-graph `vcgen` built, or an ordinary tactic.
- Release notes: one benchmark (AddSubCancel) 0.32 s with `vcgen` vs 66 s with `mvcgen`; kernel check 0.53 s vs 246 s (shown empirically by the Lean team, self-reported).
- v4.35.0 also: the `⦃ P ⦄ c ⦃ v, Q ⦄` triple form was removed (#14872); `do`-block clauses `invariant`, `decreasing`, `assert` no longer need `open Std.WP` (#14860). `WPSound` moved to `Std.WP` as `LawfulWPMonadAttach` (#14801).
- Note the manual example uses `⦃P⦄ prog ⦃Q⦄` with `fun r s => ...`; I did not see the `⇓ r => Q` syntax on that page (unsure whether it still exists).

## Velvet (documented behavior from README)
- "Dafny-style verifier for imperative programs embedded in the Lean proof assistant". Programs can be compiled, run, property-tested and proved in one place.
- Shallow embedding in monads `Id`, `Option`, `StateT`, `ExceptT` and stacks of them. Ghost state (erased from compiled code). Angelic/demonic nondeterminism. Partial and total correctness proved separately then combined.
- `#derive_tester_for` builds an executable checker for a method's contract, run on concrete or random inputs ("testing before proving").
- A proved method yields `<name>.spec`, an ordinary Lean theorem. This matters: the result is a plain theorem Comparator can check.
- Tactic named in the README: `velvet_vcgen`. How goals are discharged beyond "SMT-inspired proof automation": not described on the README (the language reference is in `docs/doc.md`, not read today).
- Install: elan, then `git clone https://github.com/verse-lab/velvet.git`, `cd velvet`, `lake build`; `lake build Examples` for examples. The root package does **not** depend on Mathlib ("a few minutes" to build); `CaseStudies/` does.
- Maturity: 80 commits on `main`, 11 open issues, created 2026-02-13, updated 2026-10-30. No release tags or stability statement seen. Website velvetprover.dev (not opened).

## iris-lean (documented behavior from README)
- Lean 4 port of Iris, "a higher-order concurrent separation logic framework". Two subprojects: `Iris` (core) and `IrisMath` (needs Mathlib).
- Has the MoSeL proof interface, the `IProp` model, the HeapLang example language, invariants, later credits.
- Kept in sync with Lean releases; tags `v4.35.0`, `v4.34.1`, ... exist. Require via `lakefile.toml` with `git.subDir = "Iris"`.
- Fit for us: poor. Separation logic is for heap-manipulating and concurrent programs. Our engine is pure functions over immutable data, so we do not need it.

## Veil (documented behavior from README)
- Framework for specifying, testing and proving safety properties of state transition systems (focus: distributed protocols). Commands seen: `#check_invariants`, `#model_check`, `sat`/`unsat trace`. Push-button checks for decidable first-order fragments, Lean proofs when automation fails.
- README calls the current state a **pre-release of Veil 2.0** that "still has bugs and rough edges".
- Install needs clang/lld/libc++ on Linux or Xcode tools on macOS, plus **Node.js 24**; a `lean-cvc5` dependency appears in troubleshooting. Windows: not mentioned.
- The `veil.smt.trust` option from CLAUDE.md: not mentioned on the README page (unsure).
- **Pinned to v4.32.0**, so it cannot share a project with our v4.35.0 toolchain.

## Fit for a poker engine written as pure Lean functions + small IO shell
- Our core (deal, betting, pots, showdown, bot policy) can be plain total functions `State → Action → Except Error State`. For pure functions, ordinary Lean proofs (induction, `simp`, `omega`, `grind`, `decide`) are the natural tool. No Hoare logic needed.
- `vcgen` / Velvet help only if we write imperative-style code: `for` loops with `let mut` in `Id` or `StateM` (for example a fast hand evaluator or the equity enumeration loop). Then `vcgen` turns loop invariants into goals. That is a good, cool "we verified the fast loop" story, but it is experimental.
- Velvet is on v4.35.0, so it is usable, but it adds a young dependency and its own syntax. Core `vcgen` needs no extra dependency.
- Veil: wrong version (v4.32.0), Node.js requirement, pre-release. Ignore.
- iris-lean: wrong problem. Ignore.

## Recommendations
1. Write the engine as pure functions; prove properties directly. This is the main path.
2. If we write the equity loop or hand evaluator as an imperative `Id.run do ... for ... let mut`, consider one `vcgen` proof (for example "the loop's win/tie/loss counts add up to the number of runouts"). Budget it as a stretch goal; experimental features may change.
3. Do not add Velvet unless the Lean-strong teammate wants Dafny-style contracts and has tried it on a toy method in hour 1. Its `#derive_tester_for` is attractive for contract testing.
4. Do not use Veil or iris-lean.

## Candidate theorems
- (vcgen, stretch) For the imperative equity loop `countOutcomes`: `wins + ties + losses = runouts.length`. Lean shape:
  `theorem countOutcomes_total (h : Hand) (v : Hand) (b : Board) : let r := countOutcomes h v b; r.wins + r.ties + r.losses = (runouts h v b).length`. Prove either with `vcgen` + invariant `acc.wins + acc.ties + acc.losses = i`, or by rewriting the loop as a `foldl` and inducting. 3 to 6 h.
- (pure) Same statement proved for a `List.foldl` version: 2 to 3 h. Recommended over the vcgen version.
