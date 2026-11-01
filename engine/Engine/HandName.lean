import Poker

/-!
# Engine: naming a player's best hand, for display

The screen shows "Two Pair" and highlights the five cards that make it. Both come from the
spec's `handScore`, so the browser never ranks hands itself.
-/

/-- The name of a kind of hand, from its strength (the first number of its score). -/
def handTypeName : Nat → String
  | 0 => "High Card" | 1 => "Pair" | 2 => "Two Pair" | 3 => "Three of a Kind"
  | 4 => "Straight" | 5 => "Flush" | 6 => "Full House" | 7 => "Four of a Kind"
  | _ => "Straight Flush"

/-- The five cards making the best hand among `cards` (five to seven of them). The first
such five if several score the same. Empty if there are fewer than five cards. -/
def bestFive (cards : List Card) : List Card :=
  match choose 5 cards with
  | [] => []
  | first :: rest => rest.foldl (fun best c => if handScore best < handScore c then c else best) first

/-- The name of the best hand among `cards`, or `none` with fewer than five cards. -/
def handName (cards : List Card) : Option String :=
  match bestFive cards with
  | [] => none
  | five => some (handTypeName ((handScore five).headD 0))

#guard handName (royalFlush ++ [card 2 .clubs, card 3 .hearts]) == some "Straight Flush"
#guard handName (fullHouse ++ [card 2 .clubs]) == some "Full House"
#guard handName [card 2 .clubs, card 3 .hearts] == none
-- Two pair plus a lone ace: the best five keep both pairs and the ace.
#guard bestFive [card 9 .clubs, card 9 .hearts, card 4 .spades, card 4 .clubs, card 2 .hearts,
    card 14 .diamonds, card 3 .clubs] ==
  [card 9 .clubs, card 9 .hearts, card 4 .spades, card 4 .clubs, card 14 .diamonds]
