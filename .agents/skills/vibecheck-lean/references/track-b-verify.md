# Track B: verify existing code

Lean cannot read Python, TypeScript, Go or C. Verifying existing code means
getting a faithful Lean version of it first. Only Rust has a real translation
pipeline; for everything else, port the core, prove the port, and show the port
matches the original.

Start every Track B session with:

```bash
python3 <skill>/scripts/detect_repo.py /path/to/repo
```

It reports the language mix, Rust features that block extraction, protocol
vocabulary, a recommended route order, and a ranked list of small, branchy,
I/O-free functions. Treat the candidates as suggestions: read the top few with
the human and pick one whose behaviour they can describe in a sentence.

## Routes

| Route | When `detect_repo.py` picks it | What you can honestly claim |
| --- | --- | --- |
| `port-prove-difftest` | Any language without extraction (Python, TS/JS, Go, C, Java, ...) | The algorithm as ported meets its spec, and the original agrees with the port on N random inputs |
| `port-prove-replace` | Languages that can call a C ABI or a subprocess | The shipped core is the verified code |
| `rust-extract` | Rust with little `unsafe`, `async` or interior mutability | Proofs about the actual Rust code |
| `rust-extract-one-function` | Rust that uses those features elsewhere | Same, for one function and its dependencies |
| `veil-protocol` | Strong distributed-protocol vocabulary (raft, paxos, quorum, ...) | Safety invariants of the protocol design, not its code |
| `lean-native` | The repo is already Lean | Properties of the existing definitions |

Order matters: try the first route, and fall back to `port-prove-difftest` if the
first hour shows the pipeline will not cooperate.

---

## Route: port, prove, differential-test

1. **Scaffold** a Lean project next to the repo (ask where; a sibling folder is a
   good default, never inside the original repo): `new_project.py NAME-verified --dir ..`.
   Replace the template's `transfer` example in `Impl`, `Spec`, `Proofs` and
   `Main` together.
2. **Port the function line by line** into `Impl.lean`. Keep the original's
   structure, names and bugs. Map types deliberately:

   | Original | Lean | Watch out for |
   | --- | --- | --- |
   | Python `int` | `Int` (or `Nat` if provably non-negative) | Python ints are unbounded; Lean `Int` matches |
   | Python `//`, `%` | `/`, `%` on `Int` when the divisor is always positive; otherwise `Int.fdiv`, `Int.fmod` | Lean's `/` is Euclidean: `7 / -2 = -3` in Lean, `-4` in Python |
   | C, Go, Rust, Java `/`, `%` on signed ints | `Int.tdiv`, `Int.tmod` | They truncate toward zero: `-7 / 2 = -3` |
   | JS/TS `number` used as an integer | `Int` | Values past 2^53 lose precision in JS; note it as a known gap |
   | Go/C/Rust `int32`, `uint64` | `Int32`, `UInt64` (wrapping) or `Int` + an explicit range spec | Overflow behaviour must match the original |
   | `float` / `double` | Avoid; restate over `Int` cents, or keep it unverified | Float proofs are expensive |
   | `None` / `null` / error returns | `Option` or `Except String` | Exceptions become explicit returns |
   | lists, arrays | `List` (easier proofs) or `Array` | |
   | dict / map | `Std.HashMap` or an association `List` | Iteration order |
   | strings | `String`, or `List Char` for proofs about characters | |
   | mutation and loops | `Id.run do` with `let mut` and `for` | Prove with `mvcgen` |

3. **Spec and prove** as in Track A. If a property is false, Lean will not
   prove it: find the counterexample (`#eval` on small inputs in a `Scratch/`
   file, which the audit ignores) and record it as a **finding**: a proved
   property whose doc comment starts with `FINDING:`, stating that a bad input
   exists. The report lists findings in their own section. Then prove the
   property that does hold, with the missing precondition made explicit:

   ```lean
   /-- FINDING: a coupon over 100% makes the price negative. -/
   def bugCouponCanGoNegative : Prop :=
     ∃ total percent cap : Int, 0 ≤ total ∧ 0 ≤ cap ∧ apply_coupon total percent cap < 0

   /-- Headline. With a valid coupon, the price stays between 0 and the original total. -/
   def couponInRange : Prop :=
     ∀ total percent cap : Int, 0 ≤ total → 0 ≤ percent → percent ≤ 100 → 0 ≤ cap →
       0 ≤ apply_coupon total percent cap ∧ apply_coupon total percent cap ≤ total
   ```

   A finding is proved by giving the input: `⟨1000, 150, 10000, by decide⟩`.
   A real bug, demonstrated against the original code, is a strong hackathon result.
4. **Differential test.** Copy `assets/difftest/Serve.lean` to the project root
   (replace `__LIB__`), add one `dispatch` case per ported function, register it:

   ```toml
   [[lean_exe]]
   name = "serve"
   root = "Serve"
   ```

   Copy `assets/difftest/difftest.py`, import the original function, write an
   input generator, then:

   ```bash
   lake build serve && python3 difftest.py 100000
   ```

   It runs 20,000 to 70,000 inputs a second and prints the first disagreement
   with both outputs. Generate negative numbers and huge values too: they are
   where ports and originals disagree (division, overflow). Run two seeds. For a TypeScript or JavaScript original, write the same loop in
   a small Node script: spawn `.lake/build/bin/serve`, write one JSON request per
   line, compare with the original's result. For other languages, call the
   original from Python through a subprocess, or write the loop in that language.
5. **Report the number** of inputs and the seed in the README. It closes the gap
   between "we proved our port" and "we proved their code" as far as testing can.

## Route: port, prove, replace

Same as above through step 3, then make the original call the verified port.
The simple, robust way is the same `serve` binary: the original spawns it once
and sends requests over stdin and stdout. Linking Lean into a C program through
`@[export]` is possible but needs the Lean runtime initialised in the host; only
attempt it with a helper who has done it before.

## Route: Rust extraction (hax, Charon, Aeneas)

Tested end to end on 2026-10-30 with cargo-hax 0.4.2. Expect these costs, and set
up the night before:

- `cargo install --locked cargo-hax` takes about a minute.
- The first `cargo hax into lean` downloads Charon, Aeneas and a pinned Rust
  nightly (about 40 seconds on a fast connection).
- The generated Lean project pins **its own Lean version** (4.31.0 at the time of
  writing) and depends on Aeneas and Mathlib: `lake exe cache get` then
  `lake build` took about 2 minutes with a warm cache, and the `.lake` folder
  reached **7.7 GB**.

Steps, run from the crate folder (not the workspace root):

```bash
cargo hax into lean                                   # whole crate
cargo hax into lean --charon-args="--start-from my_crate::module::my_fn"   # one function
cd proofs/lean && lake exe cache get && lake build
```

Output layout:

- `<Pkg>/Extraction/`: generated, overwritten on every extraction. Never edit.
- `<Pkg>/Assumptions/`: models of external functions, seeded once; fill holes there.
- `<Pkg>/Verification/`: yours. hax never touches it.

Put properties in `<Pkg>/Verification/Spec.lean` (namespace `<Pkg>.Spec`) and
proofs in `<Pkg>/Verification/Proofs.lean`, and add
`import <Pkg>.Verification.Proofs` to `Verification/ProofObligations.lean` so the
build includes them. `audit.py` then works unchanged.

What extracted code looks like: every function returns `RustM α` (Aeneas's
result monad: `.ok v`, `.fail e` for panics, `.div`), machine integers are
`Std.U64`, `Std.I32` and so on with `.val` giving the mathematical value, and
`Option` becomes `core.option.Option` with `.Some`/`.None`. A worked example that
compiles against that extraction:

```lean
import LedgerRs.Extraction
open CoreModels Aeneas
open Aeneas.Std hiding namespace core alloc
open ledger_rs

-- Rust: pub fn clamp(x: i32, lo: i32, hi: i32) -> i32
theorem clampInRange (x lo hi : Std.I32) (h : lo.val ≤ hi.val) :
    ∃ r, clamp x lo hi = .ok r ∧ lo.val ≤ r.val ∧ r.val ≤ hi.val := by
  unfold clamp
  split <;> (try split) <;> simp_all

-- Rust: transfer with `a - amt` and `b.checked_add(amt)`
theorem conserves (a b amt a' b' : Std.U64)
    (h : transfer a b amt = .ok (.Some (a', b'))) : a'.val + b'.val = a.val + b.val := by
  unfold transfer at h
  simp only [core.num.U64.checked_add, core.num.U64.overflowing_add,
    rust_primitives.arithmetic.overflowing_add_u64] at h
  split at h
  · have hadd := UScalar.overflowing_add_eq b amt
    have hsub := UScalar.sub_equiv a amt
    generalize UScalar.overflowing_add b amt = p at h hadd
    obtain ⟨r, o⟩ := p
    cases hs : a - amt <;> split at hadd <;> simp_all <;> grind
  · simp at h
```

Lessons from that run:

- **Pure arithmetic and branching extract and prove easily** (`clamp` took one line).
- **Every standard-library call needs its model unfolded.** `checked_add` lives in
  hax's `CoreModels`; its meaning comes from Aeneas lemmas such as
  `UScalar.overflowing_add_eq` and `UScalar.sub_equiv`. Find them with
  `grep -rn "theorem .*<name>" .lake/packages/aeneas/backends/lean .lake/packages/hax`.
- **Pick the first target with no std calls** so the team gets a win before
  meeting the library models.
- Not supported: `unsafe`, interior mutability, concurrency, returning or aliasing
  `&mut`, `return`/`break` out of nested loops. Check before committing to a function.

Docs: [hax Lean quick start](https://hax.cryspen.com/manual/lean/quick_start/),
[Aeneas](https://github.com/AeneasVerif/aeneas) (its `tests/lean/Tutorial` is the
best worked material), Zulip `aeneas-verif.zulipchat.com`.

## Route: protocol model in Veil

For consensus, replication or leader-election code, verify the design: model the
protocol as a transition system in [Veil](https://github.com/verse-lab/veil),
state the safety invariant (at most one leader per term, no two nodes commit
different values), and let Veil's model checker and SMT automation prove it or
produce a counterexample trace.

```bash
git clone https://github.com/verse-lab/veil.git && cd veil && lake build
```

Needs Node.js and a C toolchain (`xcode-select --install` on macOS); the
`lean-cvc5` build is sometimes flaky, so retry once. Start from
`Examples/Tutorial/Ring.lean` (leader election) and `Examples/Tutorial/FloodSet.lean`,
and read `docs/DSL-Reference.md` before writing a model. Browser version:
<https://try.veil.dev>. Be explicit in the README that the result covers the
design, and list where the code could deviate from it.

## Route: already Lean

Add `<Lib>/Spec.lean` with properties of existing definitions and
`<Lib>/Proofs.lean`, import both from the root module, and run the audit.
