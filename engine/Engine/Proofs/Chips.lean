import Lean
import Engine.Proofs.Reachable

/-!
# T1: chips are never created or destroyed

Every chip is in one of five places: the two stacks, the pot, and the two bets of this
round. `State.total` adds them up. These theorems show that no part of the engine changes
that sum: not a move, not the end of a betting round, not the payout, and not the deal of
the next hand. So a game that starts with 500 chips each always holds exactly 1,000.

Each helper of the engine gets its own small lemma, and the lemmas are chained together.
-/

/-! ## Changing one player's entry -/

/-- Changing one player's entry to `v` changes the sum of both entries by the difference. -/
theorem setFor_sum (f : Player → Nat) (p : Player) (v : Nat) :
    setFor f p v 0 + setFor f p v 1 + f p = f 0 + f 1 + v := by
  match p with
  | ⟨0, _⟩ => simp [setFor]; omega
  | ⟨1, _⟩ => simp [setFor]; omega

/-! ## Moving chips during a betting round -/

/-- A legal check, call or raise keeps the total. A legal move never asks a player to pay
more than their stack, so no subtraction is cut off at 0. -/
theorem applyMove_total (s : State) (a : Action) (hl : Legal s a) :
    (applyMove s a).total = s.total := by
  cases a with
  | fold => rfl
  | check => rfl
  | call =>
    have h1 := setFor_sum s.stack s.toAct (s.stack s.toAct - min s.toCall (s.stack s.toAct))
    have h2 := setFor_sum s.bet s.toAct (s.bet s.toAct + min s.toCall (s.stack s.toAct))
    have h3 : min s.toCall (s.stack s.toAct) ≤ s.stack s.toAct := Nat.min_le_right _ _
    simp only [applyMove, State.total]
    omega
  | raiseTo n =>
    have hpay : n - s.bet s.toAct ≤ s.stack s.toAct := by
      simp only [Legal] at hl; exact hl.2.2.2.1
    have h1 := setFor_sum s.stack s.toAct (s.stack s.toAct - (n - s.bet s.toAct))
    have h2 := setFor_sum s.bet s.toAct (s.bet s.toAct + (n - s.bet s.toAct))
    simp only [applyMove, State.total]
    omega

/-- Giving back the unmatched part of a bet keeps the total. -/
theorem returnUncalled_total (s : State) : (returnUncalled s).total = s.total := by
  unfold returnUncalled
  split
  · have h1 := setFor_sum s.stack 0 (s.stack 0 + (s.bet 0 - s.bet 1))
    have h2 := setFor_sum s.bet 0 (s.bet 1)
    simp only [State.total]; omega
  · split
    · have h1 := setFor_sum s.stack 1 (s.stack 1 + (s.bet 1 - s.bet 0))
      have h2 := setFor_sum s.bet 1 (s.bet 0)
      simp only [State.total]; omega
    · rfl

/-- Moving the bets into the pot keeps the total. -/
theorem collectBets_total (s : State) : (collectBets s).total = s.total := by
  simp only [collectBets, State.total]; omega

/-! ## Ending a hand -/

/-- A fold keeps the total: the winner takes the pot and both bets. -/
theorem payFold_total (h : Hand) (w : Player) : (h.payFold w).chips.total = h.chips.total := by
  have h1 := setFor_sum h.chips.stack w
    (h.chips.stack w + (h.chips.pot + h.chips.bet 0 + h.chips.bet 1))
  simp only [Hand.payFold, State.total]
  omega

/-- A showdown keeps the total when the bets are already in the pot. On a tie the pot is
split in two parts that add up to the whole pot. -/
theorem payShowdown_total (h : Hand) (hb0 : h.chips.bet 0 = 0) (hb1 : h.chips.bet 1 = 0) :
    h.payShowdown.chips.total = h.chips.total := by
  have hd := Nat.div_le_self h.chips.pot 2
  simp only [Hand.payShowdown, State.total, hb0, hb1]
  cases showdown (h.hole 0) (h.hole 1) h.board with
  | player0 => simp; omega
  | player1 => simp; omega
  | tie =>
    match h.button with
    | ⟨0, _⟩ => simp [other]; omega
    | ⟨1, _⟩ => simp [other]; omega

/-! ## Ending a betting round and passing the turn -/

/-- Ending betting rounds keeps the total, however many rounds are ended. -/
theorem finishStreet_total (fuel : Nat) (h : Hand) :
    (h.finishStreet fuel).chips.total = h.chips.total := by
  induction fuel generalizing h with
  | zero => rfl
  | succ fuel ih =>
    have hc : (collectBets (returnUncalled h.chips)).total = h.chips.total := by
      rw [collectBets_total, returnUncalled_total]
    simp only [Hand.finishStreet]
    split
    · next heq =>
      split at heq <;> try (cases heq)
      rw [payShowdown_total _ rfl rfl]; exact hc
    · split
      · exact hc
      · rw [ih]; exact hc

/-- Passing the turn keeps the total. -/
theorem passTurn_total (h : Hand) (first : Player) :
    (h.passTurn first).chips.total = h.chips.total := by
  unfold Hand.passTurn
  split
  · rfl
  · exact finishStreet_total _ _

/-! ## The main theorems -/

/-- After any accepted move, the chips in the stacks, the pot and the bets add up to the
same number as before. -/
theorem step_keeps_chips (h h' : Hand) (a : Action) (hs : step h a = .ok h') :
    h'.chips.total = h.chips.total := by
  unfold step at hs
  split at hs
  · cases hs
  split at hs
  · cases hs
  next hl =>
  split at hs
  · cases hs; exact payFold_total _ _
  · cases hs
    rw [Hand.afterMove, passTurn_total]
    exact applyMove_total _ _ (Decidable.of_not_not hl)

/-! ## Dealing a hand

`dealHand` shuffles the deck and then deals from it. Lean's kernel, when it reads a field
of `dealHand stacks button seed`, tries to run the shuffle on an unknown seed, which never
finishes. So we take `dealHand`'s own body with the shuffled deck as an input
(`dealFrom`), and let the kernel check that `dealHand stacks button seed` is exactly
`dealFrom stacks button (shuffle seed fullDeck)`. Facts about the deal are then proved for
any deck. `dealFrom` is only a proof tool; no theorem statement mentions it. -/

open Lean Meta Elab Command in
/-- Define `dealFrom` as `dealHand`'s body with the deck as an input, and prove
`dealHand_eq_dealFrom`. Both are checked by the kernel. -/
elab "#make_dealFrom" : command => liftTermElabM do
  let some (.defnInfo d) := (← getEnv).find? ``dealHand | throwError "dealHand not found"
  let value ← lambdaTelescope d.value fun xs b => do
    unless xs.size == 3 do throwError "expected 3 arguments"
    let .letE _ _ v body _ := b | throwError m!"expected a let, got {b.ctorName}"
    withLocalDeclD `deck (← inferType v) fun deck => do
      let body := body.instantiate1 deck
      if body.containsFVar xs[2]!.fvarId! then throwError "the body uses the seed"
      mkLambdaFVars #[xs[0]!, xs[1]!, deck] body
  let type ← inferType value
  addDecl (.defnDecl (mkDefinitionValEx `dealFrom [] type value d.hints .safe [`dealFrom]))
  let (eqType, eqProof) ← lambdaTelescope d.value fun xs b => do
    let .letE _ _ v _ _ := b | throwError "expected a let"
    let lhs := mkAppN (mkConst ``dealHand) xs
    let rhs := mkApp3 (mkConst `dealFrom) xs[0]! xs[1]! v
    return (← mkForallFVars xs (← mkEq lhs rhs), ← mkLambdaFVars xs (← mkEqRefl lhs))
  addDecl (.thmDecl (mkTheoremValEx `dealHand_eq_dealFrom [] eqType eqProof []))

#make_dealFrom

/-- Dealing from any deck: the blinds move from the stacks to the bets. -/
theorem dealFrom_chips (stacks : Player → Nat) (button : Player) (d : List Card) :
    (dealFrom stacks button d).chips =
      { stack := fun p => if p = button then stacks p - min smallBlind (stacks button)
                          else stacks p - min bigBlind (stacks (other button))
        pot := 0
        bet := fun p => if p = button then min smallBlind (stacks button)
                        else min bigBlind (stacks (other button))
        lastRaise := bigBlind
        toAct := button } := by
  rcases d with _ | ⟨a, _ | ⟨b, _ | ⟨c, _ | ⟨e, rest⟩⟩⟩⟩ <;> rfl

/-- A hand that was just dealt is not over. -/
theorem dealFrom_ended (stacks : Player → Nat) (button : Player) (d : List Card) :
    (dealFrom stacks button d).ended = none := by
  rcases d with _ | ⟨a, _ | ⟨b, _ | ⟨c, _ | ⟨e, rest⟩⟩⟩⟩ <;> rfl

/-- Dealing a hand keeps the chips the players brought: the blinds only move chips from
the stacks to the bets, and a player short of a blind puts in all they have. -/
theorem dealHand_total (stacks : Player → Nat) (button : Player) (seed : Nat) :
    (dealHand stacks button seed).chips.total = stacks 0 + stacks 1 := by
  rw [dealHand_eq_dealFrom, dealFrom_chips]
  have hsb := Nat.min_le_right smallBlind (stacks button)
  have hbb := Nat.min_le_right bigBlind (stacks (other button))
  simp only [State.total]
  match button with
  | ⟨0, _⟩ => simp [other] at *; omega
  | ⟨1, _⟩ => simp [other] at *; omega

/-- A new hand holds exactly the chips the two players brought to it. -/
theorem startHand_keeps_chips (stacks : Player → Nat) (button : Player) (seed : Nat) :
    (startHand stacks button seed).chips.total = stacks 0 + stacks 1 := by
  rw [startHand, passTurn_total, dealHand_total]

/-! ## Across a whole game -/

/-- When a hand is over, all chips are back in the stacks: the pot and both bets are 0. -/
def Hand.Settled (h : Hand) : Prop :=
  h.ended.isSome → h.chips.pot = 0 ∧ h.chips.bet 0 = 0 ∧ h.chips.bet 1 = 0

theorem finishStreet_settled (fuel : Nat) (h : Hand) (hn : h.ended = none) :
    (h.finishStreet fuel).Settled := by
  induction fuel generalizing h with
  | zero => simp [Hand.finishStreet, Hand.Settled, hn]
  | succ fuel ih =>
    simp only [Hand.finishStreet]
    split
    · intro _; simp [Hand.payShowdown, collectBets]
    · split
      · intro he; simp [Hand.dealBoard, hn] at he
      · exact ih _ (by simpa [Hand.dealBoard] using hn)

theorem passTurn_settled (h : Hand) (first : Player) (hn : h.ended = none) :
    (h.passTurn first).Settled := by
  unfold Hand.passTurn
  split
  · intro he; simp_all
  · exact finishStreet_settled _ _ hn

theorem step_settled (h h' : Hand) (a : Action) (hs : step h a = .ok h') : h'.Settled := by
  unfold step at hs
  split at hs
  · cases hs
  next hn =>
  have hn : h.ended = none := by simpa using hn
  split at hs
  · cases hs
  split at hs
  · cases hs; intro _; simp [Hand.payFold]
  · cases hs; exact passTurn_settled _ _ (by simpa using hn)

theorem startHand_settled (stacks : Player → Nat) (button : Player) (seed : Nat) :
    (startHand stacks button seed).Settled :=
  passTurn_settled _ _ (by rw [dealHand_eq_dealFrom]; exact dealFrom_ended _ _ _)

theorem act_hand {g g' : Game} {a : Action} (hs : g.act a = .ok g') :
    step g.hand a = .ok g'.hand := by
  simp only [Game.act, bind, Except.bind, pure, Except.pure] at hs
  split at hs
  · cases hs
  · cases hs; assumption

theorem nextHand_hand {g g' : Game} (hs : g.nextHand = .ok g') :
    g.hand.ended.isSome ∧
    g'.hand = startHand g.hand.chips.stack (other g.hand.button) (handSeed g.seed (g.handNo + 1)) := by
  unfold Game.nextHand at hs
  split at hs
  · cases hs
  next hn =>
  split at hs
  · cases hs
  · cases hs; exact ⟨by cases hx : g.hand.ended <;> simp_all, rfl⟩

/-- Every game the engine can reach holds 1,000 chips, and its hand is settled if over. -/
theorem reachable_total (g : Game) (hg : g.Reachable) :
    g.hand.chips.total = 1000 ∧ g.hand.Settled := by
  induction hg with
  | start seed =>
    exact ⟨by rw [newGame, startHand_keeps_chips]; rfl, startHand_settled _ _ _⟩
  | act a _ hs ih =>
    have := act_hand hs
    exact ⟨by rw [step_keeps_chips _ _ _ this]; exact ih.1, step_settled _ _ _ this⟩
  | nextHand _ hs ih =>
    obtain ⟨he, hh⟩ := nextHand_hand hs
    obtain ⟨hp, h0, h1⟩ := ih.2 he
    refine ⟨?_, ?_⟩
    · rw [hh, startHand_keeps_chips, ← ih.1]; simp only [State.total]; omega
    · rw [hh]; exact startHand_settled _ _ _

/-- In every game the engine can reach, there are always exactly 1,000 chips. -/
theorem chips_always_1000 (g : Game) (hg : g.Reachable) : g.hand.chips.total = 1000 :=
  (reachable_total g hg).1

/-! ## Checks -/

-- The hypothesis of `step_keeps_chips` can hold: a real move on a real deal is accepted,
-- and the total stays at 1,000.
#guard match step (startHand (fun _ => startingStack) 0 7) .call with
  | .ok h' => h'.chips.total == 1000
  | .error _ => false

/-- The property rejects a bad outcome: if one extra chip appears in player 0's stack,
the total is no longer the same. -/
example (s : State) :
    ({ s with stack := setFor s.stack 0 (s.stack 0 + 1) } : State).total ≠ s.total := by
  have := setFor_sum s.stack 0 (s.stack 0 + 1)
  simp only [State.total]; omega

-- The same check on a real hand: one extra chip makes the total 1,001, not 1,000.
#guard let s := (startHand (fun _ => startingStack) 0 7).chips
  ({ s with stack := setFor s.stack 0 (s.stack 0 + 1) } : State).total == 1001

/-- `chips_always_1000` applies to a real game: a new game from seed 7 is reachable. -/
example : (newGame 7).hand.chips.total = 1000 := chips_always_1000 _ (.start 7)

#print axioms step_keeps_chips
#print axioms startHand_keeps_chips
#print axioms chips_always_1000
