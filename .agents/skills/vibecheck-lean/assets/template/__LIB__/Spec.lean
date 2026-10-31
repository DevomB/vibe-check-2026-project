import __LIB__.Impl

/-!
# Specification

What the code must do. Humans own this file: an agent must not edit it.

Each property is a `def … : Prop` inside the `Spec` namespace, with a doc
comment that says the property in one English sentence. The audit script
(`audit.py`) finds every property here, finds the theorem that proves it, and
prints the English sentence next to the result for judges to read.
-/

namespace __LIB__.Spec
open __LIB__

/-- A transfer never creates or destroys money. -/
def conserves : Prop :=
  ∀ a b amt a' b', transfer a b amt = some (a', b') → a' + b' = a + b

/-- A transfer larger than the sender's balance is refused. -/
def rejectsOverdraft : Prop :=
  ∀ a b amt, a < amt → transfer a b amt = none

end __LIB__.Spec
