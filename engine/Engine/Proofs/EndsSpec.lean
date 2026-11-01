import Engine.Hand

/-!
# T9 spec: a run of accepted moves

`RunsWith st h as h'` says: starting from hand `h`, the moves `as` are made one after the
other, the engine `st` accepts each one, and the hand is `h'` at the end. `RunsTo` is this
for the real engine, `step`. T9 (`every_hand_ends`, `Engine/Proofs/Ends.lean`) says every
such run from a reachable game has at most 200 moves (`botFuel` in `Engine/Session.lean`).
-/

/-- `h` reaches `h'` by the moves `as`, each one accepted by the engine `st`. -/
def RunsWith (st : Hand → Action → Except String Hand) : Hand → List Action → Hand → Prop
  | h, [], h' => h' = h
  | h, a :: as, h' => ∃ h₁, st h a = .ok h₁ ∧ RunsWith st h₁ as h'

/-- `h` reaches `h'` by the moves `as`, each one accepted by `step`. -/
def RunsTo : Hand → List Action → Hand → Prop := RunsWith step

-- No moves: the hand stays as it is.
example (h : Hand) : RunsTo h [] h := rfl

/-- In `exStart` (blinds posted, player 0 to act), the small blind folds and the hand is
over. -/
def exFoldHand : Hand :=
  { chips := exStart, street := .preflop, button := 0,
    hole := fun p => if p = 0 then [card 14 .spades, card 13 .spades]
      else [card 2 .clubs, card 7 .diamonds],
    board := [], deck := [], acted := fun _ => false, ended := none }

example : RunsTo exFoldHand [.fold] (exFoldHand.payFold 1) := ⟨_, rfl, rfl⟩
