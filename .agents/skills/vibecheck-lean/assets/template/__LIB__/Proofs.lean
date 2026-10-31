import __LIB__.Spec

/-!
# Proofs

One theorem per property in `Spec.lean`, stated as `theorem name : Spec.name`.
Helper lemmas are welcome. `sorry`, `admit`, `axiom` and `native_decide` are not.
-/

namespace __LIB__.Proofs
open __LIB__

theorem conserves : Spec.conserves := by
  intro a b amt a' b' h
  unfold transfer at h
  split at h <;> grind

theorem rejectsOverdraft : Spec.rejectsOverdraft := by
  intro a b amt h
  unfold transfer
  grind

end __LIB__.Proofs
