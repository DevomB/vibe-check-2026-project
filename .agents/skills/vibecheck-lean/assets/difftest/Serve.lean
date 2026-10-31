import Lean.Data.Json
import __LIB__

/-!
# Differential-test server

Reads one JSON request per line on stdin, `{"fn": "transfer", "args": [100, 0, 30]}`,
calls the verified Lean function, and writes one JSON reply per line:
`{"ok": <result>}` or `{"error": "<message>"}`.

Add one `dispatch` case per ported function. Register this file in `lakefile.toml`:

    [[lean_exe]]
    name = "serve"
    root = "Serve"
-/

open Lean __LIB__

def dispatch (fn : String) (args : Array Json) : Except String Json :=
  match fn, args with
  | "transfer", #[a, b, amt] => do
    return toJson (transfer (← fromJson? a) (← fromJson? b) (← fromJson? amt))
  | _, _ => throw s!"no dispatch case for {fn} with {args.size} arguments"

def handle (line : String) : Json :=
  let reply := do
    let j ← Json.parse line
    let fn ← j.getObjValAs? String "fn"
    let args ← j.getObjValAs? (Array Json) "args"
    dispatch fn args
  match reply with
  | .ok v => Json.mkObj [("ok", v)]
  | .error e => Json.mkObj [("error", toJson e)]

def main : IO Unit := do
  let stdin ← IO.getStdin
  let stdout ← IO.getStdout
  repeat
    let line ← stdin.getLine
    if line.isEmpty then break
    stdout.putStrLn (handle line).compress
    stdout.flush
