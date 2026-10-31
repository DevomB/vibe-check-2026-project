/-! # Level 4: recursion and induction

A recursive function gets an inductive proof: prove the empty case, then show
that if it holds for `xs` it holds for `x :: xs`. `simp [f]` unfolds a
recursive `f` one step; `ih` is the induction hypothesis. -/

def len : List α → Nat
  | [] => 0
  | _ :: xs => 1 + len xs

-- Worked example
theorem len_append (xs ys : List α) : len (xs ++ ys) = len xs + len ys := by
  induction xs with
  | nil => simp [len]
  | cons x xs ih => simp [len, ih]; omega

def rev : List α → List α
  | [] => []
  | x :: xs => rev xs ++ [x]

-- Exercise 4.1
theorem len_rev (xs : List α) : len (rev xs) = len xs := by
  induction xs with
  | nil => simp [rev]
  | cons x xs ih => simp [rev, len_append, ih, len]; omega

def sumList : List Nat → Nat
  | [] => 0
  | x :: xs => x + sumList xs

-- Exercise 4.2
theorem sumList_append (xs ys : List Nat) :
    sumList (xs ++ ys) = sumList xs + sumList ys := by
  induction xs with
  | nil => simp [sumList]
  | cons x xs ih => simp [sumList, ih]; omega
