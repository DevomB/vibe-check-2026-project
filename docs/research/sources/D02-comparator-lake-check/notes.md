# D02: Comparator, `lake check`, `lake comparator`

## Citation / identity
- Project: Comparator, "a trustworthy judge for Lean proofs" (leanprover/comparator), now merged into Lake in core Lean v4.35.0.
- Sources (all fetched 2026-10-31):
  - https://github.com/leanprover/comparator (repo page + README; official code repo)
  - https://github.com/leanprover/comparator/blob/master/README.md (README; official)
  - https://lean-lang.org/doc/reference/latest/releases/v4.35.0/ (official release notes)
  - https://github.com/leanprover/lean4/pull/14990 (PR: `lake check`; official repo)
  - https://github.com/leanprover/lean4/pull/15005 (PR: bubblewrap sandbox; official repo)
  - https://github.com/leanprover/lean4/pull/15156 (PR: flag to disable the sandbox; merged 2026-09-14)
  - https://github.com/leanprover/lean4/pull/15147 (PR: `comparator.json` default location; merged 2026-09-13)
- Source type: official code repos, PR descriptions, release notes.
- Standalone repo state: **archived, read-only**. README says it "has been merged into core as of Lean release v4.35.0". 247 stars, 41 forks, 130 commits on `master`, license Apache-2.0. Its own lean-toolchain contents: not seen.
- The README tells users to migrate to `lake comparator` / `lake check`, since they are "the only ones guaranteed to receive further security and performance improvements".

## What each one checks (documented behavior)
### `lake comparator` (renamed from `lake challenge`; #14885, #15146)
- Two modules: a trusted **Challenge** (theorem statements, proofs may be `sorry`) and a **Solution** (the same statements, with proofs).
- For each name in `theorem_names` it checks: (1) the Solution states the same thing as the Challenge (it compares every declaration the statement mentions, transitively, including special `Init` ones; both files must use the default prelude); (2) the proof uses only axioms in `permitted_axioms`; (3) the Lean kernel accepts the Solution environment (replay).
- Config: JSON. Default file name `comparator.json` (#15147). Example fields seen in the README and release notes:
```json
{
    "challenge_module": "Challenge",
    "solution_module": "Solution",
    "theorem_names": ["todo1"],
    "permitted_axioms": ["propext", "Quot.sound", "Classical.choice"]
}
```
- Optional fields seen in the old README: `definition_names` ("definition holes": `def`s left as `sorry` in the Challenge), and `external_kernels`. The README warns that definition-hole solutions "must always be checked with an additional (potentially human) verifier", because the tool only checks name, type, universe levels, safety level and axioms of the filled-in def, not that it is the right def.
- Flags in v4.35.0 notes: `--solution-from-export`, `--challenge-from-export`, `--paranoid`.

### `lake check` (#14990)
- No challenge file. Builds the project's default targets, exports them, replays the export through the kernel, and fails if any constant uses an axiom other than the standard three.
- **Allowed axioms are fixed: `propext`, `Classical.choice`, `Quot.sound`.** The PR describes no flag or lakefile option to add more.
- `sorryAx` is not rejected by the kernel; the axiom report is what catches `sorry`.
- The project **must contain a `lake-manifest.json`** (the sandbox cannot write one).
- Cost: PR says about a minute for a project with one theorem, roughly the same regardless of size.
- Flags in v4.35.0 notes: `--paranoid`, `--from-export`. `lake help check` prints help.

### `--paranoid`
- Requires all bundled independent checkers to accept: `leanchecker-paranoid` (hardened allocator, #14884), `lean4lean` (#15048), `nanoda` (#15099), `con-leche` (#15130), `con-ron` (#15153). These ship with release toolchains, no extra install (release notes "Other" section).

## Sandbox and platforms (documented behavior + our inference)
- v4.35.0 notes: projects are treated as untrusted. Build and export run in a **bubblewrap (`bwrap`) sandbox** (#15005) that hides home directories and limits network. The kernel runs in a separate, privilege-separated process (#15055). **The sandbox is Linux-only.**
- PR #15005: root filesystem read-only, only `.lake` writable; only dependency resolution (`lake resolve-deps`) gets network. Needs `bwrap` via unprivileged user namespaces or a setuid-root install. Some CI runners deny `pivot_root`, which stops bwrap.
- CLAUDE.md also says both commands are "Linux only".
- Expert flag to turn the sandbox off: `--inadvisably-no-sandbox` (#15156). The PR says it "should not be used in usual production environments". Which exact subcommand(s) accept it: unsure (PR page did not show).
- Windows / macOS behavior: **not stated** in any page I read. Inference: on Windows, `lake check` / `lake comparator` will either refuse or need `--inadvisably-no-sandbox`. Unsure.

### What this means for a Windows team
- Develop and `lake build` on Windows as normal.
- Run `lake check` and `lake comparator` inside **WSL2 (Ubuntu)** with elan installed there, on a clone of the repo inside the WSL filesystem (not `/mnt/c`, for speed; opinion). Install `bubblewrap` there (`sudo apt install bubblewrap`; package name is our assumption, unsure).
- Judges will most likely run on Linux: clone, `make install`, then `lake check` and/or `lake comparator` with our `comparator.json`. Opinion, not stated by organizers in anything I read.

## Axioms and `native_decide` (key facts)
- Since v4.29.0, each `native_decide` call adds its own axiom with an auto-generated name containing `._native.` (release notes v4.29.0, #12217). `Lean.ofReduceBool` and `Lean.trustCompiler` were removed in v4.35.0 (#14953).
- **`lake check` accepts only `propext`, `Classical.choice`, `Quot.sound`.** Inference (high confidence): any theorem in a default target that uses `native_decide` makes `lake check` fail.
- `lake comparator`: `permitted_axioms` is a list of names. Whether it accepts globs (to allow `*._native.native_decide.*`) is **unsure**: not documented in anything I read. A third-party tool (Axle) supports such globs, but that is not Comparator.
- Recommendation: **do not use `native_decide` in any shipped proof.** Use `decide`, `decide +kernel`, or real proofs.

## Fit for our poker engine
- Excellent fit as the "final check". Our main theorems should live in a small trusted `Challenge.lean` (statements only, with `sorry`), and the proofs in `Solution.lean` (or the real modules). Comparator then shows the judge that the statements were not weakened.
- Important design rule: the Challenge statement mentions our real engine functions (for example `applyAction`, `settlePots`). Comparator compares those definitions transitively, so the Challenge must import or contain the **same** engine code. Simplest layout: `Challenge.lean` imports the engine modules and states theorems about them with `sorry`; `Solution.lean` imports the same modules and proves them. (Our proposal; check against how `lake comparator` resolves modules.)
- Keep all proof modules in the default `lake build` targets so `lake check` covers them.

## Recommendations
1. Put a `comparator.json` at the repo root listing our main theorems, `permitted_axioms` = the standard three.
2. Add `make check` that runs `lake build && lake check && lake comparator` (Linux/WSL only), and document in README that it needs Linux + bwrap.
3. Ban `native_decide`, `sorry`, new `axiom`s in proof modules; run `#print axioms` on every main theorem in CI.
4. Commit `lake-manifest.json` (required by `lake check`).
5. Early (hour 1 to 2): one teammate sets up WSL2 + elan + bwrap and runs `lake check` on a toy theorem. This flushes out sandbox surprises before the deadline.

## Candidate checks
- Toy Challenge/Solution pair run through `lake comparator` in WSL: 1 to 2 h including setup.
- `make check` target wiring: 0.5 h.
