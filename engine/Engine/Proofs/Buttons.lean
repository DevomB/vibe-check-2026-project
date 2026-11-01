import Engine.Bot

/-!
# The buttons the page offers are exactly the legal moves

The app builds the human's buttons from `legalOptions` (`Engine/Protocol.lean` sends it as
`legal`): whether Fold and Check work, how much a call costs, and the smallest and largest
raise. `legalOptions_exact` shows these say exactly what the rules (`Legal`) say. So the page
never offers an illegal move, and never hides a legal one.
-/

/-- **The buttons match the rules.** In any state:
- the Fold button works exactly when folding is legal;
- the Check button works exactly when checking is legal;
- the call amount is above 0 exactly when calling is legal, and it is then the chips a call
  really costs (`State.toCall`);
- a raise to `n` is legal exactly when a raise range is offered and `n` is inside it. -/
theorem legalOptions_exact (s : State) :
    ((legalOptions s).fold = true ↔ Legal s .fold) ∧
    ((legalOptions s).check = true ↔ Legal s .check) ∧
    (0 < (legalOptions s).call ↔ Legal s .call) ∧
    (Legal s .call → (legalOptions s).call = s.toCall) ∧
    (∀ n, Legal s (.raiseTo n) ↔
      ∃ lo hi, (legalOptions s).raise = some (lo, hi) ∧ lo ≤ n ∧ n ≤ hi) := by
  refine ⟨by simp [legalOptions], by simp [legalOptions], ?_, ?_, ?_⟩
  · -- A legal call costs at least one chip: something is owed and the caller has chips.
    simp only [legalOptions]
    by_cases hc : Legal s .call
    · simp only [hc, decide_true, ↓reduceIte, iff_true]
      simp only [Legal, State.MayAct, State.toCall] at hc ⊢
      omega
    · simp [hc]
  · intro hc
    simp only [legalOptions, hc, decide_true, ↓reduceIte]
    simp only [State.toCall]
    omega
  · intro n
    by_cases ha : Legal s (.raiseTo (s.bet s.toAct + s.stack s.toAct))
    · have hr : (legalOptions s).raise =
          some (min (s.bet (other s.toAct) + s.minRaise) (s.bet s.toAct + s.stack s.toAct),
                s.bet s.toAct + s.stack s.toAct) := by
        simp [legalOptions, ha]
      rw [hr]
      simp only [Legal, State.MayAct, State.minRaise, bigBlind] at ha ⊢
      constructor
      · intro hn; exact ⟨_, _, rfl, by omega, by omega⟩
      · rintro ⟨lo, hi, heq, h1, h2⟩
        simp only [Option.some.injEq, Prod.mk.injEq] at heq
        obtain ⟨rfl, rfl⟩ := heq
        omega
    · have hr : (legalOptions s).raise = none := by simp [legalOptions, ha]
      rw [hr]
      simp only [reduceCtorEq, false_and, exists_const, iff_false]
      intro hn
      apply ha
      simp only [Legal, State.MayAct, State.minRaise, bigBlind] at hn ⊢
      omega

/-! ## Checks -/

/-- At the start of a hand: Fold, Call 5, and raises from 20 to 500. A raise to 20 is legal
and inside the range. -/
example : Legal exStart (.raiseTo 20) ∧ legalOptions exStart = ⟨true, false, 5, some (20, 500)⟩ :=
  ⟨by decide, rfl⟩

/-- The theorem applies there: every raise from 20 to 500 is legal. -/
example (n : Nat) (h1 : 20 ≤ n) (h2 : n ≤ 500) : Legal exStart (.raiseTo n) :=
  ((legalOptions_exact exStart).2.2.2.2 n).2 ⟨20, 500, rfl, h1, h2⟩

/-- After a short all-in, no raise is offered, and indeed none is legal. -/
example : (legalOptions exShortAllIn).raise = none := rfl

/-- The statement rejects wrong buttons: if the page offered raises from 15 (below the
minimum), a raise to 15 would be "offered" but it is not legal. -/
example : ¬ Legal exStart (.raiseTo 15) ∧ (15 ≤ 15 ∧ 15 ≤ 500) := ⟨by decide, by decide⟩

#print axioms legalOptions_exact
