import Engine.Proofs
import Engine.Proofs.Reachable

/-!
# T3: only legal moves are accepted (the engine half)

The engine checks the spec's own `Legal` rule before it changes anything. These theorems
show that this check is always applied:

- a move the engine accepts is legal;
- an illegal move in a hand that is still going is rejected with "illegal move";
- in every game the engine can reach, the player whose turn it is may act.

The bot half (the bot only picks legal moves) is in `Engine/Proofs/BotLegal.lean`.
-/

/-- If the engine accepts a move, the move is legal under the rules. -/
theorem accepted_move_is_legal (h h' : Hand) (a : Action) (hs : step h a = .ok h') :
    Legal h.chips a := by
  unfold step at hs
  by_cases hl : Legal h.chips a
  · exact hl
  · split at hs <;> simp_all

/-- If the hand is still going and a move is illegal, the engine rejects it with the
message "illegal move" and gives back no new hand. -/
theorem illegal_move_rejected (h : Hand) (a : Action) (hnot : h.ended = none)
    (hbad : ¬ Legal h.chips a) : step h a = .error "illegal move" := by
  unfold step
  simp [hnot, hbad]

/-- A move in a game is a move in its current hand: if the game accepts it, the hand's
`step` accepted it and the game now holds the new hand. -/
theorem Game.act_ok {g g' : Game} {a : Action} (hs : g.act a = .ok g') :
    step g.hand a = .ok g'.hand := by
  unfold Game.act at hs
  cases hstep : step g.hand a with
  | error e => simp [hstep, bind, Except.bind] at hs
  | ok h' =>
    simp [hstep, bind, Except.bind, pure, Except.pure] at hs
    subst hs
    rfl

/-- Starting the next hand deals a new hand with `startHand`. -/
theorem Game.nextHand_ok {g g' : Game} (hs : g.nextHand = .ok g') :
    ∃ stacks button seed, g'.hand = startHand stacks button seed := by
  unfold Game.nextHand at hs
  split at hs
  · cases hs
  split at hs
  · cases hs
  cases hs
  exact ⟨_, _, _, rfl⟩

/-- In every game the engine can reach, if the hand is not over, the player whose turn it
is is allowed to act: they have chips and have not bet more than the other player. -/
theorem player_to_act_may_act (g : Game) (hg : g.Reachable) (hnot : g.hand.ended = none) :
    g.hand.chips.MayAct := by
  have ok : g.hand.ended.isSome ∨ g.hand.chips.MayAct := by
    cases hg with
    | start seed => exact startHand_turn_ok _ _ _
    | act a _ hs => exact step_turn_ok _ _ a (Game.act_ok hs)
    | nextHand _ hs =>
      obtain ⟨stacks, button, seed, e⟩ := Game.nextHand_ok hs
      rw [e]; exact startHand_turn_ok _ _ _
  rcases ok with done | may
  · simp [hnot] at done
  · exact may

/-! ## Checks

The hypotheses can hold on a real game, and the statements reject bad behaviour. -/

-- A real legal move (a call by the button before the flop) is accepted.
#guard match step (startHand (fun _ => startingStack) 0 7) .call with
  | .ok _ => true
  | .error _ => false

-- A real illegal move is rejected with the message the player sees: raising to 5 chips
-- when the other player has already bet 10.
#guard match step (startHand (fun _ => startingStack) 0 7) (.raiseTo 5) with
  | .ok _ => false
  | .error msg => msg == "illegal move"

-- The new hand is still going and its player to act may act, so every hypothesis of
-- `illegal_move_rejected` and `player_to_act_may_act` holds on a real game.
#guard (newGame 7).hand.ended.isNone && decide (newGame 7).hand.chips.MayAct

/-- A bad engine that accepted an illegal move would break `accepted_move_is_legal`: the
raise to 5 is not legal in a new hand, so no engine satisfying the theorem may accept it. -/
example : ¬ Legal (startHand (fun _ => startingStack) 0 7).chips (.raiseTo 5) := by
  decide

#print axioms accepted_move_is_legal
#print axioms illegal_move_rejected
#print axioms player_to_act_may_act
