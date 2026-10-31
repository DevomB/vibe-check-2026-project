# Summary: D07: Performance of compiled Lean for enumeration; `decide` vs `native_decide`; exact `Rat`

**Source:** Ullrich, de Moura. "Counting Immutable Beans: Reference Counting Optimized for Purely Functional Programming." IFL 2019. https://arxiv.org/abs/1908.05647. Lean reference manual: https://lean-lang.org/doc/reference/latest/Basic-Types/Natural-Numbers/

**TL;DR.** Prove general theorems instead of evaluating huge cases in the kernel. Use exact `Rat` (it is in core) for EV. Benchmark preflop equity early.

- A preflop all-in has 1,712,304 boards, so about 3.4 million hand evaluations per spot. That needs a fast `UInt64` bitmask evaluator; `UInt64` values get boxed inside `Array`.
- I found no public benchmarks of compiled Lean for this kind of code. All speed figures here are estimates, not measurements.
- `decide` runs in the kernel: slow but trusted. `native_decide` trusts the compiler and fails `lake check`.
- `Rat` is in core at v4.35, so exact rational EV needs no Mathlib.

Verdict: use.

Full extraction: [notes.md](notes.md).
