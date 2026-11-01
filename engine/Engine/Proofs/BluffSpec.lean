import Engine.River

/-!
# T7 spec: what "rounded to a whole hand" means

The definition the T7 theorems (`Engine/Proofs/BluffFrequency.lean`) are stated with. It is
kept here, apart from the proofs, so it is easy to review and so the Comparator challenge
(`Checks/Challenge.lean`) can state the same theorems.
-/

/-- `n` is the whole number nearest to the fraction `num / den`, and a half rounds up.
In fractions: `num / den - 1/2 ≤ n < num / den + 1/2`. Here both sides are multiplied by
`2 × den`, so only whole numbers appear. It is never true when `den` is 0. -/
def NearestWhole (n num den : Nat) : Prop :=
  2 * n * den ≤ 2 * num + den ∧ 2 * num + den < 2 * n * den + 2 * den

instance (n num den : Nat) : Decidable (NearestWhole n num den) := by
  unfold NearestWhole; infer_instance

-- 10 / 3 = 3.33... is nearest to 3, and 11 / 3 = 3.67... is nearest to 4.
example : NearestWhole 3 10 3 := by decide
example : NearestWhole 4 11 3 := by decide
example : ¬ NearestWhole 4 10 3 := by decide
example : ¬ NearestWhole 3 11 3 := by decide
-- 7 / 2 = 3.5 is a half: it rounds up to 4, not down to 3.
example : NearestWhole 4 7 2 := by decide
example : ¬ NearestWhole 3 7 2 := by decide
-- Whole fractions round to themselves: 12 / 4 = 3.
example : NearestWhole 3 12 4 := by decide
example : ¬ NearestWhole 2 12 4 := by decide

/-! ## The order of the river ranking (MVP §5)

`rankRiverHands` must list the candidate hands strongest first: by showdown score, and among
equal scores by card IDs, lower first. These definitions say what that order is. The theorem
`rankRiverHands_sorted` (`Engine/Proofs/BluffFrequency.lean`) says the ranking follows it. -/

/-- A card's ID: its place in a new deck (`fullDeck`), rank first, then suit: 2c = 0, 2d = 1,
2h = 2, 2s = 3, 3c = 4, ..., As = 51. -/
def cardId (c : Card) : Nat :=
  4 * c.rank.val + match c.suit with | .clubs => 0 | .diamonds => 1 | .hearts => 2 | .spades => 3

-- The IDs run as MVP §5 says, and each is the card's place in `fullDeck`.
example : cardId (card 2 .clubs) = 0 ∧ cardId (card 2 .diamonds) = 1 ∧
    cardId (card 3 .clubs) = 4 ∧ cardId (card 14 .spades) = 51 := by decide
example : ∀ c ∈ fullDeck, fullDeck.idxOf c = cardId c := by decide

/-- `x` ranks above `y` (comes first in the river ranking): `x` has the higher showdown score,
or the same score and the lower card IDs, comparing the first (lower) cards first, then the
second cards. -/
def RanksAbove (x y : RankedHand) : Prop :=
  y.score < x.score ∨
    (x.score = y.score ∧
      (cardId x.cards.1 < cardId y.cards.1 ∨
        (cardId x.cards.1 = cardId y.cards.1 ∧ cardId x.cards.2 < cardId y.cards.2)))

instance (x y : RankedHand) : Decidable (RanksAbove x y) := by
  unfold RanksAbove; infer_instance

-- A higher score ranks above, whatever the cards. Equal scores go by the first card's ID,
-- then by the second card's.
example : RanksAbove ⟨(card 9 .clubs, card 9 .diamonds), [1, 7]⟩
    ⟨(card 2 .clubs, card 3 .clubs), [0, 1]⟩ := by decide
example : RanksAbove ⟨(card 2 .clubs, card 3 .diamonds), [0, 1]⟩
    ⟨(card 2 .diamonds, card 3 .clubs), [0, 1]⟩ := by decide
example : RanksAbove ⟨(card 2 .clubs, card 3 .clubs), [0, 1]⟩
    ⟨(card 2 .clubs, card 3 .diamonds), [0, 1]⟩ := by decide
-- The other way round is rejected, and so is a lower score with lower IDs.
example : ¬ RanksAbove ⟨(card 2 .clubs, card 3 .diamonds), [0, 1]⟩
    ⟨(card 2 .clubs, card 3 .clubs), [0, 1]⟩ := by decide
example : ¬ RanksAbove ⟨(card 2 .clubs, card 3 .clubs), [0, 1]⟩
    ⟨(card 9 .clubs, card 9 .diamonds), [1, 7]⟩ := by decide
