/-! # Implementation: a grow-only counter CRDT replicated across `n` nodes. -/

namespace __LIB__

/-- Each replica's view: how many increments it has seen from each node. -/
def GCounter (n : Nat) := Fin n → Nat

def GCounter.zero : GCounter n := fun _ => 0

/-- Node `i` counts one more event. -/
def GCounter.incr (c : GCounter n) (i : Fin n) : GCounter n :=
  fun j => if j = i then c j + 1 else c j

/-- Combine two replicas' views: take the larger count per node. -/
def GCounter.merge (a b : GCounter n) : GCounter n := fun i => max (a i) (b i)

/-- Apply a sequence of increments, in the order they arrived. -/
def GCounter.applyAll (c : GCounter n) (ops : List (Fin n)) : GCounter n := ops.foldl GCounter.incr c

/-- The counter's value: the sum over all nodes. -/
def GCounter.value (c : GCounter n) : Nat := ((List.finRange n).map c).sum

end __LIB__
