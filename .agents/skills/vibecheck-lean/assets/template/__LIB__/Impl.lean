/-!
# Implementation

The code that runs. Agents may edit this file freely: the proofs in
`Proofs.lean` will stop compiling if a change breaks a property in `Spec.lean`.

The example below is a starting point. Replace it with your own code.
-/

namespace __LIB__

/-- Move `amt` from balance `a` to balance `b`, or refuse if `a` is too small. -/
def transfer (a b amt : Nat) : Option (Nat × Nat) :=
  if amt ≤ a then some (a - amt, b + amt) else none

end __LIB__
