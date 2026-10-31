# Lean in ten minutes

Use this to give the first explanation. Say it in your own words and keep it short;
then put a file in front of the learner as fast as possible. People learn Lean by
watching a goal shrink, not by reading about it.

## The one idea

Lean is a programming language whose type checker also checks proofs. If a file
compiles with no `sorry`, every theorem in it is true. You write a program, write
a statement about it, and Lean refuses to compile until the statement is proved.

## Five things to know

1. **Programs are ordinary functional code.** `def` defines, `#eval` runs. Lean
   compiles to C, so programs are real executables.
2. **A theorem is a type; its proof is a value of that type.** `theorem foo : P := proof`
   compiles only if `proof` proves `P`.
3. **Tactics build the proof step by step.** After `by`, commands such as `unfold`,
   `simp`, `omega`, `grind` and `induction` transform the goal; the infoview shows
   what is left after each line.
4. **A small kernel re-checks everything.** Tactics and AI can be wrong; the kernel
   cannot be talked into accepting a false proof. That is why an AI-written proof
   can be trusted and an AI-written test cannot.
5. **`sorry` is a hole.** It lets unfinished work compile with a warning. Anything
   resting on `sorry` proves nothing.

## Reading the infoview

Click inside a proof. The panel shows the goal:

```
a b amt a' b' : Nat
h : transfer a b amt = some (a', b')
⊢ a' + b' = a + b
```

Above the line are the facts you have (hypotheses); below `⊢` is what you must
prove. Teach learners to read this before anything else: most confusion is a
misread goal.

## Tactic cheat sheet

| Tactic | What it does | Reach for it when |
| --- | --- | --- |
| `grind` | SMT-style automation: case splits, congruence, arithmetic | First thing to try on most goals |
| `simp [f, g]` | Rewrites with definitions and simp lemmas until stuck | The goal mentions your functions |
| `omega` | Decides linear arithmetic over `Nat` and `Int` | `+`, `-`, `<`, `≤`, constants, `%` by literals |
| `unfold f` / `unfold f at h` | Replaces `f` by its body | You need to see inside a definition |
| `intro x h` | Moves `∀ x,` and `→` from the goal into hypotheses | Goal starts with `∀` or `→` |
| `split` / `split at h` | Splits an `if` or `match` into cases | Branching in the goal or in `h` |
| `cases h` / `rcases h with ⟨a, b⟩` | Takes apart an `∧`, `∃`, `∨` or inductive value | Hypothesis has structure |
| `induction xs with` | Proof by induction | Recursive functions |
| `induction xs generalizing acc` | Induction with a changing argument | Accumulator loops |
| `exact?` | Searches the library for a closing lemma | You suspect the fact already exists |
| `decide` / `rfl` | Proves closed facts by computation | `f 3 = 9` style goals |
| `have h : P := by …` | Proves a stepping stone | Breaking a big proof into parts |
| `mvcgen invariants · ⇓⟨xs, s⟩ => ⌜…⌝ with grind` | Verifies a `do` block with loops | Imperative code (see track-a-build.md) |

## Error messages decoded

| Message | Usually means |
| --- | --- |
| `unsolved goals` | The tactics ran out before the goal was closed; read the goal it prints |
| `omega could not prove the goal` | The goal has non-linear terms or hidden definitions; `unfold`/`simp` first |
| `simp made no progress` | Nothing to rewrite; name the definition: `simp [myFun]` |
| `type mismatch` | You gave a value of one type where another was expected; read both types |
| `unknown identifier` | Typo, missing `open`, or the definition is in another namespace |
| `declaration uses 'sorry'` | Not an error, but the result is not proved |
| `fail to show termination` | Lean cannot see the recursion shrinks; add `termination_by` or restructure |
| `maximum recursion depth` / `deterministic timeout` | Automation looped; give `simp` fewer lemmas or split the goal first |
| `split` failed: could not split an `if` or `match`, and the goal shows `have y := …` | The function body uses `let`; use `simp only [f]` instead of `unfold f`, or just `grind` |
| `Unknown identifier` in a scratch file that imports your library | That module isn't built yet: `lake build <Lib>.Impl`, then re-run |
| `` `if_pos` has been deprecated `` | Lean 4.35 renamed it: use `ite_eq_left`, or let `simp` handle the `if` |

## Two recipes worth knowing early

**Products of two variables.** `omega` and `grind` handle `+`, `-`, constants and
`<`, but not `rate * time` when both are variables. State the product fact you need
with a library lemma; then `omega` treats the product as a single unknown:

```lean
example (r t c : Nat) (h : 0 < r) (ht : 0 < t) : c < c + r * t := by
  have := Nat.mul_pos h ht
  omega
```

Useful lemmas: `Nat.mul_pos`, `Nat.mul_le_mul_left`, `Nat.mul_add`,
`Int.mul_nonneg`, `Int.mul_le_mul_of_nonneg_left`. If the product appears in
several places, `generalize r * t = m at *` before `omega`.

**Clean errors without the editor.** `lake build` prints long trace lines. When
iterating on one file, `lake env lean <Lib>/Proofs.lean` shows just that file's
errors and goals.

## Core Lean versus Mathlib

Core Lean plus `Std` is enough for software verification and builds in seconds.
Mathlib is the large mathematics library: add it only when you need its lemmas,
and run `lake exe cache get` before the first build or you will compile it from
source for an hour.
