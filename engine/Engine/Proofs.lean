import Engine.Hand

/-!
# Proofs about the engine: whose turn it is

The spec says a player who is all-in, or who has bet more than the other player, may not
act (`State.MayAct`). These theorems show the engine never gives such a player the turn:
after a new hand is dealt, and after every accepted move, either the hand is over or the
player to act is allowed to act.
-/

/-- The player `nextToAct` picks still has chips and has not bet more than the other. -/
theorem nextToAct_mayAct (h : Hand) (first p : Player) (hp : h.nextToAct first = some p) :
    0 < h.chips.stack p ∧ h.chips.bet p ≤ h.chips.bet (other p) := by
  have key : ∀ q, h.needsAction q = true → 0 < h.chips.stack q ∧ h.chips.bet q ≤ h.chips.bet (other q) := by
    intro q hq
    simp only [Hand.needsAction, Bool.and_eq_true, decide_eq_true_eq] at hq
    exact ⟨hq.1.1, hq.1.2⟩
  unfold Hand.nextToAct at hp
  split at hp
  · cases hp; exact key _ (by assumption)
  · split at hp
    · cases hp; exact key _ (by assumption)
    · cases hp

/-- Giving the turn to the player `nextToAct` picked makes `MayAct` true. -/
theorem giveTurn_mayAct (h : Hand) (first p : Player) (hp : h.nextToAct first = some p) :
    ({ h with chips := { h.chips with toAct := p } } : Hand).chips.MayAct :=
  nextToAct_mayAct h first p hp

/-- A showdown ends the hand. -/
theorem payShowdown_ended (h : Hand) : h.payShowdown.ended.isSome := by
  simp [Hand.payShowdown]

/-- How many more times `finishStreet` may need to run before the showdown. -/
def Street.roundsLeft : Street → Nat
  | .preflop => 4 | .flop => 3 | .turn => 2 | .river => 1

/-- Ending a betting round, with enough fuel, either ends the hand or gives the turn to a
player who may act. -/
theorem finishStreet_turn_ok : ∀ (fuel : Nat) (h : Hand), h.street.roundsLeft ≤ fuel →
    (h.finishStreet fuel).ended.isSome ∨ (h.finishStreet fuel).chips.MayAct := by
  intro fuel
  induction fuel with
  | zero => intro h hf; cases hs : h.street <;> simp [hs, Street.roundsLeft] at hf
  | succ fuel ih =>
    intro h hf
    unfold Hand.finishStreet
    cases hs : h.street
    · -- preflop: deal the flop
      dsimp only
      split
      · next p hp => exact .inr (giveTurn_mayAct _ _ _ hp)
      · exact ih _ (by rw [hs] at hf; simp [Street.roundsLeft] at hf ⊢; omega)
    · dsimp only
      split
      · next p hp => exact .inr (giveTurn_mayAct _ _ _ hp)
      · exact ih _ (by rw [hs] at hf; simp [Street.roundsLeft] at hf ⊢; omega)
    · dsimp only
      split
      · next p hp => exact .inr (giveTurn_mayAct _ _ _ hp)
      · exact ih _ (by rw [hs] at hf; simp [Street.roundsLeft] at hf ⊢; omega)
    · -- river: showdown
      dsimp only
      exact .inl (payShowdown_ended _)

/-- Every street needs at most 4 more rounds. -/
theorem roundsLeft_le_four (st : Street) : st.roundsLeft ≤ 4 := by
  cases st <;> decide

/-- Passing the turn either ends the hand or gives the turn to a player who may act. -/
theorem passTurn_ok (h : Hand) (first : Player) :
    (h.passTurn first).ended.isSome ∨ (h.passTurn first).chips.MayAct := by
  unfold Hand.passTurn
  split
  · next p hp => exact .inr (giveTurn_mayAct _ _ _ hp)
  · exact finishStreet_turn_ok 4 _ (roundsLeft_le_four _)

/-- A new hand either ends at once (a player is all-in from the blinds) or gives the turn
to a player who may act. -/
theorem startHand_turn_ok (stacks : Player → Nat) (button : Player) (seed : Nat) :
    (startHand stacks button seed).ended.isSome ∨ (startHand stacks button seed).chips.MayAct :=
  passTurn_ok _ _

/-- **No player is asked to act when they may not.** After any accepted move, either the
hand is over or the player whose turn it is still has chips and has not bet more than the
other player. -/
theorem step_turn_ok (h h' : Hand) (a : Action) (hs : step h a = .ok h') :
    h'.ended.isSome ∨ h'.chips.MayAct := by
  unfold step at hs
  split at hs
  · cases hs
  split at hs
  · cases hs
  split at hs
  · cases hs; exact .inl (by simp [Hand.payFold])
  · cases hs; exact passTurn_ok _ _

/-! ## Checks

The theorems' conditions can hold: a real move is accepted. And the axioms each theorem
relies on are only Lean's standard ones. -/

#guard match step (startHand (fun _ => startingStack) 0 7) .call with
  | .ok h => h.ended.isNone && decide h.chips.MayAct
  | .error _ => false

#print axioms step_turn_ok
#print axioms startHand_turn_ok
