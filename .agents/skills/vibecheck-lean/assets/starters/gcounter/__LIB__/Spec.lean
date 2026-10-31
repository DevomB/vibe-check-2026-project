import __LIB__.Impl

/-! # Specification: why replicas can sync in any order. Humans own this file. -/

namespace __LIB__.Spec
open __LIB__

/-- Headline. Replicas that receive the same increments, in any order, end in the same state. -/
def converges : Prop :=
  ∀ (n : Nat) (c : GCounter n) (l₁ l₂ : List (Fin n)), l₁.Perm l₂ → c.applyAll l₁ = c.applyAll l₂

/-- Merging is commutative: it doesn't matter who syncs with whom. -/
def mergeComm : Prop := ∀ (n : Nat) (a b : GCounter n), a.merge b = b.merge a

/-- Merging is associative: it doesn't matter how syncs are grouped. -/
def mergeAssoc : Prop := ∀ (n : Nat) (a b c : GCounter n), (a.merge b).merge c = a.merge (b.merge c)

/-- Merging is idempotent: syncing twice changes nothing. -/
def mergeIdem : Prop := ∀ (n : Nat) (a : GCounter n), a.merge a = a

end __LIB__.Spec
