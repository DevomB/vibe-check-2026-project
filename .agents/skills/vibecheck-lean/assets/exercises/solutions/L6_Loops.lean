import Std.Tactic.Do
open Std.Do

/-! # Level 6: imperative loops

Real code has `let mut` and `for` loops. `mvcgen` turns a `do` block into
verification conditions; you supply the loop invariant: what is true after
processing a prefix `xs.prefix` of the input. (Lean 4.35 warns that `mvcgen` is
deprecated in favour of `vcgen`; `vcgen` is still experimental, keep `mvcgen`.) -/

def mySum (l : Array Nat) : Nat := Id.run do
  let mut out := 0
  for i in l do
    out := out + i
  return out

-- Worked example
theorem mySum_correct (l : Array Nat) : mySum l = l.sum := by
  generalize h : mySum l = x
  apply Id.of_wp_run_eq h
  mvcgen invariants
  · ⇓⟨xs, out⟩ => ⌜xs.prefix.sum = out⌝
  with grind

def countBig (l : List Nat) (k : Nat) : Nat := Id.run do
  let mut n := 0
  for x in l do
    if x > k then n := n + 1
  return n

-- Exercise 6.1: the count never exceeds the length.
theorem countBig_le (l : List Nat) (k : Nat) : countBig l k ≤ l.length := by
  generalize h : countBig l k = x
  apply Id.of_wp_run_eq h
  mvcgen invariants
  · ⇓⟨xs, n⟩ => ⌜n ≤ xs.prefix.length⌝
  with grind
