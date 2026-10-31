import __LIB__

open __LIB__

def main : IO Unit := do
  let e := (Editor.new "hello").edit "hello world" |>.edit "hello, world!"
  IO.println s!"now:        {e.doc}"
  IO.println s!"undo:       {e.undo.doc}"
  IO.println s!"undo, undo: {e.undo.undo.doc}"
  IO.println s!"undo, redo: {e.undo.redo.doc}"
