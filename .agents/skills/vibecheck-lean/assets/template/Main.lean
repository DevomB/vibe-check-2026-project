import __LIB__

open __LIB__

/-- The demo: run the verified core. Unverified I/O lives here, and only here. -/
def main : IO Unit := do
  IO.println s!"transfer 100 0 30  = {repr (transfer 100 0 30)}"
  IO.println s!"transfer 100 0 130 = {repr (transfer 100 0 130)}"
