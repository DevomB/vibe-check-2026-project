import Engine.Equity

/-!
# T6 spec: what the exact counts must count

The definitions the T6 theorems (`Engine/Proofs/EquityExact.lean`) are stated with. They
are kept here, apart from the proofs, so they are easy to review and so the Comparator
challenge (`Checks/Challenge.lean`) can state the same theorems.
-/

/-- The opponent can hold the cards `a` and `b`: they are two different cards, and neither is
in the bot's hand or on the board. -/
def OpponentCanHold (hole board : List Card) (a b : Card) : Prop :=
  a ≠ b ∧ a ∉ hole ++ board ∧ b ∉ hole ++ board

/-- On the turn, the river can be `r` while the opponent holds `a` and `b`: three different
cards, none of them in the bot's hand or on the board. -/
def TurnOutcomePossible (hole board : List Card) (r a b : Card) : Prop :=
  OpponentCanHold hole board a b ∧ r ≠ a ∧ r ≠ b ∧ r ∉ hole ++ board

instance (hole board : List Card) (a b : Card) : Decidable (OpponentCanHold hole board a b) := by
  unfold OpponentCanHold; infer_instance

instance (hole board : List Card) (r a b : Card) :
    Decidable (TurnOutcomePossible hole board r a b) := by
  unfold TurnOutcomePossible; infer_instance

/-- How many times the two-card hand `a`, `b` is in a list of hands, in either order. -/
def timesListed (hands : List (List Card)) (a b : Card) : Nat :=
  hands.count [a, b] + hands.count [b, a]

/-- How many times the turn outcome "river `r`, opponent holds `a` and `b`" is in a list,
with the opponent's cards in either order. -/
def timesListedTurn (outcomes : List (Card × List Card)) (r a b : Card) : Nat :=
  outcomes.count (r, [a, b]) + outcomes.count (r, [b, a])

/-- Count how many results are a win for the bot (player 0), a tie, and a loss. -/
def countResults (results : List Outcome) : Counts :=
  ⟨results.count .player0, results.count .tie, results.count .player1⟩
