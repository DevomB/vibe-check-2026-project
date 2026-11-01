import Engine.Proofs.Session

/-!
# The game can never freeze

In every game the engine can reach, while the hand is not over, the player whose turn it is
always has a legal move, and the engine accepts it. So a hand can never get stuck; with
`bot_move_accepted` (the engine always accepts the bot's move) and `every_hand_ends` (every
hand ends within 200 moves), neither can the bot's turn. Dealing the next hand is a separate
command, covered by `handle_keeps_reachable`, not by this theorem.
-/

/-- **The game can never freeze.** In every game the engine can reach, while the hand is not
over, there is a legal move for the player to act, and the engine accepts it. (The proof
uses folding.) -/
theorem game_never_freezes (g : Game) (hg : g.Reachable) (hnot : g.hand.ended = none) :
    ∃ a, Legal g.hand.chips a ∧ ∃ h', step g.hand a = .ok h' := by
  have hmay := player_to_act_may_act g hg hnot
  have hfold : Legal g.hand.chips .fold := ⟨hmay, trivial⟩
  exact ⟨.fold, hfold, legal_move_accepted _ _ hnot hfold⟩

/-! ## Checks -/

/-- The conditions can hold: a new game is reachable and its first hand is not over, so the
theorem gives a legal move the engine accepts. -/
example : ∃ a, Legal (newGame 7).hand.chips a ∧ ∃ h', step (newGame 7).hand a = .ok h' :=
  game_never_freezes _ (.start 7) rfl

/-- The "hand is not over" condition is needed: once a hand has ended, the real `step` refuses
every move, so no accepted move exists. -/
example (h : Hand) (r : HandEnd) (hend : h.ended = some r) (a : Action) :
    ¬ ∃ h', step h a = .ok h' := by
  intro ⟨h', hok⟩
  simp [step, hend] at hok

#print axioms game_never_freezes
