# Summary: D01: Which Lean toolchain to pin (v4.35.0) and matching dependency tags

**TL;DR.** Lean v4.53 does not exist; the "4.53" in CLAUDE.md is a typo for 4.35. Pin `leanprover/lean4:v4.35.0` (stable, released 2026-10-12), which the repo already does.

- Mathlib, Batteries, plausible, repl and iris-lean all have a `v4.35.0` tag.
- plausible and repl `main` have already moved to v4.36.0-rc2, so pin `rev = "v4.35.0"` and never track `main`.
- Breaking changes to watch: `Decidable` is now a structure, `rwa` is stricter, `constructor` warns when ambiguous.
- Commit `lake-manifest.json`; `lake check` needs it.

Verdict: use. This settles the toolchain question.

Full extraction: [notes.md](notes.md).
