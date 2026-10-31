/-! # Level 7: make illegal states unrepresentable

Put the invariant inside the type. A `Counter` carries a proof that its value is
within its limit, so every function that builds one must prove the invariant,
and no caller can ever see a broken counter. -/

structure Counter (limit : Nat) where
  value : Nat
  ok : value ≤ limit

def Counter.zero (limit : Nat) : Counter limit := ⟨0, Nat.zero_le _⟩

-- Worked example: incrementing saturates at the limit.
def Counter.incr (c : Counter limit) : Counter limit :=
  if h : c.value < limit then ⟨c.value + 1, by omega⟩ else c

-- Exercise 7.1: decrementing never goes below zero (Nat subtraction floors at 0).
def Counter.decr (c : Counter limit) : Counter limit :=
  ⟨c.value - 1, by sorry⟩

-- Exercise 7.2: `incr` grows the value by at most one.
theorem Counter.incr_le (c : Counter limit) : (c.incr).value ≤ c.value + 1 := by
  sorry

-- Exercise 7.3: a bounded queue whose length never exceeds its capacity.
structure BQueue (cap : Nat) where
  items : List Nat
  ok : items.length ≤ cap

def BQueue.push (q : BQueue cap) (x : Nat) : Option (BQueue cap) :=
  if h : q.items.length < cap then some ⟨q.items ++ [x], by sorry⟩ else none
