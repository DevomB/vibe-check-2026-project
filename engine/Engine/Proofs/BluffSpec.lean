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
