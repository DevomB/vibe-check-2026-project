import Engine.Hand

/-!
# Spec: how many shared cards each street has

Part of what a reader must trust for `board_matches_street` (`Engine/Proofs/Board.lean`).
-/

/-- The number of shared cards on the table during each betting round: none before the
flop, three on the flop, four on the turn and five on the river. -/
def Street.boardCards : Street → Nat
  | .preflop => 0
  | .flop => 3
  | .turn => 4
  | .river => 5

example : Street.boardCards .flop = 3 := rfl
example : Street.boardCards .river = 5 := rfl
