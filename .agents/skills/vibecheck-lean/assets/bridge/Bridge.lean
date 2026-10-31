import Std.Data.HashMap

/-! # Lean for Python and TypeScript developers

Every snippet compiles. Run with `lean Bridge.lean` and read the `#eval` output. -/

-- Functions: types after the colon, no `return` needed
def add (a b : Int) : Int := a + b                  -- py: def add(a, b): return a + b
#eval add 2 3

-- Local variables and string interpolation
def greet (name : String) : String :=
  let greeting := "hello"                           -- ts: const greeting = "hello"
  s!"{greeting}, {name}!"                           -- ts: `${greeting}, ${name}!`
#eval greet "lean"

-- if is an expression
def sign (x : Int) : String := if x < 0 then "neg" else if x == 0 then "zero" else "pos"

-- Lists and the usual higher-order functions
#eval [1, 2, 3].map (· * 2)                         -- py: [x * 2 for x in xs]
#eval [1, 2, 3, 4].filter (· % 2 == 0)
#eval [1, 2, 3].foldl (· + ·) 0                     -- py: functools.reduce
#eval (List.range 5).sum

-- Records: structure (py dataclass / ts interface)
structure User where
  name : String
  age : Nat
  deriving Repr

def alice : User := { name := "alice", age := 30 }
#eval { alice with age := 31 }                      -- ts: { ...alice, age: 31 }

-- Enums and tagged unions: inductive + match (ts discriminated union)
inductive Shape where
  | circle (r : Nat)
  | rect (w h : Nat)
  deriving Repr

def area : Shape → Nat
  | .circle r => 3 * r * r
  | .rect w h => w * h
#eval area (.rect 2 5)

-- None / null: Option
def find? (xs : List Nat) (p : Nat → Bool) : Option Nat := xs.find? p
#eval find? [1, 5, 8] (· > 4)                        -- some 5
#eval (find? [1, 2] (· > 4)).getD 0                 -- py: x if x is not None else 0

-- Exceptions: Except
def parseAge (s : String) : Except String Nat :=
  match s.toNat? with
  | some n => if n < 150 then .ok n else .error s!"implausible age {n}"
  | none => .error s!"not a number: {s}"
#eval parseAge "42"
#eval parseAge "abc"

-- Mutable variables and loops live inside `do`
def countdown (n : Nat) : List Nat := Id.run do
  let mut out := []
  for i in [0:n] do                                 -- py: for i in range(n)
    out := (n - i) :: out
  return out.reverse
#eval countdown 3

-- Dictionaries: Std.HashMap
open Std in
def wordCounts (ws : List String) : List (String × Nat) :=
  let m := ws.foldl (fun (m : HashMap String Nat) w => m.insert w (m.getD w 0 + 1)) {}
  m.toList
#eval wordCounts ["a", "b", "a"]

-- Interfaces: type classes
class Describe (α : Type) where
  describe : α → String
instance : Describe User where
  describe u := s!"{u.name} ({u.age})"
#eval Describe.describe alice
