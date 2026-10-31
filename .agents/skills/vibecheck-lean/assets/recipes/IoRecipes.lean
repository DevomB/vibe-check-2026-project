import Lean.Data.Json

/-!
# I/O recipes for the unverified shell around a verified core

Run: `lean --run IoRecipes.lean greet world` (or `json`, `file`, `count`).
In a lake project, put the same code in `Main.lean` and run `lake exe <name> ARGS`.
-/

open Lean

/-- JSON in and out: derive the instances, then `toJson` / `fromJson?`. -/
structure Order where
  item : String
  qty : Nat
  deriving ToJson, FromJson, Repr

def jsonDemo : IO Unit := do
  let o : Order := { item := "tea", qty := 2 }
  IO.println (toJson o).compress                                   -- {"item":"tea","qty":2}
  match Json.parse "{\"item\": \"cake\", \"qty\": 3}" >>= fromJson? (α := Order) with
  | .ok o' => IO.println (repr o')
  | .error e => IO.eprintln s!"bad json: {e}"

/-- Files: whole-file read and write; `lines` splits on newlines. -/
def fileDemo : IO Unit := do
  let path : System.FilePath := "vibecheck-demo.txt"
  IO.FS.writeFile path "one\ntwo\nthree\n"
  let lines ← IO.FS.lines path
  IO.println s!"{lines.size} lines, first = {lines[0]!}"
  IO.FS.removeFile path

/-- State that lives across the whole run: an `IO.Ref`. -/
def countDemo : IO Unit := do
  let counter ← IO.mkRef 0
  for _ in [0:5] do
    counter.modify (· + 1)
  IO.println s!"counted {← counter.get}"

/-- Command-line arguments and exit codes: `main` may take the args and return a code. -/
def main (args : List String) : IO UInt32 := do
  match args with
  | ["greet", name] => IO.println s!"hello, {name}"; return 0
  | ["json"] => jsonDemo; return 0
  | ["file"] => fileDemo; return 0
  | ["count"] => countDemo; return 0
  | _ => IO.eprintln "usage: greet NAME | json | file | count"; return 1
