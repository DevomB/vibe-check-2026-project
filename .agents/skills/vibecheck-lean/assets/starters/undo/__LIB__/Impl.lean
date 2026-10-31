/-! # Implementation: a text buffer with undo and redo. -/

namespace __LIB__

structure Editor where
  doc : String
  undoStack : List String
  redoStack : List String
  deriving Repr

def Editor.new (s : String) : Editor := ⟨s, [], []⟩

/-- Replace the document; the old one goes on the undo stack and redo history is dropped. -/
def Editor.edit (e : Editor) (d : String) : Editor := ⟨d, e.doc :: e.undoStack, []⟩

def Editor.undo (e : Editor) : Editor :=
  match e.undoStack with
  | [] => e
  | p :: rest => ⟨p, rest, e.doc :: e.redoStack⟩

def Editor.redo (e : Editor) : Editor :=
  match e.redoStack with
  | [] => e
  | n :: rest => ⟨n, e.doc :: e.undoStack, rest⟩

end __LIB__
