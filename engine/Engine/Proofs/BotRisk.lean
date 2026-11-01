import Engine.Proofs.BotSpec

/-!
# T4: more Risk never means more calls

The bot's Risk slider only appears in one place: `callPays`, the rule for calling a bet.
A higher Risk makes a loss count for more there, so it can only turn a call into a fold.
The counts do not depend on Risk either: `countsFor` has no slider input.
-/

/-- A higher Risk never turns a call that does not pay into one that does. Risk only
makes the loss side of `callPays` bigger. -/
theorem callPays_risk_mono (c : Counts) (pot toCall r₁ r₂ : Nat) (hr : r₁ ≤ r₂)
    (h : callPays c pot toCall r₂ = true) : callPays c pot toCall r₁ = true := by
  simp only [callPays, decide_eq_true_eq] at h ⊢
  refine Nat.le_trans ?_ h
  refine Nat.mul_le_mul_right _ (Nat.mul_le_mul_right _ (Nat.mul_le_mul_left _ ?_))
  omega

/-- In one view, if the bot calls or raises at Risk `r₂`, it also does at a lower Risk
`r₁`. Facing a bet, only the call rule looks at Risk. With no bet to face, Risk is not
looked at at all. -/
theorem decideView_risk_mono (v : View) (c : Counts) (b r₁ r₂ : Nat) (hr : r₁ ≤ r₂)
    (h : (decideView { v with sliders := ⟨r₂, b⟩ } c).action.continues) :
    (decideView { v with sliders := ⟨r₁, b⟩ } c).action.continues := by
  by_cases hc : 0 < v.toCall
  · cases h2 : callPays c v.pot v.toCall r₂
    · cases hraise : v.raise with
      | none => simp [decideView, decideView.callOrFold, hc, hraise, h2, Action.continues] at h
      | some p =>
        cases ha : c.atLeast raiseAtPercent
        · simp [decideView, decideView.callOrFold, hc, hraise, h2, ha, Action.continues] at h
        · simp [decideView, hc, ha, Action.continues]
    · have h1 := callPays_risk_mono c _ _ r₁ r₂ hr h2
      cases hraise : v.raise with
      | none => simp [decideView, decideView.callOrFold, hc, h1, Action.continues]
      | some p =>
        cases ha : c.atLeast raiseAtPercent
        · simp [decideView, decideView.callOrFold, hc, h1, ha, Action.continues]
        · simp [decideView, hc, ha, Action.continues]
  · have same : (decideView { v with sliders := ⟨r₂, b⟩ } c).action =
        (decideView { v with sliders := ⟨r₁, b⟩ } c).action := by
      simp only [decideView, hc, ↓reduceIte, riverOpening, decideView.checkMove, View.potBetTarget]
      split <;> (try split) <;> (try split) <;> rfl
    rw [← same]; exact h

/-- For given counts, in one spot, the bot's moves at each Risk are Risk-monotone. -/
theorem risk_monotone (bluff : Nat) (c : Counts) (hole board : List Card) (s : State) :
    RiskMonotone fun r => (decideWithCounts ⟨r, bluff⟩ c hole board s).action :=
  fun r₁ r₂ hr h => decideView_risk_mono (viewOf ⟨0, bluff⟩ hole board s) c bluff r₁ r₂ hr h

/-- The bot's counts come from `countsFor seed hole board`, which has no Risk input. So at
every Risk setting the bot decides from the same counts. -/
theorem botDecide_eq (sl : Sliders) (seed : Nat) (hole board : List Card) (s : State) :
    botDecide sl seed hole board s = decideWithCounts sl (countsFor seed hole board) hole board s :=
  rfl

/-- **T4: more Risk never means more calls.** Take one spot: the same betting state, seed,
cards and Bluff. If the bot calls or raises at Risk `r₂`, it also calls or raises at every
lower Risk `r₁`. -/
theorem botDecide_risk_monotone (bluff seed : Nat) (hole board : List Card) (s : State) :
    RiskMonotone fun r => (botDecide ⟨r, bluff⟩ seed hole board s).action :=
  risk_monotone bluff (countsFor seed hole board) hole board s

/-! ## Checks -/

/-- The theorem's condition can hold. With 40 wins in 100, calling 50 to win 150 pays at
Risk 0 but not at Risk 100. So the bot folds at Risk 100 and calls at Risk 0. -/
example : (decideView { exFlopView with sliders := ⟨100, 33⟩ } ⟨40, 0, 60⟩).action.continues = false ∧
    (decideView { exFlopView with sliders := ⟨0, 33⟩ } ⟨40, 0, 60⟩).action.continues = true := by
  decide

/-- A spot where the bot calls at Risk 100 (60 wins in 100), so it must call at Risk 0 too. -/
example : (decideView { exFlopView with sliders := ⟨0, 33⟩ } ⟨60, 0, 40⟩).action.continues :=
  decideView_risk_mono exFlopView ⟨60, 0, 40⟩ 33 0 100 (by decide) (by decide)

/-- The same at the start of a real hand: the small blind faces the big blind with 60 wins
in 100. It calls at Risk 100, so the theorem says it calls at Risk 0 too. -/
example : (decideWithCounts ⟨0, 20⟩ ⟨60, 0, 40⟩ [] [] exStart).action.continues :=
  risk_monotone 20 ⟨60, 0, 40⟩ [] [] exStart 0 100 (by decide) (by decide)

#print axioms botDecide_risk_monotone
