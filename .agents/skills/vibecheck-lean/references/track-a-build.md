# Track A: build new verified software in Lean

Write the program in Lean from the start. Code and proof live in one project, so
nothing is lost in translation, and the shipped binary is the verified code.

## The loop

1. **Headline property in English.** One sentence a non-expert would care about:
   "a transfer never creates or destroys money", "undo restores the previous
   document exactly". Agree on it with the human before any code.
2. **Scaffold.** `python3 <skill>/scripts/new_project.py NAME --dir PARENT` (ask
   where they want it). This gives `Impl.lean` (code), `Spec.lean` (properties,
   human-owned), `Proofs.lean`, `Main.lean`, `CLAUDE.md` with agent rules,
   `.mcp.json` for lean-lsp, and a passing `transfer` example to imitate. The
   example is referenced from `Impl`, `Spec`, `Proofs` and `Main`: replace it in
   all four in the same change, or the build breaks with `Unknown identifier transfer`.
3. **Reference first.** In `Impl.lean`, write the slowest, most obviously
   correct version. It is itself a spec.
4. **Spec.** In `Spec.lean`, one `def name : Prop` per property, each with a
   one-sentence doc comment. Start the headline property's doc comment with
   `Headline.` so the report lists it first. Pair every safety property ("never
   more than N") with a liveness one ("a full bucket allows a burst"): a limiter
   that refuses everything satisfies every safety property. The human reads every
   statement; then lock it: `audit.py --lock`.
5. **Real implementation.** Loops, arrays, hash maps: Lean's `do` notation reads
   like Python. If there is both a simple reference and a fast version, add a
   property "fast = reference"; if there is only one version, skip this.
6. **Prove.** `theorem name : Spec.name` in `Proofs.lean`. Try `grind` first.
7. **Wire it up.** `Main.lean` runs the verified core on real input so the demo
   is a program, not a page of proofs. I/O stays in `Main.lean`.
8. **Check the spec has teeth.** Break the code on purpose in a scratch copy
   (drop a cap, refuse everything, add a free token) and confirm a proof fails.
   If none does, the spec is too weak.
9. **Audit.** `audit.py --report` writes `VERIFICATION.md` for the judges.

**What the spec lock covers.** The lock hashes `Spec.lean` only. If a property
mentions a function from `Impl.lean`, changing that function changes what the
locked property means. Keep a property's vocabulary honest: either the function
is the code under test (that is the point), or it is a definition that gives the
property its meaning (a reference implementation, a "valid input" predicate),
and those belong in `Spec.lean` so the lock covers them.

## Patterns

**Safety property** (from the template):

```lean
def conserves : Prop :=
  ∀ a b amt a' b', transfer a b amt = some (a', b') → a' + b' = a + b

theorem conserves : Spec.conserves := by
  intro a b amt a' b' h
  unfold transfer at h
  split at h <;> grind
```

**Fast equals reference** (accumulators need a generalized lemma; see exercise L5):

```lean
theorem sumAcc_eq (acc : Nat) (xs : List Nat) : sumAcc acc xs = acc + sumRef xs := by
  induction xs generalizing acc with
  | nil => simp [sumAcc, sumRef]
  | cons x xs ih => simp [sumAcc, sumRef, ih]; omega
```

**Imperative loop** with `mvcgen` (Lean 4.35 warns it is deprecated in favour of
`vcgen`; `vcgen` is still experimental and fails on this example, so keep `mvcgen`):

```lean
import Std.Tactic.Do
open Std.Do

def mySum (l : Array Nat) : Nat := Id.run do
  let mut out := 0
  for i in l do
    out := out + i
  return out

theorem mySum_correct (l : Array Nat) : mySum l = l.sum := by
  generalize h : mySum l = x
  apply Id.of_wp_run_eq h
  mvcgen invariants
  · ⇓⟨xs, out⟩ => ⌜xs.prefix.sum = out⌝
  with grind
```

The invariant describes what holds after processing `xs.prefix`. Writing it is
the only creative step; `mvcgen` generates the rest. Full tutorial:
<https://lean-lang.org/doc/tutorials/4.34.0/mvcgen/>.

**Roundtrip** (best value per hour: easy to state, easy to demo, catches real bugs):

```lean
/-- Decoding an encoded value gives back the original. -/
def roundtrip : Prop := ∀ v, decode (encode v) = some v
```

**Invariant in the type** (see exercise L7): a structure carrying a proof field,
so illegal states cannot be built.

## Scoping for a weekend

- Verify the core, not the app. A verified rate limiter, diff, CRDT merge or
  interpreter wrapped in unverified I/O is a strong result.
- Prefer `Nat`, `Int`, `List`, `Array`, `Std.HashMap`. Floats, byte-level
  strings and concurrency are where proofs get expensive.
- One meaningful property fully proved beats ten stated with `sorry`. Get the
  headline theorem by Saturday evening; everything after is extra.

## Project ideas

| Idea | Difficulty | Headline theorem |
| --- | --- | --- |
| Bank ledger or wallet | Starter | No sequence of operations changes the total supply |
| Token-bucket rate limiter | Medium | No window of T ticks admits more than capacity + rate·T requests (needs a budget lemma by induction) |
| Permission checker | Starter | A user without role R is never granted action A |
| Undo/redo stack | Medium | Undo after any edit restores the previous document exactly |
| JSON or CSV printer/parser | Medium | `parse (print v) = some v` |
| Run-length compressor | Medium | `decompress (compress s) = s` |
| Calculator / tiny interpreter | Medium | The optimizer never changes what a program evaluates to |
| Line diff | Medium | Applying the patch to the old file yields the new file |
| Game logic (2048, Sudoku checker) | Medium | The board never enters an invalid state |
| CRDT counter or set | Medium to hard | Replicas that see the same updates converge |
