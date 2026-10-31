/-! # Level 2: facts about all inputs

`rfl` only works when Lean can compute both sides. For a statement about every
`n`, unfold the definition and let `omega` (linear arithmetic) finish. -/

def double (n : Nat) : Nat := n + n

-- Worked example
theorem double_ge (n : Nat) : n ≤ double n := by
  unfold double
  omega

-- Exercise 2.1
theorem double_even (n : Nat) : double n % 2 = 0 := by
  unfold double
  omega

-- Exercise 2.2: a discount never makes a price negative or larger.
def discount (price pct : Nat) : Nat := price - price * pct / 100

theorem discount_le (price pct : Nat) : discount price pct ≤ price := by
  unfold discount
  omega

-- Exercise 2.3: `double` is injective.
theorem double_inj (a b : Nat) (h : double a = double b) : a = b := by
  unfold double at h
  omega
