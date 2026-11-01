import Engine.Proofs.ReviewSpec

/-!
# Spec: the bluff catcher on the river (game theory, part 1)

The bot bets on the river. Its bet is either a value hand (stronger than yours) or a bluff
(weaker than yours). Your hand is a **bluff catcher**: it beats every bluff and loses to
every value hand. Call or fold?

- Calling wins the pot when the bot is bluffing and loses the call when it is not.
- Folding wins and loses nothing more.

If the bot bluffs just often enough, calling and folding are worth the same, and you cannot
gain by choosing either. For a pot-sized bet, "just often enough" is one bet in three. This
is the textbook break-even bluff share. It is half of what game theory calls an
equilibrium: neither player can gain by changing their own play alone.

The theorems are in `Engine/Proofs/BluffCatcher.lean`. They use the review's own chip
arithmetic (`choiceTotal`, `Engine/Proofs/ReviewSpec.lean`), so they are about the code the
app runs, not a separate model.

Definitions a reader must trust: `CatchesBluffs`, `RiverSpot.valueHands`,
`RiverSpot.bluffHands`, plus `choiceTotal`, `callResult` and `riverBettingSet`.
-/

/-- A hand with showdown score `mine` is a **bluff catcher** against `value` and `bluffs`:
it loses to every value hand and beats every bluff. No hand ties. -/
def CatchesBluffs (mine : List Nat) (value bluffs : List RankedHand) : Prop :=
  (∀ h ∈ value, mine < h.score) ∧ (∀ h ∈ bluffs, h.score < mine)

instance (mine : List Nat) (value bluffs : List RankedHand) :
    Decidable (CatchesBluffs mine value bluffs) := by
  unfold CatchesBluffs; infer_instance

/-- The value hands the bot can hold in a review spot: its river value hands, minus the
hands that use one of your cards. -/
def RiverSpot.valueHands (spot : RiverSpot) : List RankedHand :=
  (riverBettingSet spot.bluffPct spot.board).value.filter fun h => !spot.blocks h

/-- The bluffs the bot can hold in a review spot: its river bluffs, minus the hands that use
one of your cards. -/
def RiverSpot.bluffHands (spot : RiverSpot) : List RankedHand :=
  (riverBettingSet spot.bluffPct spot.board).bluffs.filter fun h => !spot.blocks h

/-! ## Examples

Two made-up bot hands: a value hand scoring `[5]` and a bluff scoring `[1]`. -/

/-- A value hand for the examples. -/
def exValueHand : RankedHand := ⟨(card 14 .spades, card 14 .hearts), [5]⟩
/-- A bluff for the examples. -/
def exBluffHand : RankedHand := ⟨(card 2 .clubs, card 3 .diamonds), [1]⟩

-- A hand scoring `[3]` sits between them, so it catches bluffs.
example : CatchesBluffs [3] [exValueHand] [exBluffHand] := by decide
-- A hand that beats the value hand is not a bluff catcher, and neither is one that loses to the bluff.
example : ¬ CatchesBluffs [7] [exValueHand] [exBluffHand] := by decide
example : ¬ CatchesBluffs [0] [exValueHand] [exBluffHand] := by decide
-- A tie with a bluff is not "beats every bluff".
example : ¬ CatchesBluffs [1] [exValueHand] [exBluffHand] := by decide
