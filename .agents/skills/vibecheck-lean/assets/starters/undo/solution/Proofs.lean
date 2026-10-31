import __LIB__.Spec

namespace __LIB__.Proofs
open __LIB__

theorem undoAfterEdit : Spec.undoAfterEdit := by
  intro e d
  simp [Editor.edit, Editor.undo]

theorem redoAfterUndo : Spec.redoAfterUndo := by
  intro e h
  rcases e with ⟨doc, u, r⟩
  cases u with
  | nil => contradiction
  | cons p rest => simp [Editor.undo, Editor.redo]

theorem undoAfterRedo : Spec.undoAfterRedo := by
  intro e h
  rcases e with ⟨doc, u, r⟩
  cases r with
  | nil => contradiction
  | cons p rest => simp [Editor.undo, Editor.redo]

theorem editClearsRedo : Spec.editClearsRedo := by
  intro e d
  rfl

end __LIB__.Proofs
