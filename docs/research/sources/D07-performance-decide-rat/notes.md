# D07: Performance of compiled Lean for enumeration; `decide` vs `native_decide`; exact `Rat`

## Summary

**Source:** Ullrich, de Moura. "Counting Immutable Beans: Reference Counting Optimized for Purely Functional Programming." IFL 2019. https://arxiv.org/abs/1908.05647. Lean reference manual: https://lean-lang.org/doc/reference/latest/Basic-Types/Natural-Numbers/

**TL;DR.** Prove general theorems instead of evaluating huge cases in the kernel. Use exact `Rat` (it is in core) for EV. Benchmark preflop equity early.

- A preflop all-in has 1,712,304 boards, so about 3.4 million hand evaluations per spot. That needs a fast `UInt64` bitmask evaluator; `UInt64` values get boxed inside `Array`.
- I found no public benchmarks of compiled Lean for this kind of code. All speed figures here are estimates, not measurements.
- `decide` runs in the kernel: slow but trusted. `native_decide` trusts the compiler and fails `lake check`.
- `Rat` is in core at v4.35, so exact rational EV needs no Mathlib.

Verdict: use.

## Citation / identity (all fetched 2026-10-31)
- Ullrich, S. and de Moura, L. "Counting Immutable Beans: Reference Counting Optimized for Purely Functional Programming". IFL 2019 (peer-reviewed workshop; arXiv:1908.05647 v3, 2020-03-05). https://arxiv.org/abs/1908.05647
- Lean reference manual, Natural Numbers: https://lean-lang.org/doc/reference/latest/Basic-Types/Natural-Numbers/ (official; read in two parts)
- Lean reference manual, Fixed-Precision Integers: https://lean-lang.org/doc/reference/latest/Basic-Types/Fixed-Precision-Integers/ (official; first 100k chars read)
- Lean reference manual, Tactic Reference (`decide`): https://lean-lang.org/doc/reference/latest/Tactic-Proofs/Tactic-Reference/ (official; read in three parts; `native_decide` entry itself was cut off)
- Lean v4.29.0 release notes (native computation axioms, #12217): https://lean-lang.org/doc/reference/latest/releases/v4.29.0/
- Lean v4.35.0 release notes (#14953 removal of `ofReduceBool`/`trustCompiler`; `Nat.powMod`): https://lean-lang.org/doc/reference/latest/releases/v4.35.0/
- `Rat` API docs: https://lean-lang.org/doc/api/Init/Data/Rat/Basic.html (official; doc build version not shown)
- Ramos, A. F. and Soria, T. "From Rules to Nash Equilibria: A Lean 4 Case Study in Game-Theoretic Analysis of a Competitive Trading Card Game". arXiv:2607.08692, 2026-07-09, **preprint** (not peer-reviewed). https://arxiv.org/abs/2607.08692
- Searched for recent public benchmarks of compiled Lean vs C/OCaml/Haskell: **none found** in official or peer-reviewed sources (search results only pointed to older work and a non-peer-reviewed extraction report, not opened, not counted).

## 1. How fast is compiled Lean? (claim status noted)
- Lean compiles to C and uses exact reference counting. When a value has only one reference, updates happen in place ("destructive updates"), so `Array.set` on an unshared array does not copy. (proved on paper / shown empirically in Counting Immutable Beans; documented design.) The paper reports "preliminary experimental results" that are "competitive and often outperforms state-of-the-art compilers" (shown empirically, 2019, old compiler).
- v4.35.0: `markLinear` on `String`, `ByteArray`, `FloatArray`, `Array` (#15052); env var `LEAN_ABORT_ON_NONLINEAR` aborts on non-linear (copying) writes. Useful to catch hidden array copies in hot loops. (documented)
- Small `Nat` values: no allocation; 63 bits on 64-bit machines are stored in the pointer itself; bigger values become heap bignums. (documented)
- Fixed-width integers (documented, Fixed-Precision page):
  - In monomorphic code (code that uses one concrete type), `UInt64` can be used unboxed, possibly after specialization.
  - In polymorphic containers such as `Array`, values are **boxed** even if the array only holds `UInt64`. `UInt64`, `USize`, `Int64` "may require pointers on all architectures" when boxed. `UInt8`, `UInt16`, `Int8`, `Int16` (and `UInt32`/`Int32` on 64-bit) never need a pointer.
  - `ByteArray` stores `UInt8` without boxing.
  - Boxing "tends to happen at the edges of integer calculations rather than for each intermediate result".
- `@[specialize]` / `@[inline]`: I found no official page in this pass (UNVERIFIED). Background knowledge: `@[inline]` asks the compiler to inline; `@[specialize]` makes copies of higher-order functions for each concrete function argument. Treat as unverified.

### Our enumeration sizes (arithmetic, ours)
| Spot | Unknown cards (both hands known) | Runouts | 7-card evaluations (2 per runout) |
|---|---|---|---|
| River | 0 | 1 | 2 |
| Turn | 44 | 44 | 88 |
| Flop | C(45,2) | 990 | 1,980 |
| Preflop | C(48,5) | 1,712,304 | 3,424,608 |

- Opinion (not measured, no benchmark found): a bitmask evaluator in compiled Lean (ranks per suit packed in a `UInt64`, lookup tables in `ByteArray`, no `List` allocation in the inner loop) might run in roughly 0.1 to 1 µs per 7-card hand, so preflop takes about 0.3 to 3.5 s. A naive evaluator that builds all 21 five-card `List`s and sorts them could be 10 to 100 times slower (tens of seconds to minutes preflop). **Measure in hour 2 to 4.**
- Flop/turn/river equity is trivial at any speed. Only preflop all-in needs a fast evaluator.
- Mitigations for preflop: run the review in a background `Task` and show progress; or show turn/flop exact and preflop after it finishes; or use suit symmetry (opinion).

## 2. `decide`, `decide +kernel`, `native_decide`: what each trusts (documented)
- `decide`: finds a `Decidable p` instance and reduces it to `isTrue h` in the elaborator, then the kernel checks it. Trust: kernel only. Goal must have no free variables (`+revert` helps).
- `decide +kernel`: reduction done by the kernel itself; ignores transparency; reduces the instance once, not twice. The manual mentions no extra axiom. Trust: kernel only.
- Limits for both: instances defined by well-founded recursion may not reduce; `Eq.rec` from `rw`/`simp`-built instances can get stuck (use `decidable_of_iff`). Large computations are slow in the kernel: the kernel is an interpreter, not compiled code.
- Kernel `Nat` support: literals use GMP ("a widely-trusted, efficient arbitrary-precision integer library"). The page lists kernel (and compiler) overrides for `Nat.add`, `Nat.sub`, `Nat.mul`, `Nat.pow`, `Nat.gcd`, `Nat.beq`, `Nat.ble`, `Nat.blt`, `Nat.decEq`. For `Nat.div`, `Nat.mod`, `Nat.log2` the part I read mentions only runtime/compiler overrides (unsure whether the kernel also accelerates them).
- `decide +native` / `native_decide`: evaluates with compiled code, "admitting the result via an axiom". Trust grows to the whole Lean compiler and every `@[implemented_by]` definition. Since v4.29.0 each use adds its own auto-named axiom (name contains `._native.`). `Lean.ofReduceBool` and `Lean.trustCompiler` no longer exist (removed in v4.35.0, #14953).
- **Consequence (inference from D02): `native_decide` makes `lake check` fail**, because `lake check` only allows `propext`, `Classical.choice`, `Quot.sound`. The Pokémon TCG Nash-equilibrium preprint (arXiv:2607.08692) relies on `native_decide` for its headline results: a warning example of a game-theory Lean project that would not pass `lake check`.
- v4.35.0: `Decidable` is now a structure (Bool + proof), so many equations hold by `rfl` (#8309); `Nat.powMod` (#13490) lets `decide` check large modular powers.

### What this means for us
- We cannot prove "equity of this preflop all-in is exactly 0.8123" by `decide` (1.7M boards in the kernel is far too slow) and must not use `native_decide`.
- Instead prove **general** theorems about the code: "the equity function equals (wins + ties/2) / total over the list of all boards", "the board list has no duplicates and no dead cards", "the fast evaluator agrees with the reference evaluator". The app then runs the compiled code; the theorems say the compiled code computes the right thing.
- `decide` is fine for small finite facts: Kuhn poker (3 cards, 6 deals), evaluator unit cases, "these 4 chip-count edge cases settle correctly".

## 3. Exact rationals: `Rat` is in core (documented)
- `Rat` lives in core module `Init.Data.Rat.Basic`. Fields: `num : Int`, `den : Nat`, `den_nz : den ≠ 0`, `reduced : num.natAbs.Coprime den` (always in lowest terms).
- Operations on the page: `add`, `mul`, `div`, `inv`, `neg`, `sub`, `pow`, `zpow`, `blt`, `<`, `≤`, `min`, `max` (decidable), `ofScientific`, `floor`, `ceil`, `abs`, `divInt`, `mkRat`, `normalize`. v4.29.0 added `Rat.abs`.
- `Rat.toFloat` (for display): not seen on the page (unsure). Display can format `num`/`den` ourselves.
- Advice: use `Rat` for EV and equity in the spec and the review. For `decide` proofs (Kuhn), consider scaling to integers (for example, probabilities as `Nat` numerators over a fixed denominator) so the kernel only does `Nat`/`Int` arithmetic, which is GMP-accelerated for `+`, `-`, `*`. Opinion; `decide` over `Rat` may work but was not tested.

## Fit for a poker engine
- Pure functions + compiled code are fast enough for flop/turn/river and probably for preflop with a bitmask evaluator.
- Proof approach: theorems over all inputs, not kernel evaluation of huge enumerations.

## Recommendations
1. Two evaluators: `evalRef` (obviously correct: try all 21 five-card subsets, compare by a clear ranking) and `evalFast` (bitmask). Prove or at least exhaustively test `evalFast = evalRef`.
2. Hot loops: monomorphic `UInt64` code, `ByteArray` tables, no `List` in the inner loop; run with `LEAN_ABORT_ON_NONLINEAR` once to catch copies.
3. Benchmark preflop in hour 2 to 4 with a `#eval`-free compiled `lake exe bench`.
4. Exact `Rat` for EV in reviews; no `Float` in anything a theorem talks about.
5. No `native_decide`, anywhere a main theorem depends on.

## Candidate theorems (plain English, rough Lean shape, hours)
- Board enumeration is complete and clean: every board in `runouts dead k` has `k` cards, none dead, no repeats, and the list has `Nat.choose (52 - dead.length) k` entries (given `dead` has no repeats).
  `theorem runouts_length (dead : List Card) (h : dead.Nodup) : (runouts dead k).length = Nat.choose (52 - dead.length) k` 4 to 8 h.
- Equity is the plain average: `equity a b board = (wins + ties / 2) / total` where the counts are taken over `runouts`. Shape: `theorem equity_eq_ref : equity a b bd = equityRef a b bd` with `equityRef` written as a simple `List.foldl` over `runouts`. 2 to 4 h.
- Equities of the two players sum to 1 (heads-up): `equity a b bd + equity b a bd = 1` (needs total > 0). 2 to 3 h. Good "spec rejects bad output" pairing.
- Fast evaluator agrees with reference: `∀ h : Hand7, evalFast h = evalRef h`. Full proof is hard (8 to 20 h); exhaustive testing over all C(52,7) hands at runtime is ~134M evaluations (opinion: minutes) and is a strong differential test. Proof over a symbolic hand: stretch.
- Kuhn equilibrium by `decide` on scaled integers: "neither player gains by switching to any of their 64 pure strategies". 3 to 6 h.
