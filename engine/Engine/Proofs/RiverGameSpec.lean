import Engine.Proofs.ReviewSpec

/-!
# The one-street river game (the spec behind "matches the textbook ratio")

The bot's river bluff share comes from a textbook model (von Neumann; research note A03): one
final bet, a bettor whose range is **polarised** (every hand it bets either beats the caller or
loses to it), and a caller who holds a **bluff-catcher** (a hand that beats every bluff and
loses to every value hand) and can only call or fold. Chips are counted at face value.

The definitions here say what that model means for our review, in the simplest way. They
reuse the review's own `callResult` and `choiceTotal` (`Engine/Proofs/ReviewSpec.lean`), so
"what a call wins" is the same number the review grades with. The theorems about them are in
`Engine/Proofs/RiverGame.lean`. These definitions are part of what a reader must trust.
-/

/-- The caller holds a bluff-catcher against a polarised range: every value hand scores above
the caller's score `mine`, and every bluff scores below it. This ties the engine's labels to
the outcome: on a real board it holds only for a caller whose score sits above all of the
bot's bluffs and below all of its value hands, and the theorems about it apply to exactly
those spots. The human's real hand may not satisfy it. -/
def Polarized (mine : List Nat) (value bluffs : List RankedHand) : Prop :=
  (∀ h ∈ value, mine < h.score) ∧ (∀ h ∈ bluffs, h.score < mine)

instance (mine : List Nat) (value bluffs : List RankedHand) :
    Decidable (Polarized mine value bluffs) := by
  unfold Polarized; infer_instance

/-- What calling wins in total against the range `value ++ bluffs`, in half-chips: the
review's own `choiceTotal`. Calling pays `cost` to win `prize`. Divide by twice the number of
hands for the average in chips. -/
def callTotal (value bluffs : List RankedHand) (mine : List Nat) (prize cost : Nat) : Int :=
  choiceTotal (value ++ bluffs) mine prize cost .call

/-- What one bluff gains over checking, in chips, when the caller holds `hands` bluff-catchers
and calls with `calls` of them: each fold wins the `pot`, each call loses the `bet`. (A bluff
loses at showdown, so checking it wins nothing: the simplified bettor side that A03 notes is
not exactly von Neumann's model.) `pot` is the pot before the bet, so the
caller's prize in `callTotal` is `pot + bet`. This is the model's bettor side: no engine
function computes it, because the engine never models how often the human calls. -/
def bluffGain (hands calls pot bet : Nat) : Int :=
  ((hands : Int) - calls) * pot - (calls : Int) * bet

/-! ## Examples -/

/-- Two value hands (scores 9 and 8) and one bluff (score 1), against a caller whose score is 5. -/
def exValueHands : List RankedHand :=
  [⟨(card 2 .clubs, card 3 .clubs), [9]⟩, ⟨(card 2 .diamonds, card 3 .diamonds), [8]⟩]
def exBluffHands : List RankedHand := [⟨(card 4 .clubs, card 6 .clubs), [1]⟩]

example : Polarized [5] exValueHands exBluffHands := by decide
-- Not a bluff-catcher: a score of 10 beats the value hands too.
example : ¬ Polarized [10] exValueHands exBluffHands := by decide

-- Calling 100 to win 200: the bluff pays 400 half-chips, each value hand costs 200. One bluff
-- in three bets is exactly break-even for a pot-sized bet.
#guard callTotal exValueHands exBluffHands [5] 200 100 == 0
-- With two bluffs the call gains; with none it loses the two calls.
#guard callTotal exValueHands (exBluffHands ++ exBluffHands) [5] 200 100 == 400
#guard callTotal exValueHands [] [5] 200 100 == -400

-- Four bluff-catchers, the caller calls with two of them: a pot-sized bluff gains nothing.
#guard bluffGain 4 2 100 100 == 0
-- Calling with only one of four: the bluff wins the pot three times and loses the bet once.
#guard bluffGain 4 1 100 100 == 200
