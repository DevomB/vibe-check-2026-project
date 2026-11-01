import Engine.Review

/-!
# What the review must do (the spec for T5 and T8)

MVP §6: the review grades the human's call or fold against the bot's opening river bet. It
treats every hand the bot can hold (`RiverSpot.botHands`) as equally likely, and compares the
chips each choice wins on average, from the decision on.

The definitions here say what "the chips each choice wins" means, in the simplest way: one
bot hand at a time, then added up. The theorems in `Engine/Proofs/Review.lean` show that the
review's grade agrees with them. These definitions are part of what a reader must trust, so
they are kept short.
-/

/-- What calling wins against one bot hand, in half-chips (so that a split pot is a whole
number). The human's showdown score is `mine`; calling pays `cost` chips to win `prize` chips.
- The bot's hand scores higher: the human loses the call, `2 * cost` half-chips.
- The human's hand scores higher: the human wins the prize, `2 * prize` half-chips.
- Equal scores: the pot of `prize + cost` is split, so the human gets half of it back after
  paying `cost`, a gain of `prize - cost` half-chips. -/
def callResult (mine : List Nat) (prize cost : Nat) (bot : RankedHand) : Int :=
  if mine < bot.score then -(2 * (cost : Int))
  else if bot.score < mine then 2 * (prize : Int)
  else (prize : Int) - cost

/-- Calling 50 to win 150 with a lower score than the bot loses 100 half-chips. -/
example : callResult [1] 150 50 ⟨(card 2 .clubs, card 3 .clubs), [5]⟩ = -100 := by decide

/-- What a choice wins in total over all the bot's possible hands `hands`, in half-chips,
from this decision on. Dividing by twice the number of hands gives the average in chips.
Folding wins nothing and loses nothing more: chips already in the pot are gone either way. -/
def choiceTotal (hands : List RankedHand) (mine : List Nat) (prize cost : Nat) :
    RiverChoice → Int
  | .call => (hands.map (callResult mine prize cost)).sum
  | .fold => 0

/-- The same, for a review spot: the bot's possible hands are `spot.botHands`. -/
def RiverSpot.total (spot : RiverSpot) (choice : RiverChoice) : Int :=
  choiceTotal spot.botHands spot.myScore spot.prize spot.cost choice

/-- `a` is at most `b`, for two fractions whose denominators are above 0. -/
def Frac.LE (a b : Frac) : Prop := a.num * b.den ≤ b.num * a.den

/-- Two review inputs show the human the same thing: the same chips (stacks, pot, bets and
whose turn it is), the same board, and the same cards for the player to act, who is the
human. The other player's cards and the undealt deck may differ. -/
def SameForHuman (h₁ h₂ : Hand) : Prop :=
  h₁.chips = h₂.chips ∧ h₁.board = h₂.board ∧
    h₁.hole h₁.chips.toAct = h₂.hole h₂.chips.toAct
