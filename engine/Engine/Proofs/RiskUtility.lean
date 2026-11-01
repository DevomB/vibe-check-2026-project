import Engine.Proofs.RiskSpec

/-!
# What the Risk slider means, and a proof that the bot follows it

`Engine/Proofs/RiskSpec.lean` writes down what Risk means (`riskWeight`, `Gamble.Takes`,
`callGamble`). This file proves:

1. `callPays_iff_takes`: the bot's call rule `callPays` calls exactly when the call, seen
   as a gamble, has a weighted average of at least 0 (the value of folding).
2. `bot_calls_only_when_worth_it`, `bot_folds_only_when_not_worth_it`: the real bot's
   calls and folds follow that rule.
3. `more_risk_takes_fewer_gambles`: for any gamble at all, not only a call, if a bot
   with more Risk takes it, a bot with less Risk takes it too. This is the order of
   cautiousness from Pratt (1964), for this family of weights (research note B01).
4. `risk_zero_is_average_chips`: at Risk 0 the bot just counts average chips.
5. `no_loss_always_taken`: a gamble that can never lose is taken at every Risk. (A
   "punish the spread" rule like mean-variance fails this; research note B06.)

These are statements about one decision. They do not say how many hands a bot wins.
-/

/-! ## 1. The call rule is the Risk rule -/

theorem riskWeight_of_nonneg (risk : Nat) {g : Int} (h : 0 ≤ g) : riskWeight risk g = 50 * g := by
  simp [riskWeight, h]

theorem riskWeight_of_nonpos (risk : Nat) {g : Int} (h : g ≤ 0) :
    riskWeight risk g = (50 + risk) * g := by
  unfold riskWeight
  split
  · have : g = 0 := by omega
    subst this; simp
  · rfl

/-- **The call rule is the Risk rule.** When the pot is at least the call (always true in
a real hand: the pot holds the bet being called), `callPays` says "call" exactly when the
call has a weighted average of at least 0 at the bot's Risk. -/
theorem callPays_iff_takes (c : Counts) (pot toCall risk : Nat) (h : toCall ≤ pot) :
    callPays c pot toCall risk = true ↔ (callGamble c pot toCall).Takes risk := by
  have hw : riskWeight risk (2 * (pot : Int)) = 50 * (2 * pot) :=
    riskWeight_of_nonneg _ (by omega)
  have ht : riskWeight risk ((pot : Int) - toCall) = 50 * ((pot : Int) - toCall) :=
    riskWeight_of_nonneg _ (by omega)
  have hl : riskWeight risk (-(2 * (toCall : Int))) = (50 + risk) * (-(2 * (toCall : Int))) :=
    riskWeight_of_nonpos _ (by omega)
  simp only [callPays, decide_eq_true_eq, Gamble.Takes, Gamble.value, callGamble,
    List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, hw, ht, hl]
  have hsub : ((pot - toCall : Nat) : Int) = (pot : Int) - toCall := by omega
  rw [← Int.ofNat_le]
  push_cast [hsub]
  constructor <;> intro hle <;>
    grind

/-! ## 2. The real bot follows the rule -/

/-- The bot calls only through its call rule: if it calls, `callPays` said yes. -/
theorem decideView_call_pays (v : View) (c : Counts) (hcall : (decideView v c).action = .call) :
    callPays c v.pot v.toCall v.sliders.risk = true := by
  simp only [decideView, decideView.callOrFold, decideView.checkMove, riverOpening,
    riverBetOrCheck] at hcall
  split at hcall <;> (try split at hcall) <;> (try split at hcall) <;> (try split at hcall) <;>
    simp_all

/-- The bot folds only through its call rule: if it folds, `callPays` said no. -/
theorem decideView_fold_not_pays (v : View) (c : Counts) (hfold : (decideView v c).action = .fold) :
    callPays c v.pot v.toCall v.sliders.risk = false := by
  simp only [decideView, decideView.callOrFold, decideView.checkMove, riverOpening,
    riverBetOrCheck] at hfold
  split at hfold <;> (try split at hfold) <;> (try split at hfold) <;> (try split at hfold) <;>
    simp_all

/-- **The bot calls only when the call is worth it at its Risk.** In any spot, if the bot
calls, the call has a weighted average of at least 0 at the bot's Risk. -/
theorem bot_calls_only_when_worth_it (v : View) (c : Counts) (h : v.toCall ≤ v.pot)
    (hcall : (decideView v c).action = .call) :
    (callGamble c v.pot v.toCall).Takes v.sliders.risk :=
  (callPays_iff_takes _ _ _ _ h).mp (decideView_call_pays v c hcall)

/-- **The bot folds only when the call is not worth it at its Risk.** -/
theorem bot_folds_only_when_not_worth_it (v : View) (c : Counts) (h : v.toCall ≤ v.pot)
    (hfold : (decideView v c).action = .fold) :
    ¬ (callGamble c v.pot v.toCall).Takes v.sliders.risk := by
  rw [← callPays_iff_takes _ _ _ _ h, decideView_fold_not_pays v c hfold]
  simp

/-! ## 3. More Risk takes fewer gambles (Pratt's order of cautiousness) -/

/-- A higher Risk never makes any outcome count for more. -/
theorem riskWeight_antitone (g : Int) {r₁ r₂ : Nat} (hr : r₁ ≤ r₂) :
    riskWeight r₂ g ≤ riskWeight r₁ g := by
  unfold riskWeight
  split
  · exact Int.le_refl _
  · have : (50 + (r₁ : Int)) ≤ 50 + r₂ := by omega
    exact Int.mul_le_mul_of_nonpos_right this (by omega)

/-- A higher Risk never makes a gamble's weighted total bigger. -/
theorem value_antitone (g : Gamble) {r₁ r₂ : Nat} (hr : r₁ ≤ r₂) :
    g.value r₂ ≤ g.value r₁ := by
  induction g with
  | nil => exact Int.le_refl _
  | cons o rest ih =>
    simp only [Gamble.value, List.map_cons, List.sum_cons] at ih ⊢
    exact Int.add_le_add
      (Int.mul_le_mul_of_nonneg_left (riskWeight_antitone _ hr) (by omega)) ih

/-- **More Risk takes fewer gambles.** For any gamble, if a bot at Risk `r₂` takes it
rather than walk away, a bot at any lower Risk `r₁` takes it too. -/
theorem more_risk_takes_fewer_gambles (g : Gamble) {r₁ r₂ : Nat} (hr : r₁ ≤ r₂)
    (h : g.Takes r₂) : g.Takes r₁ :=
  Int.le_trans h (value_antitone g hr)

/-! ## 4 and 5. Two sanity checks on the meaning of Risk -/

/-- **At Risk 0 the bot just counts chips.** Each outcome counts as its chips, times 50. -/
theorem risk_zero_is_average_chips (g : Int) : riskWeight 0 g = 50 * g := by
  unfold riskWeight; split <;> simp

/-- **A gamble that can never lose is taken at every Risk.** Being careful never means
turning down free chips. -/
theorem no_loss_always_taken (g : Gamble) (risk : Nat) (h : ∀ o ∈ g, 0 ≤ o.2) :
    g.Takes risk := by
  unfold Gamble.Takes
  induction g with
  | nil => exact Int.le_refl _
  | cons o rest ih =>
    simp only [Gamble.value, List.map_cons, List.sum_cons] at ih ⊢
    have ho := h o (by simp)
    rw [riskWeight_of_nonneg _ ho]
    exact Int.add_nonneg (Int.mul_nonneg (by omega) (by omega))
      (ih fun o' ho' => h o' (by simp [ho']))

/-! ## Examples: real numbers, and bad behaviour rejected

Against a pot-sized bet (call 100 to win 200), MVP section 3 promises the bot needs 1/3
wins at Risk 0, 1/2 at Risk 50 and 3/5 at Risk 100. -/

-- Risk 0: 1 win in 3 is enough, a bit less is not.
example : (callGamble ⟨1, 0, 2⟩ 200 100).Takes 0 := by decide
example : ¬ (callGamble ⟨99, 0, 201⟩ 200 100).Takes 0 := by decide
-- Risk 50: 1 win in 2 is enough, a bit less is not.
example : (callGamble ⟨1, 0, 1⟩ 200 100).Takes 50 := by decide
example : ¬ (callGamble ⟨99, 0, 101⟩ 200 100).Takes 50 := by decide
-- Risk 100: 3 wins in 5 is enough, a bit less is not.
example : (callGamble ⟨3, 0, 2⟩ 200 100).Takes 100 := by decide
example : ¬ (callGamble ⟨299, 0, 201⟩ 200 100).Takes 100 := by decide

-- A tie that splits a pot bigger than the call is free chips: taken at every Risk.
example : (callGamble ⟨0, 1, 0⟩ 200 100).Takes 100 := by decide

/-- A bot that calls everything (like "Rook") breaks the Risk rule: with 1 win in 10
against a pot-sized bet, calling is not worth it even at Risk 0. -/
example : ¬ (callGamble ⟨1, 0, 9⟩ 200 100).Takes 0 := by decide

/-- A rule that punished risk the wrong way round (taking a gamble at Risk 100 that it
refuses at Risk 0) is ruled out: here Risk 100 refuses what Risk 0 takes. -/
example : (callGamble ⟨1, 0, 2⟩ 200 100).Takes 0 ∧ ¬ (callGamble ⟨1, 0, 2⟩ 200 100).Takes 100 := by
  decide

/-! The real bot, on the flop spot from `decide.test.ts` (call 50 to win 150, 40% wins):
it calls at Risk 0 and 50 and folds at Risk 100. Each hypothesis of the two bot theorems
holds here (the call is at most the pot, and the bot really calls or folds), and the
conclusions agree. -/

example : exFlopView.toCall ≤ exFlopView.pot := by decide
#guard (decideView { exFlopView with sliders := ⟨0, 33⟩ } ⟨40, 0, 60⟩).action.text == "call"
#guard decide ((callGamble ⟨40, 0, 60⟩ 150 50).Takes 0)
#guard (decideView { exFlopView with sliders := ⟨100, 33⟩ } ⟨40, 0, 60⟩).action.text == "fold"
#guard !decide ((callGamble ⟨40, 0, 60⟩ 150 50).Takes 100)
-- On the real start of a hand, the pot is at least the call.
#guard (viewOf ⟨50, 20⟩ [] [] exStart).toCall ≤ (viewOf ⟨50, 20⟩ [] [] exStart).pot

#print axioms callPays_iff_takes
#print axioms bot_calls_only_when_worth_it
#print axioms bot_folds_only_when_not_worth_it
#print axioms more_risk_takes_fewer_gambles
#print axioms no_loss_always_taken
