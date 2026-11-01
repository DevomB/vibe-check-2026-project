import Engine.Proofs.Session

/-!
# The game can never freeze

In every game the engine can reach, while the hand is not over, the player whose turn it is
always has a legal move, and the engine accepts it. With `every_hand_ends` (every hand ends
within 200 moves), this means a game can never get stuck.
-/

/-- **The game can never freeze.** In every game the engine can reach, while the hand is not
over, there is a legal move for the player to act (folding is always one), and the engine
accepts it. -/
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

/-- The statement rejects a stuck game: an engine that refused every move (always an error)
has no accepted move. -/
example : ¬ ∃ (a : Action) (h' : Hand),
    (fun (_ : Action) => (Except.error "stuck" : Except String Hand)) a = .ok h' := by
  intro ⟨_, _, h⟩; cases h

#print axioms game_never_freezes
