# Summary: D04: Testing tools: plausible, Specimen, LSpec

**Source:** plausible: https://github.com/leanprover-community/plausible. Specimen: https://reservoir.lean-lang.org/@strata-org/specimen. LSpec: https://github.com/argumentcomputer/LSpec

**TL;DR.** Use plausible for property-based testing before proving. Skip LSpec and Specimen.

- plausible has a `v4.35.0` tag. Random actions are rarely legal, so write a generator for legal action sequences.
- LSpec pins v4.34.1 and Specimen pins v4.34.0, so neither matches our toolchain.
- Core `#guard` and `example ... := by decide` cover unit tests with no dependency.
- Run plausible on each main statement before proving it, and again when a proof stalls.

Verdict: use (plausible only).

Full extraction: [notes.md](notes.md).
