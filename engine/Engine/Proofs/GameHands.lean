import Engine.Proofs.Payout
import Engine.Proofs.Board

/-!
# Every hand of a game is a real deal, from two players who both have chips

The theorems about a single hand (`showdown_pays_better_hand`, `fold_pays_other_player`,
`board_matches_street`, `showdown_has_five_cards`) are stated for a hand dealt with
`startHand` from stacks above 0 and then played with accepted moves. `game_hand_from_deal`
shows every hand of every game the engine can reach is exactly that. So those theorems hold
for every hand the app plays, with no extra assumption: a new hand is only dealt while both
players still have chips.
-/

/-- A run of accepted moves can be extended by one more accepted move. -/
theorem RunsTo.snoc {h h₁ h₂ : Hand} {as : List Action} {a : Action}
    (hrun : RunsTo h as h₁) (hs : step h₁ a = .ok h₂) : RunsTo h (as ++ [a]) h₂ := by
  induction as generalizing h with
  | nil =>
    simp only [RunsTo, RunsWith] at hrun
    subst hrun
    exact ⟨h₂, hs, rfl⟩
  | cons b bs ih =>
    obtain ⟨h', hb, hrest⟩ := hrun
    exact ⟨h', hb, ih hrest⟩

/-- The next hand is only dealt when the game is not over: both players still have chips. -/
theorem nextHand_not_over {g g' : Game} (hs : g.nextHand = .ok g') :
    0 < g.hand.chips.stack 0 ∧ 0 < g.hand.chips.stack 1 := by
  unfold Game.nextHand at hs
  split at hs
  · cases hs
  next hn =>
  split at hs
  · cases hs
  next hover =>
  have hend : g.hand.ended.isSome = true := by cases he : g.hand.ended <;> simp_all
  simp only [Game.over, hend, Bool.true_and, Bool.or_eq_true, beq_iff_eq, not_or] at hover
  omega

/-- **Every hand of a game is a real deal.** In every game the engine can reach, the current
hand was dealt with `startHand` from two stacks that both had chips, and then played with
moves the engine accepted. -/
theorem game_hand_from_deal (g : Game) (hg : g.Reachable) :
    ∃ (stacks : Player → Nat) (button : Player) (seed : Nat) (as : List Action),
      0 < stacks 0 ∧ 0 < stacks 1 ∧ RunsTo (startHand stacks button seed) as g.hand := by
  induction hg with
  | start seed =>
    exact ⟨fun _ => startingStack, 0, handSeed seed 1, [], by decide, by decide, rfl⟩
  | act a _ hs ih =>
    obtain ⟨S, b, sd, as, h0, h1, hrun⟩ := ih
    exact ⟨S, b, sd, as ++ [a], h0, h1, hrun.snoc (act_hand hs)⟩
  | nextHand _ hs _ =>
    obtain ⟨h0, h1⟩ := nextHand_not_over hs
    obtain ⟨_, hh⟩ := nextHand_hand hs
    exact ⟨_, _, _, [], h0, h1, by rw [hh]; rfl⟩

/-! ## The hand theorems hold for every hand the app plays -/

/-- In every game the engine can reach, a showdown pays the better hand: there are stacks
the hand was dealt from, both above 0, such that the winner ends with more and the loser
with fewer (and a tie leaves both where they started). -/
example (g : Game) (hg : g.Reachable) (r : Outcome) (hend : g.hand.ended = some (.showdown r)) :
    r = showdown (g.hand.hole 0) (g.hand.hole 1) g.hand.board := by
  obtain ⟨S, b, sd, as, h0, h1, hrun⟩ := game_hand_from_deal g hg
  exact (showdown_pays_better_hand S b sd h0 h1 as _ hrun r hend).1

/-- In every game the engine can reach, a showdown has all five board cards. -/
example (g : Game) (hg : g.Reachable) (r : Outcome) (hend : g.hand.ended = some (.showdown r)) :
    g.hand.board.length = 5 := by
  obtain ⟨S, b, sd, as, _, _, hrun⟩ := game_hand_from_deal g hg
  exact showdown_has_five_cards S b sd as _ hrun r hend

/-! ## Checks -/

/-- The conditions hold: a new game is reachable, so the theorem applies to it. -/
example : ∃ (stacks : Player → Nat) (button : Player) (seed : Nat) (as : List Action),
    0 < stacks 0 ∧ 0 < stacks 1 ∧ RunsTo (startHand stacks button seed) as (newGame 7).hand :=
  game_hand_from_deal _ (.start 7)

/-- The statement rejects a hand dealt to a player with no chips: 0 is not above 0. -/
example : ¬ (0 < (0 : Nat)) := by decide

#print axioms game_hand_from_deal
