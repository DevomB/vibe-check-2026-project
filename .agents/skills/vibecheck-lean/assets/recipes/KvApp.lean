import Lean.Data.Json
import Std.Data.HashMap

/-!
# A complete small app: verified core, unverified shell

Run it:  `printf 'put a 1\nget a\ndel a\nget a\n' | lean --run KvApp.lean`

The pattern every Lean app should follow:
1. The core is pure: `step : Store → Cmd → Store × Reply`. All decisions happen here.
2. The spec talks about the core only.
3. The shell (`main`) parses text into `Cmd`, calls `step`, prints the `Reply`. It is
   small enough to read, and it is the only unverified part.
-/

open Std

/-! ## Core -/

abbrev Store := List (String × Int)      -- an association list: easy to reason about

def Store.get? (s : Store) (k : String) : Option Int := (s.find? (·.1 == k)).map (·.2)
def Store.del (s : Store) (k : String) : Store := s.filter (·.1 != k)
def Store.put (s : Store) (k : String) (v : Int) : Store := (k, v) :: s.del k

inductive Cmd where
  | put (k : String) (v : Int)
  | get (k : String)
  | del (k : String)

inductive Reply where
  | ok
  | value (v : Option Int)

def step (s : Store) : Cmd → Store × Reply
  | .put k v => (s.put k v, .ok)
  | .get k => (s, .value (s.get? k))
  | .del k => (s.del k, .ok)

/-! ## Spec and proofs -/

/-- Reading a key right after writing it returns what was written. -/
theorem get_put (s : Store) (k : String) (v : Int) : (s.put k v).get? k = some v := by
  simp [Store.put, Store.get?]

/-- Writing one key never changes what another key reads. -/
theorem get_put_other (s : Store) (k k' : String) (v : Int) (h : k' ≠ k) :
    (s.put k v).get? k' = s.get? k' := by
  have hk : (k == k') = false := by simp; exact fun e => h e.symm
  -- After unfolding, the two searches use different predicates that agree on every entry.
  have hp : (fun a : String × Int => !decide (a.fst = k) && decide (a.fst = k')) =
      (fun a => a.fst == k') := by
    funext a; by_cases h1 : a.fst = k' <;> simp_all
  simp [Store.put, Store.get?, Store.del, hk, List.find?_filter, hp]

/-- A deleted key reads as missing. -/
theorem get_del (s : Store) (k : String) : (s.del k).get? k = none := by
  simp [Store.del, Store.get?, List.find?_filter]

/-! ## Shell -/

def parse (line : String) : Option Cmd :=
  match line.trimAscii.toString.splitOn " " with
  | ["put", k, v] => v.toInt?.map (Cmd.put k)
  | ["get", k] => some (.get k)
  | ["del", k] => some (.del k)
  | _ => none

def render : Reply → String
  | .ok => "ok"
  | .value (some v) => toString v
  | .value none => "(missing)"

def main : IO Unit := do
  let stdin ← IO.getStdin
  let mut store : Store := []
  repeat
    let line ← stdin.getLine
    if line.isEmpty then break
    match parse line with
    | none => IO.eprintln s!"cannot parse: {line.trimAscii}"
    | some cmd =>
      let (s', reply) := step store cmd
      store := s'
      IO.println (render reply)
