/-! # Level 5: fast code equals simple code

The most useful pattern in verified software: write a slow, obviously correct
reference, write the fast version, prove they agree. Accumulator functions need
a *generalized* lemma first: state it for every starting accumulator. -/

def sumRef : List Nat → Nat
  | [] => 0
  | x :: xs => x + sumRef xs

def sumAcc : Nat → List Nat → Nat
  | acc, [] => acc
  | acc, x :: xs => sumAcc (acc + x) xs

def sumFast (xs : List Nat) : Nat := sumAcc 0 xs

-- Exercise 5.1: the generalized lemma. Induct with `acc` free (`generalizing acc`).
theorem sumAcc_eq (acc : Nat) (xs : List Nat) : sumAcc acc xs = acc + sumRef xs := by
  sorry

-- Exercise 5.2: the headline theorem.
theorem sumFast_correct (xs : List Nat) : sumFast xs = sumRef xs := by
  sorry

def countRef (p : Nat → Bool) : List Nat → Nat
  | [] => 0
  | x :: xs => (if p x then 1 else 0) + countRef p xs

def countAcc (p : Nat → Bool) : Nat → List Nat → Nat
  | acc, [] => acc
  | acc, x :: xs => countAcc p (if p x then acc + 1 else acc) xs

-- Exercise 5.3
theorem countAcc_eq (p : Nat → Bool) (acc : Nat) (xs : List Nat) :
    countAcc p acc xs = acc + countRef p xs := by
  sorry
