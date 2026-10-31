# Summary: D03: Program-verification tools: core `vcgen` (Std.WP / Std.Do), Velvet, iris-lean, Veil

**TL;DR.** Core `vcgen`, Velvet, iris-lean and Veil are built for imperative or concurrent code. Our engine is pure functions, so ordinary Lean proofs are enough.

- `vcgen` (core v4.35) is experimental; at most try it on one loop as a stretch.
- Velvet is young. Veil pins v4.32.0, and it targets protocols, not game engines.
- iris-lean (separation logic) does not fit pure code.
- Writing the engine as pure functions over a state record is the design choice that keeps proofs cheap.

Verdict: maybe. `vcgen` is a stretch only; skip the rest.

Full extraction: [notes.md](notes.md).
