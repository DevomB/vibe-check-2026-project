/-! # Level 1: programs and facts that compute

Lean is a programming language first. `def` defines, `#eval` runs.
A closed fact like `double 3 = 6` is proved by computation: `rfl` or `decide`. -/

def double (n : Nat) : Nat := n + n

#eval double 21

-- Worked example
example : double 3 = 6 := rfl

-- Exercise 1.1: define `square` and prove `square 7 = 49`.
def square (n : Nat) : Nat := sorry
example : square 7 = 49 := by sorry

-- Exercise 1.2: `isEven` returns true for even numbers. Prove it on 10 and 7.
def isEven (n : Nat) : Bool := n % 2 == 0
example : isEven 10 = true := by sorry
example : isEven 7 = false := by sorry

-- Exercise 1.3: `maxOf` returns the larger of two numbers. Prove `maxOf 3 9 = 9`.
def maxOf (a b : Nat) : Nat := if a ≤ b then b else a
example : maxOf 3 9 = 9 := by sorry
