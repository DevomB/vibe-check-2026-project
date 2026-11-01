import Engine.Proofs.BluffCatcherSpec

/-!
# Spec: the bettor's side of the one-street river game (game theory, part 2)

`Engine/Proofs/BluffCatcherSpec.lean` gives the caller's side: a bluff-catcher (`CatchesBluffs`)
facing a polarised range, and what calling is worth (`choiceTotal`). This file adds the one
definition the bettor's side needs. The theorems about it, and about the bot's Risk 0 and
Risk 100 sets, are in `Engine/Proofs/RiverGame.lean`.

`bluffGain` is the textbook model's bettor side (research note A03, with the simplification A03
notes is not exactly von Neumann's model: a bluff loses at showdown, so checking it wins
nothing). No engine function computes it, because the engine never models how often the human
calls. It is part of what a reader must trust.
-/

/-- What one bluff gains over checking, in chips, when the caller holds `hands` bluff-catchers
and calls with `calls` of them: each fold wins the `pot`, each call loses the `bet`. `pot` is
the pot before the bet, so the caller's prize is `pot + bet`. -/
def bluffGain (hands calls pot bet : Nat) : Int :=
  ((hands : Int) - calls) * pot - (calls : Int) * bet

/-! ## Examples -/

/-- Two value hands (scores 9 and 8) and one bluff (score 1), against a caller whose score is 5:
one bluff in three bets. -/
def exValueHands : List RankedHand :=
  [⟨(card 2 .clubs, card 3 .clubs), [9]⟩, ⟨(card 2 .diamonds, card 3 .diamonds), [8]⟩]
def exBluffHands : List RankedHand := [⟨(card 4 .clubs, card 6 .clubs), [1]⟩]

example : CatchesBluffs [5] exValueHands exBluffHands := by decide
example : CatchesBluffs [5] exValueHands (exBluffHands ++ exBluffHands) := by decide

-- Four bluff-catchers, the caller calls with two of them: a pot-sized bluff gains nothing.
#guard bluffGain 4 2 100 100 == 0
-- Calling with only one of four: the bluff wins the pot three times and loses the bet once.
#guard bluffGain 4 1 100 100 == 200
-- Calling with three of four: the bluff loses.
#guard bluffGain 4 3 100 100 == -200
