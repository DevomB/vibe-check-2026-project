import Engine.Slider

/-!
# What the Risk slider means (the spec)

MVP section 3: Risk is how heavily the bot weighs a lost chip when it decides whether to
call. A gain of g chips counts as g. A loss of g chips counts as (1 + Risk/50) times g: at
Risk 0 a lost chip counts once, at Risk 50 twice, at Risk 100 three times.

These definitions are what the Risk theorems in `Engine/Proofs/RiskUtility.lean` mean, so
they are part of what a reader must trust. They are kept short.
-/

/-- How much a gain of `g` chips counts at a Risk setting, times 50 so that every number
is whole. A gain counts as it is; a loss counts (50 + Risk) / 50 times as much.
Example: at Risk 50, a loss of 10 counts as `100 * -10`, twice a gain of 10 (`50 * 10`). -/
def riskWeight (risk : Nat) (g : Int) : Int :=
  if 0 ≤ g then 50 * g else (50 + risk) * g

example : riskWeight 50 (-10) = -1000 := by decide
example : riskWeight 50 10 = 500 := by decide

/-- A gamble: its possible outcomes, each with the number of ways it can happen and the
chips gained (a negative number is a loss). -/
abbrev Gamble := List (Nat × Int)

/-- The weighted total of a gamble: each outcome's weight, counted as many times as the
outcome can happen. Dividing by the number of ways gives the weighted average; we only
compare it with 0, so we do not divide. -/
def Gamble.value (risk : Nat) (g : Gamble) : Int :=
  (g.map fun o => (o.1 : Int) * riskWeight risk o.2).sum

/-- At this Risk, the gamble is at least as good as walking away with nothing. -/
def Gamble.Takes (risk : Nat) (g : Gamble) : Prop :=
  0 ≤ g.value risk

instance (risk : Nat) (g : Gamble) : Decidable (g.Takes risk) :=
  inferInstanceAs (Decidable (0 ≤ _))

/-- A call as a gamble, in half-chips so that a split pot is a whole number. Calling
`toCall` to win `pot`: a win gains `pot`, a loss loses `toCall`, and a tie gives back half
of the final pot, a gain of `(pot - toCall) / 2`. -/
def callGamble (c : Counts) (pot toCall : Nat) : Gamble :=
  [(c.win, 2 * (pot : Int)), (c.tie, (pot : Int) - toCall), (c.loss, -(2 * (toCall : Int)))]

