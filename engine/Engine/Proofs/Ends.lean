import Engine.Proofs
import Engine.Proofs.EndsSpec
import Engine.Proofs.Chips
import Engine.Proofs.Legal
import Engine.Proofs.Deck
import Engine.Session

/-!
# T9 `every_hand_ends`: every hand ends within 200 moves

A hand cannot go on forever. Each accepted move either ends the hand or brings it closer to
its end, in a sense a number can measure (`Hand.measure`):

- a check or a call uses up the mover's turn for this round (they have now acted);
- a raise puts at least a big blind (10 chips) more into the middle, or puts the raiser
  all-in;
- when a betting round ends, the hand moves to the next street, or to the showdown.

With 1,000 chips on the table, the measure is at most 116, so no run of accepted moves is
longer than 117 moves. Stated with the bot loop's `botFuel` of 200, which is enough.

The spec is `RunsTo` in `Engine/Proofs/EndsSpec.lean`.
-/

/-! ## The measure -/

/-- 1 while a player still has chips, else 0. -/
def hasChips (stack : Nat) : Nat := min stack 1

/-- 1 while a player still has to act this round, else 0. -/
def notActed (acted : Bool) : Nat := if acted then 0 else 1

/-- How far a hand is from its end. Every accepted move that does not end the hand makes
this number smaller. -/
def Hand.measure (h : Hand) : Nat :=
  (h.chips.stack 0 + h.chips.stack 1) / 10 + 3 * h.street.roundsLeft +
    (notActed (h.acted 0) + notActed (h.acted 1)) +
    (hasChips (h.chips.stack 0) + hasChips (h.chips.stack 1))

/-- The player to act has not acted yet this round. `reachable_acted` shows this holds in
every reachable hand that is not over; `step_measure` needs it. -/
def Hand.TurnClear (h : Hand) : Prop := h.acted h.chips.toAct = false

theorem notActed_le (b : Bool) : notActed b ≤ 1 := by cases b <;> simp [notActed]
theorem hasChips_le (n : Nat) : hasChips n ≤ 1 := Nat.min_le_right _ _

/-- In a hand with 1,000 chips the measure is at most 116. -/
theorem measure_le (h : Hand) (ht : h.chips.total = 1000) : h.measure ≤ 116 := by
  have := roundsLeft_le_four h.street
  have := notActed_le (h.acted 0)
  have := notActed_le (h.acted 1)
  have := hasChips_le (h.chips.stack 0)
  have := hasChips_le (h.chips.stack 1)
  simp only [State.total] at ht
  unfold Hand.measure
  omega

/-! ## Per-player bookkeeping -/

theorem notActed_true : notActed true = 0 := rfl
theorem notActed_false : notActed false = 1 := rfl
theorem other_zero : other 0 = 1 := by decide
theorem other_one : other 1 = 0 := by decide

theorem pair_sum (f : Player → Nat) (me : Player) : f 0 + f 1 = f me + f (other me) := by
  match me with
  | ⟨0, _⟩ => simp [other]
  | ⟨1, _⟩ => simp [other]; omega

theorem other_ne (p : Player) : other p ≠ p := by
  unfold other
  split
  · next h => rw [h]; decide
  · next h => exact fun h' => h h'.symm

theorem other_other (p : Player) : other (other p) = p := by
  match p with
  | ⟨0, _⟩ => simp [other]
  | ⟨1, _⟩ => simp [other]

theorem setFor_self {β : Type} (f : Player → β) (p : Player) (v : β) : setFor f p v p = v := by
  simp [setFor]

theorem setFor_ne {β : Type} (f : Player → β) (p q : Player) (v : β) (h : q ≠ p) :
    setFor f p v q = f q := by
  simp [setFor, h]

/-- The measure, written with the player `me` first. -/
theorem measure_eq (h : Hand) (me : Player) :
    h.measure = (h.chips.stack me + h.chips.stack (other me)) / 10 + 3 * h.street.roundsLeft +
      (notActed (h.acted me) + notActed (h.acted (other me))) +
      (hasChips (h.chips.stack me) + hasChips (h.chips.stack (other me))) := by
  have h1 := pair_sum h.chips.stack me
  have h2 := pair_sum (fun p => notActed (h.acted p)) me
  have h3 := pair_sum (fun p => hasChips (h.chips.stack p)) me
  unfold Hand.measure
  omega

/-! ## One move, before the turn passes -/

/-- The hand right after the player to act checks or calls, before the turn passes: the
chips move and the mover's acted flag is set, as in `step`. -/
def Hand.afterApply (h : Hand) (a : Action) : Hand :=
  { h with chips := applyMove h.chips a, acted := setFor h.acted h.chips.toAct true }

/-- The hand right after the player to act raises to `n`, before the turn passes: the chips
move, the mover's acted flag is set and the other player's is cleared, as in `step`. -/
def Hand.afterRaise (h : Hand) (n : Nat) : Hand :=
  { h with chips := applyMove h.chips (.raiseTo n),
           acted := setFor (setFor h.acted h.chips.toAct true) (other h.chips.toAct) false }

/-- The hand is not over when a move is accepted. -/
theorem ended_none_of_step (h h' : Hand) (a : Action) (hs : step h a = .ok h') :
    h.ended = none := by
  cases he : h.ended with
  | none => rfl
  | some e => unfold step at hs; simp [he] at hs

/-- What `step` gives for each accepted move. -/
theorem step_fold (h : Hand) (he : h.ended = none) (hl : Legal h.chips .fold) :
    step h .fold = .ok (h.payFold (other h.chips.toAct)) := by
  simp [step, he, hl]

theorem step_check (h : Hand) (he : h.ended = none) (hl : Legal h.chips .check) :
    step h .check = .ok (h.afterApply .check).afterMove := by
  simp [step, he, hl, Hand.afterApply]

theorem step_call (h : Hand) (he : h.ended = none) (hl : Legal h.chips .call) :
    step h .call = .ok (h.afterApply .call).afterMove := by
  simp [step, he, hl, Hand.afterApply]

theorem step_raise (h : Hand) (n : Nat) (he : h.ended = none) (hl : Legal h.chips (.raiseTo n)) :
    step h (.raiseTo n) = .ok (h.afterRaise n).afterMove := by
  simp [step, he, hl, Hand.afterRaise]

/-- A check uses up the mover's turn. -/
theorem measure_check (h : Hand) (hJ : h.acted h.chips.toAct = false) :
    (h.afterApply .check).measure + 1 ≤ h.measure := by
  rw [measure_eq _ h.chips.toAct, measure_eq _ h.chips.toAct]
  simp only [Hand.afterApply, applyMove, setFor_self, setFor_ne _ _ _ _ (other_ne _), hJ,
    notActed_true, notActed_false]
  omega

/-- A call uses up the mover's turn and never adds chips to a stack. -/
theorem measure_call (h : Hand) (hJ : h.acted h.chips.toAct = false) :
    (h.afterApply .call).measure + 1 ≤ h.measure := by
  rw [measure_eq _ h.chips.toAct, measure_eq _ h.chips.toAct]
  simp only [Hand.afterApply, applyMove, setFor_self, setFor_ne _ _ _ _ (other_ne _), hJ,
    notActed_true, notActed_false, hasChips]
  omega

/-- A raise puts at least a big blind more in, or puts the raiser all-in. -/
theorem measure_raise (h : Hand) (n : Nat) (hl : Legal h.chips (.raiseTo n))
    (hJ : h.acted h.chips.toAct = false) :
    (h.afterRaise n).measure + 1 ≤ h.measure := by
  obtain ⟨⟨hst, hbet⟩, -, hgt, hle, hmin⟩ := hl
  simp only [State.minRaise, bigBlind] at hmin
  rw [measure_eq _ h.chips.toAct, measure_eq _ h.chips.toAct]
  simp only [Hand.afterRaise, applyMove, setFor_self, setFor_ne _ _ _ _ (other_ne _),
    setFor_ne _ _ _ _ (other_ne _).symm, hJ, notActed_true, notActed_false, hasChips]
  omega

/-! ## Ending a betting round -/

/-- With equal bets, nothing is given back. -/
theorem returnUncalled_of_eq (s : State) (hb : s.bet 0 = s.bet 1) : returnUncalled s = s := by
  unfold returnUncalled
  simp [hb]

/-- Ending a betting round with equal bets ends the hand or does not raise the measure. -/
theorem finishStreet_measure : ∀ (fuel : Nat) (h : Hand), h.street.roundsLeft ≤ fuel →
    h.chips.bet 0 = h.chips.bet 1 →
    (h.finishStreet fuel).ended.isSome ∨ (h.finishStreet fuel).measure ≤ h.measure := by
  intro fuel
  induction fuel with
  | zero => intro h hf; cases hs : h.street <;> simp [hs, Street.roundsLeft] at hf
  | succ fuel ih =>
    intro h hf hb
    simp only [Hand.finishStreet, returnUncalled_of_eq _ hb]
    split
    · exact .inl (payShowdown_ended _)
    · next street n heq =>
      split at heq <;> cases heq <;> rename_i hs
      all_goals
        split
        · right
          simp only [Hand.measure, Hand.dealBoard, collectBets, Street.roundsLeft, hs,
            notActed_false]
          omega
        · refine (ih _ ?_ rfl).imp id (fun h3 => Nat.le_trans h3 ?_)
          · simp only [Street.roundsLeft, hs] at hf ⊢; omega
          · simp only [Hand.measure, Hand.dealBoard, collectBets, Street.roundsLeft, hs,
              notActed_false]
            omega

/-- The player with the lower (or equal) bet has no chips left. -/
def AllInBehind (s : State) : Prop :=
  (s.bet 0 ≤ s.bet 1 ∧ s.stack 0 = 0) ∨ (s.bet 1 ≤ s.bet 0 ∧ s.stack 1 = 0)

/-- Giving back the unmatched part of a bet leaves the all-in player at 0. -/
theorem returnUncalled_allIn (s : State) (h : AllInBehind s) :
    (returnUncalled s).stack 0 = 0 ∨ (returnUncalled s).stack 1 = 0 := by
  unfold returnUncalled
  rcases h with ⟨hb, hs⟩ | ⟨hb, hs⟩
  · split
    · omega
    · split
      · left; simp [setFor]; exact hs
      · left; exact hs
  · split
    · right; simp [setFor]; exact hs
    · split
      · omega
      · right; exact hs

/-- When a player is all-in and the bets are collected, nobody needs to act. -/
theorem nextToAct_none_of_allIn (h : Hand) (first : Player)
    (hb0 : h.chips.bet 0 = 0) (hb1 : h.chips.bet 1 = 0)
    (hs : h.chips.stack 0 = 0 ∨ h.chips.stack 1 = 0) : h.nextToAct first = none := by
  have hna : ∀ p, h.needsAction p = false := by
    intro p
    match p with
    | ⟨0, _⟩ => rcases hs with hs | hs <;> simp [Hand.needsAction, other, hb0, hb1, hs]
    | ⟨1, _⟩ => rcases hs with hs | hs <;> simp [Hand.needsAction, other, hb0, hb1, hs]
  simp [Hand.nextToAct, hna]

/-- Once a player is all-in behind, ending the round ends the hand: the remaining streets
are dealt with nobody to act, and the showdown pays out. -/
theorem finishStreet_ended_of_allIn : ∀ (fuel : Nat) (h : Hand), h.street.roundsLeft ≤ fuel →
    AllInBehind h.chips → (h.finishStreet fuel).ended.isSome := by
  intro fuel
  induction fuel with
  | zero => intro h hf; cases hs : h.street <;> simp [hs, Street.roundsLeft] at hf
  | succ fuel ih =>
    intro h hf hall
    have hz := returnUncalled_allIn h.chips hall
    have hnone : ∀ (st : Street) (k : Nat) (first : Player),
        ({ (({ h with chips := collectBets (returnUncalled h.chips), acted := fun _ => false }
          : Hand).dealBoard k) with street := st } : Hand).nextToAct first = none :=
      fun st k first => nextToAct_none_of_allIn _ first rfl rfl
        (by simpa [Hand.dealBoard, collectBets] using hz)
    simp only [Hand.finishStreet]
    split
    · exact payShowdown_ended _
    · next street n heq =>
      rw [hnone]
      split at heq <;> cases heq <;> rename_i hs
      all_goals
        apply ih
        · simp only [Street.roundsLeft, hs] at hf ⊢; omega
        · simp only [AllInBehind, Hand.dealBoard, collectBets]
          rcases hz with hz | hz
          · exact .inl ⟨Nat.le_refl _, hz⟩
          · exact .inr ⟨Nat.le_refl _, hz⟩

/-- Passing the turn ends the hand or does not raise the measure. -/
theorem passTurn_measure (h : Hand) (first : Player) :
    (h.passTurn first).ended.isSome ∨ (h.passTurn first).measure ≤ h.measure := by
  unfold Hand.passTurn
  split
  · exact .inr (Nat.le_of_eq rfl)
  · next hn =>
    -- Nobody needs to act: the bets are equal, or the player behind is all-in.
    have hboth : h.needsAction 0 = false ∧ h.needsAction 1 = false := by
      unfold Hand.nextToAct at hn
      split at hn
      · cases hn
      · split at hn
        · cases hn
        · next h1 h2 =>
          simp only [Bool.not_eq_true] at h1 h2
          match first with
          | ⟨0, _⟩ => exact ⟨h1, by simpa [other] using h2⟩
          | ⟨1, _⟩ => exact ⟨by simpa [other] using h2, h1⟩
    obtain ⟨h0, h1⟩ := hboth
    have hR := roundsLeft_le_four h.street
    rcases Nat.lt_trichotomy (h.chips.bet 0) (h.chips.bet 1) with hlt | heq | hgt
    · left
      apply finishStreet_ended_of_allIn 4 h hR
      left
      refine ⟨Nat.le_of_lt hlt, ?_⟩
      simp only [Hand.needsAction, other_zero, Bool.and_eq_false_iff, Bool.or_eq_false_iff,
        decide_eq_false_iff_not] at h0
      rcases h0 with (h0 | h0) | ⟨h0, -⟩ <;> omega
    · exact finishStreet_measure 4 h hR heq
    · left
      apply finishStreet_ended_of_allIn 4 h hR
      right
      refine ⟨Nat.le_of_lt hgt, ?_⟩
      simp only [Hand.needsAction, other_one, Bool.and_eq_false_iff, Bool.or_eq_false_iff,
        decide_eq_false_iff_not] at h1
      rcases h1 with (h1 | h1) | ⟨h1, -⟩ <;> omega

/-! ## One accepted move -/

/-- **Every accepted move ends the hand or lowers the measure**, provided the player to act
has not acted yet this round (which `reachable_acted` shows always holds). -/
theorem step_measure (h h' : Hand) (a : Action) (hJ : h.acted h.chips.toAct = false)
    (hs : step h a = .ok h') : h'.ended.isSome ∨ h'.measure < h.measure := by
  have hl := accepted_move_is_legal h h' a hs
  have he := ended_none_of_step h h' a hs
  cases a with
  | fold =>
    rw [step_fold h he hl] at hs
    cases hs
    exact .inl (by simp [Hand.payFold])
  | check =>
    rw [step_check h he hl] at hs
    cases hs
    have hm := measure_check h hJ
    rcases passTurn_measure (h.afterApply .check) (other h.chips.toAct) with hend | hle
    · exact .inl hend
    · exact .inr (Nat.lt_of_le_of_lt hle (by omega))
  | call =>
    rw [step_call h he hl] at hs
    cases hs
    have hm := measure_call h hJ
    rcases passTurn_measure (h.afterApply .call) (other h.chips.toAct) with hend | hle
    · exact .inl hend
    · exact .inr (Nat.lt_of_le_of_lt hle (by omega))
  | raiseTo n =>
    rw [step_raise h n he hl] at hs
    cases hs
    have hm := measure_raise h n hl hJ
    rcases passTurn_measure (h.afterRaise n) (other h.chips.toAct) with hend | hle
    · exact .inl hend
    · exact .inr (Nat.lt_of_le_of_lt hle (by omega))

/-! ## The player to act has not acted yet this round -/

/-- Ending a round ends the hand or clears every player's acted flag. -/
theorem finishStreet_acted : ∀ (fuel : Nat) (h : Hand), h.street.roundsLeft ≤ fuel →
    (h.finishStreet fuel).ended.isSome ∨ ∀ p, (h.finishStreet fuel).acted p = false := by
  intro fuel
  induction fuel with
  | zero => intro h hf; cases hs : h.street <;> simp [hs, Street.roundsLeft] at hf
  | succ fuel ih =>
    intro h hf
    simp only [Hand.finishStreet]
    split
    · exact .inl (payShowdown_ended _)
    · next street n heq =>
      split at heq <;> cases heq <;> rename_i hs
      all_goals
        split
        · exact .inr fun p => rfl
        · exact ih _ (by simp [Street.roundsLeft, hs] at hf ⊢; omega)

/-- Passing the turn to a player who needs to act and has not acted yet (or ending the round)
leaves the player to act with the acted flag clear. -/
theorem passTurn_acted (h : Hand) (first : Player)
    (h1 : h.needsAction first = true → h.acted first = false)
    (h2 : h.needsAction (other first) = true → h.acted (other first) = false) :
    (h.passTurn first).ended.isSome ∨ (h.passTurn first).TurnClear := by
  unfold Hand.passTurn
  split
  · next p hp =>
    right
    unfold Hand.TurnClear
    unfold Hand.nextToAct at hp
    split at hp
    · cases hp; exact h1 (by assumption)
    · split at hp
      · cases hp; exact h2 (by assumption)
      · cases hp
  · rcases finishStreet_acted 4 h (roundsLeft_le_four _) with he | ha
    · exact .inl he
    · exact .inr (ha _)

/-- What `needsAction` says, as a proposition. -/
theorem needsAction_iff (h : Hand) (p : Player) :
    h.needsAction p = true ↔
      0 < h.chips.stack p ∧ h.chips.bet p ≤ h.chips.bet (other p) ∧
        (h.chips.bet p < h.chips.bet (other p) ∨
          (h.acted p = false ∧ 0 < h.chips.stack (other p))) := by
  simp [Hand.needsAction, and_assoc]

/-- After an accepted move, the hand is over or the player to act has not acted yet. -/
theorem step_acted (h h' : Hand) (a : Action) (hs : step h a = .ok h') :
    h'.ended.isSome ∨ h'.TurnClear := by
  have hl := accepted_move_is_legal h h' a hs
  have he := ended_none_of_step h h' a hs
  cases a with
  | fold =>
    rw [step_fold h he hl] at hs
    cases hs
    exact .inl (by simp [Hand.payFold])
  | check =>
    rw [step_check h he hl] at hs
    cases hs
    obtain ⟨⟨hst, hbet⟩, hc⟩ := hl
    simp only [State.toCall] at hc
    refine passTurn_acted (h.afterApply .check) (other h.chips.toAct) ?_ ?_
    · intro hn
      rw [needsAction_iff] at hn
      simp only [Hand.afterApply, applyMove, other_other, setFor_ne _ _ _ _ (other_ne _)] at hn ⊢
      rcases hn with ⟨-, -, hlt | ⟨ha, -⟩⟩
      · exact absurd hlt (by omega)
      · exact ha
    · intro hn
      rw [needsAction_iff] at hn
      simp only [Hand.afterApply, applyMove, other_other, setFor_self] at hn ⊢
      rcases hn with ⟨-, -, hlt | ⟨ha, -⟩⟩
      · exact absurd hlt (by omega)
      · cases ha
  | call =>
    rw [step_call h he hl] at hs
    cases hs
    obtain ⟨⟨hst, hbet⟩, hc⟩ := hl
    simp only [State.toCall] at hc
    refine passTurn_acted (h.afterApply .call) (other h.chips.toAct) ?_ ?_
    · intro hn
      rw [needsAction_iff] at hn
      simp only [Hand.afterApply, applyMove, State.toCall, other_other, setFor_self,
        setFor_ne _ _ _ _ (other_ne _)] at hn ⊢
      rcases hn with ⟨-, -, hlt | ⟨ha, -⟩⟩
      · exact absurd hlt (by omega)
      · exact ha
    · intro hn
      rw [needsAction_iff] at hn
      simp only [Hand.afterApply, applyMove, State.toCall, other_other, setFor_self,
        setFor_ne _ _ _ _ (other_ne _)] at hn ⊢
      rcases hn with ⟨hst', -, hlt | ⟨ha, -⟩⟩
      · exact absurd hlt (by omega)
      · cases ha
  | raiseTo n =>
    rw [step_raise h n he hl] at hs
    cases hs
    obtain ⟨⟨hst, hbet⟩, -, hgt, hle, -⟩ := hl
    refine passTurn_acted (h.afterRaise n) (other h.chips.toAct) ?_ ?_
    · intro _
      simp only [Hand.afterRaise, applyMove, setFor_self]
    · intro hn
      rw [needsAction_iff] at hn
      simp only [Hand.afterRaise, applyMove, other_other, setFor_self,
        setFor_ne _ _ _ _ (other_ne _), setFor_ne _ _ _ _ (other_ne _).symm] at hn ⊢
      rcases hn with ⟨-, hle', -⟩
      exact absurd hle' (by omega)

/-- Nobody has acted in a hand dealt from any deck. -/
theorem dealFrom_acted (stacks : Player → Nat) (button : Player) (d : List Card) (p : Player) :
    (dealFrom stacks button d).acted p = false := by
  rcases d with _ | ⟨a, _ | ⟨b, _ | ⟨c, _ | ⟨e, rest⟩⟩⟩⟩ <;> rfl

/-- Nobody has acted in a freshly dealt hand. -/
theorem dealHand_acted (stacks : Player → Nat) (button : Player) (seed : Nat) (p : Player) :
    (dealHand stacks button seed).acted p = false := by
  rw [dealHand_eq_dealFrom]
  exact dealFrom_acted _ _ _ _

/-- A freshly dealt hand: over, or the player to act has not acted yet. -/
theorem startHand_acted (stacks : Player → Nat) (button : Player) (seed : Nat) :
    (startHand stacks button seed).ended.isSome ∨ (startHand stacks button seed).TurnClear :=
  passTurn_acted _ _ (fun _ => dealHand_acted _ _ _ _) (fun _ => dealHand_acted _ _ _ _)

/-- **In every reachable hand the player to act has not acted yet this round.** -/
theorem reachable_acted (h : Hand) (hr : h.Reachable) :
    h.ended.isSome ∨ h.TurnClear := by
  induction hr with
  | deal stacks button seed => exact startHand_acted stacks button seed
  | move a _ hs _ => exact step_acted _ _ a hs

/-! ## The theorem -/

/-- Once the hand is over, no more moves are accepted. -/
theorem runsTo_nil_of_ended (h h' : Hand) (as : List Action) (he : h.ended.isSome)
    (hrun : RunsTo h as h') : as = [] := by
  cases as with
  | nil => rfl
  | cons a as =>
    obtain ⟨h₁, hs, -⟩ := hrun
    unfold step at hs
    simp [he] at hs

/-- A run of accepted moves from a hand whose player to act has not acted yet is at most
one move longer than the hand's measure. -/
theorem run_length_le (as : List Action) : ∀ (h h' : Hand),
    h.TurnClear → RunsTo h as h' → as.length ≤ h.measure + 1 := by
  induction as with
  | nil => intro h h' _ _; simp
  | cons a as ih =>
    intro h h' hJ hrun
    obtain ⟨h₁, hs, hrun₁⟩ := hrun
    by_cases he : h₁.ended.isSome
    · rw [runsTo_nil_of_ended h₁ h' as he hrun₁]
      simp
    · have hJ₁ : h₁.TurnClear := by
        rcases step_acted h h₁ a hs with h | h
        · exact absurd h he
        · exact h
      have hm : h₁.measure < h.measure := by
        rcases step_measure h h₁ a hJ hs with h | h
        · exact absurd h he
        · exact h
      have := ih h₁ h' hJ₁ hrun₁
      simp only [List.length_cons]
      omega

/-- **T9: every hand ends within 200 moves.** From any game the engine can reach, every run
of accepted moves has at most 200 moves, the bot loop's `botFuel`. (The proof shows at most
117.) -/
theorem every_hand_ends (g : Game) (hg : g.Reachable) (as : List Action) (h' : Hand)
    (hrun : RunsTo g.hand as h') : as.length ≤ 200 := by
  have ht := chips_always_1000 g hg
  have hJ : g.hand.TurnClear ∨ as = [] := by
    rcases reachable_acted g.hand hg.hand with he | hJ
    · exact .inr (runsTo_nil_of_ended _ _ _ he hrun)
    · exact .inl hJ
  rcases hJ with hJ | rfl
  · have := run_length_le as g.hand h' hJ hrun
    have := measure_le g.hand ht
    omega
  · simp

/-! ## Checks on the statement -/

-- The bound is the bot loop's fuel.
example : botFuel = 200 := rfl

/-- What "every hand ends within `n` moves" asks of any engine `st`. -/
def EndsWithin (n : Nat) (st : Hand → Action → Except String Hand) : Prop :=
  ∀ (g : Game), g.Reachable → ∀ (as : List Action) (h' : Hand),
    RunsWith st g.hand as h' → as.length ≤ n

example : EndsWithin 200 step := every_hand_ends

/-- An engine that accepts every move and never changes the hand runs forever. -/
theorem runsWith_same (h : Hand) : ∀ n, RunsWith (fun h _ => .ok h) h (List.replicate n .check) h
  | 0 => rfl
  | n + 1 => ⟨h, rfl, runsWith_same h n⟩

/-- Such an engine is rejected: 201 checks are accepted in a row. -/
example : ¬ EndsWithin 200 fun h _ => .ok h := by
  intro h
  have := h (newGame 7) (.start 7) (List.replicate 201 .check) _ (runsWith_same _ 201)
  rw [List.length_replicate] at this
  omega

#print axioms every_hand_ends
