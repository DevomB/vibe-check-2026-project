# D01: Which Lean toolchain to pin (v4.35.0) and matching dependency tags

## Citation / identity
- Project: Lean 4 (leanprover/lean4), plus tag lists of Mathlib, Batteries, plausible, repl, iris-lean.
- Sources (all fetched 2026-10-31):
  - https://github.com/leanprover/lean4/releases (GitHub releases page; official)
  - https://github.com/leanprover/lean4/releases/tag/v4.35.0 (official; says only "This is the v4.35.0 release", links to notes)
  - https://lean-lang.org/doc/reference/latest/releases/ (official release-notes index)
  - https://lean-lang.org/doc/reference/latest/releases/v4.35.0/ (official release notes, read in two parts)
  - https://lean-lang.org/doc/reference/latest/releases/v4.29.0/ (official release notes; native_decide change)
  - https://github.com/leanprover/lean4/releases/expanded_assets/v4.35.0 (download sizes)
  - Tag lists via the GitHub API (GitHub MCP `list_tags`) for leanprover-community/mathlib4, leanprover-community/batteries, leanprover-community/plausible, leanprover-community/repl, leanprover-community/iris-lean.
- Source type: official release notes and official code repositories.
- Latest versions seen: stable **v4.35.0 (2026-10-12)**; newest prerelease **v4.36.0-rc2 (2026-10-27)**; v4.36.0-rc1 (2026-10-14); v4.34.1 (2026-09-24).
- License: Lean 4 is Apache-2.0 (not re-checked today; unsure for this exact release page).

## The "4.53" question (settled)
- The official index lists every release from v4.0.0-m1 up to 4.36.0-rc2. **There is no v4.53.** (documented behavior: the index page)
- "ideally 4.53" in CLAUDE.md is almost surely a typo for 4.35. The same file says Comparator is "built into Lean 4.35", and the v4.35.0 notes confirm `lake check` and `lake comparator` ship in v4.35.0.
- Decision: **pin `leanprover/lean4:v4.35.0`** (what the repo already has). Do not move to v4.36.0-rc2: it is a release candidate, and Mathlib/Batteries/plausible all have a `v4.35.0` tag.

## Dependency tags that match v4.35.0 (documented: tag lists seen today)
| Repo | Tag | Commit SHA seen |
|---|---|---|
| leanprover-community/mathlib4 | v4.35.0 | 56a005855ea17e0b0958f73ec801ae140b0a1679 |
| leanprover-community/batteries | v4.35.0 | 66e469188fe07963e5cf666c7d4433f45b8131c5 |
| leanprover-community/plausible | v4.35.0 | dfa4f38190d07c37e315953e08b90fe2d95b3c24 |
| leanprover-community/repl | v4.35.0 | 58bdde1ff173117960083cc5a052a11d51c49ff1 |
| leanprover-community/iris-lean | v4.35.0 | 9a4ae0df7ea421267d6cbed9496a3845dd14e1e1 |

Note: the `main`/`master` branches of plausible and repl already point at `leanprover/lean4:v4.36.0-rc2` (read from their lean-toolchain files). So **we must pin `rev = "v4.35.0"`**, never `main`, or Lake will pull code for the wrong Lean.

Example lakefile.toml shape (our own suggestion, not copied from a doc):
```toml
[[require]]
name = "plausible"
git = "https://github.com/leanprover-community/plausible"
rev = "v4.35.0"
```

## What changed in v4.35.0 that matters to us (claim status: documented behavior, release notes)
- `lake check` (#14990) and `lake comparator` (#14885, #15146; renamed from `lake challenge`) are in core. See D02.
- `vcgen` replaces `mvcgen` (#14874); `mvcgen` is deprecated. Experimental; `set_option experimental.vcgen true` silences the warning. See D03.
- `Decidable` is now a structure holding a `Bool` plus a proof (#8309). `isTrue`/`isFalse` still work as match patterns. Old tutorials that build `Decidable` instances by hand may need small fixes.
- `Lean.reduceBool`, `Lean.reduceNat`, `Lean.ofReduceBool`, `Lean.ofReduceNat` and the `Lean.trustCompiler` axiom were **removed** (#14953), after deprecation since 2026-02-01. Migration: use `native_decide`.
- Since v4.29.0 (#12217, RFC #12216), each `native_decide` / `bv_decide` call is "one axiom per computation", with an auto-generated name containing `._native.` (for example `._native.bv_decide.`). `#print axioms` shows those names, not `Lean.trustCompiler`.
- Breaking changes we may hit: `rwa ... at h` now fails if `h` alone does not close the goal (#14937); `constructor` warns when several constructors match (#14854; `constructor!` restores old behavior); range precedence: `1 + 2...3` means `(1 + 2)...3` (#15054).
- `Std.Http.Server` exists in this release (fix #15043 for idle keep-alive connections). See D06.
- LLVM 23.1.0 (#14531); mimalloc built with `MI_MAX_ALIGN_SIZE=8` so `List.cons` takes 24 bytes not 32 (#14948).
- `Nat.powMod` added (#13490) so `decide` can check large modular powers.
- Lake: dependencies are now fetched as treeless partial clones of one revision (#14782): smaller downloads for `make install`.

## Download size for `make install` (documented: GitHub asset list, rounded)
| Asset | Size |
|---|---|
| lean-4.35.0-linux.tar.zst | 567 MB |
| lean-4.35.0-linux_aarch64.tar.zst | 567 MB |
| lean-4.35.0-darwin_aarch64.tar.zst | 544 MB |
| lean-4.35.0-darwin.tar.zst | 550 MB |
| lean-4.35.0-windows.tar.zst | 594 MB |
| (.zip variants) | 844 to 885 MB |

- Which archive format elan picks: unsure (not checked today).
- Time: opinion only. About 1 to 2 minutes at 50 to 100 Mbit/s, plus unpacking. On slow venue Wi-Fi it could take 5 to 10 minutes. This is the biggest cost of `make install`. Mathlib would add its cache download on top (size not checked today), so avoid Mathlib.

## Fit for a poker engine (pure Lean functions + small IO shell)
- v4.35.0 has everything we need in core: `Rat` (D07), `Lean.Json` (D06), `Std.Http.Server` (D06), `vcgen` (D03), `lake check`/`lake comparator` (D02).
- Not depending on Mathlib keeps `make install` to one toolchain download plus small git clones.

## Recommendations
1. Keep `lean-toolchain` = `leanprover/lean4:v4.35.0`. Do not use 4.36 rc.
2. Pin every `[[require]]` to `rev = "v4.35.0"` where such a tag exists; commit `lake-manifest.json` (also required by `lake check`, see D02).
3. Skip Mathlib unless a teammate needs a specific lemma. Core + Batteries (+ plausible for testing) should be enough.
4. Tell the team about the `Decidable` structure change and `rwa` change before they copy older proof snippets.

## Candidate checks
- "Toolchain sanity": a CI-style `make check-versions` that greps `lean-toolchain` and `lake-manifest.json` revs. 0.5 h. (engineering, not a theorem)
