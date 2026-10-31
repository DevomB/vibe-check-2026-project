import __LIB__

open __LIB__

def main (args : List String) : IO Unit := do
  let s := args.headD "aaabccdddd"
  let enc := encodeString s
  IO.println s!"encoded: {enc}"
  IO.println s!"decoded: {decodeString enc}"
