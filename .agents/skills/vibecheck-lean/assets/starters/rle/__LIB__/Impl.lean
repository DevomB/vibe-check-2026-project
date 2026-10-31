/-! # Implementation: run-length encoding, e.g. "aaab" ↦ [(a,3), (b,1)]. -/

namespace __LIB__

def encode : List Char → List (Char × Nat)
  | [] => []
  | c :: cs =>
    match encode cs with
    | (d, n) :: rest => if c = d then (d, n + 1) :: rest else (c, 1) :: (d, n) :: rest
    | [] => [(c, 1)]

def decode (l : List (Char × Nat)) : List Char := l.flatMap (fun p => List.replicate p.2 p.1)

def encodeString (s : String) : List (Char × Nat) := encode s.toList
def decodeString (l : List (Char × Nat)) : String := String.ofList (decode l)

end __LIB__
