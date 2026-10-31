/-! # Level 3: code with branches

`if` and `match` split the proof into cases. `split` makes the cases explicit;
`grind` usually handles the cases and the arithmetic in one go. -/

def clamp (lo hi x : Int) : Int :=
  if x < lo then lo else if x > hi then hi else x

-- Worked example
theorem clamp_ge (lo hi x : Int) (h : lo ≤ hi) : lo ≤ clamp lo hi x := by
  unfold clamp
  split <;> (try split) <;> omega

-- Exercise 3.1
theorem clamp_le (lo hi x : Int) (h : lo ≤ hi) : clamp lo hi x ≤ hi := by
  sorry

-- Exercise 3.2: clamping twice is the same as clamping once.
theorem clamp_idem (lo hi x : Int) (h : lo ≤ hi) :
    clamp lo hi (clamp lo hi x) = clamp lo hi x := by
  sorry

-- Exercise 3.3: a rate limiter admits a request only when under budget.
def admit (used limit : Nat) : Option Nat :=
  if used < limit then some (used + 1) else none

theorem admit_within (used limit n : Nat) (h : admit used limit = some n) : n ≤ limit := by
  sorry
