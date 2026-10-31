import __LIB__.Spec

/-! # Proofs: one theorem per property in Spec.lean. Replace each `sorry`. -/

namespace __LIB__.Proofs
open __LIB__

theorem undoAfterEdit : Spec.undoAfterEdit := by
  sorry

theorem redoAfterUndo : Spec.redoAfterUndo := by
  sorry

theorem undoAfterRedo : Spec.undoAfterRedo := by
  sorry

theorem editClearsRedo : Spec.editClearsRedo := by
  sorry

end __LIB__.Proofs
