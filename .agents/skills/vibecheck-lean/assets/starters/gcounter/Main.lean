import __LIB__

open __LIB__

def main : IO Unit := do
  let ops : List (Fin 3) := [0, 1, 1, 2, 0]
  let a := (GCounter.zero : GCounter 3).applyAll ops
  let b := (GCounter.zero : GCounter 3).applyAll ops.reverse
  IO.println s!"replica a value {a.value}, replica b value {b.value}"
  IO.println s!"merged value {(a.merge b).value}"
