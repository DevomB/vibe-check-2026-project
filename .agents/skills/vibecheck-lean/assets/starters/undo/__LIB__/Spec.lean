import __LIB__.Impl

/-! # Specification: what undo and redo promise. Humans own this file. -/

namespace __LIB__.Spec
open __LIB__

/-- Headline. Undo right after an edit restores exactly the previous document. -/
def undoAfterEdit : Prop := ∀ (e : Editor) (d : String), ((e.edit d).undo).doc = e.doc

/-- Redo cancels an undo completely, whenever there was something to undo. -/
def redoAfterUndo : Prop := ∀ e : Editor, e.undoStack ≠ [] → e.undo.redo = e

/-- Undo cancels a redo completely, whenever there was something to redo. -/
def undoAfterRedo : Prop := ∀ e : Editor, e.redoStack ≠ [] → e.redo.undo = e

/-- A new edit clears the redo history. -/
def editClearsRedo : Prop := ∀ (e : Editor) (d : String), (e.edit d).redoStack = []

end __LIB__.Spec
