import Engine.Slider

/-!
# What we prove about the slider bot

Two properties, stated here so they can be read on their own. The proofs are in
`BotLegal.lean` (T3) and `BotRisk.lean` (T4).

- **T3, always legal.** Whenever the player to act may act at all, the bot's move is legal.
- **T4, more caution never means more calls.** In one spot, if the bot calls or raises at some
  internal caution, it also calls or raises at every lower caution.

What to review (the definitions these statements depend on):
- From the spec: `Legal`, `State.MayAct`, `State.toCall`, `State.minRaise`.
- Here: `AlwaysLegal`, `RiskMonotone`, `Action.continues`.
- The bot (`Engine/Slider.lean`): `botDecide`, `decideWithCounts`, `viewOf`, `decideView`,
  `riverOpening`, `riverBetOrCheck`, `callPays`, `Counts.atLeast`, `State.raiseBounds`, `State.allIn`,
  `State.potToWin`, `clampTo`. The reason text (`chanceText`, `betVerb`) does not affect the
  move.
- The counts (`countsFor`, `Engine/Equity.lean`) do not matter for either theorem: both hold
  for any counts. T4 only uses that `countsFor` has no Risk input.
-/

/-- A bot is **always legal** when, in every state where the player to act may act at all
(they have chips and are not ahead in the betting), the bot's move is legal by the spec. -/
def AlwaysLegal (bot : State → Action) : Prop :=
  ∀ s, s.MayAct → Legal s (bot s)

/-- A bot's moves at each internal caution setting (the `risk` field), for one fixed spot,
are **Risk-monotone** when: if the bot calls or raises at caution `r₂`, it also calls or raises
at every lower caution `r₁`. So turning caution up can turn a call into a fold, but never a
fold into a call. (The player's Risk runs the other way: `more_risk_never_folds_a_call`.) -/
def RiskMonotone (bot : Nat → Action) : Prop :=
  ∀ r₁ r₂, r₁ ≤ r₂ → (bot r₂).continues → (bot r₁).continues

/-! ## The properties reject bad bots -/

/-- A bot that always checks is not always legal: at the start of a hand the small blind
owes 5 chips, so it may not check. -/
example : ¬ AlwaysLegal fun _ => .check := by
  intro h
  exact absurd (h exStart (by decide)) (by decide)

/-- A bot that always goes all-in plus one chip is not always legal: it bets chips it does
not have. -/
example : ¬ AlwaysLegal fun s => .raiseTo (s.allIn + 1) := by
  intro h
  exact absurd (h exStart (by decide)) (by decide)

/-- A decision table that calls at caution 100 but folds at caution 0 is not Risk-monotone. -/
example : ¬ RiskMonotone fun r => if r = 100 then .call else .fold := by
  intro h
  exact absurd (h 0 100 (by decide) (by decide)) (by decide)
