import Engine.Proofs.Reachable

/-!
# The main theorems, as agreed by the team (the Comparator "challenge")

This file holds only the statements. The proofs are in `Engine/Proofs/`, and
`Checks/Solution.lean` collects them. `lake comparator` checks that every theorem named
in `comparator.json` is proved with exactly the statement written here, using only the
standard axioms.

Do not change a statement to make a proof easier. Change one only if the team agrees
that the statement itself was wrong.
-/

/-! ## T1: chips are never created or destroyed -/

/-- After any accepted move, the chips in the stacks, the pot and the bets add up to the
same number as before. -/
theorem step_keeps_chips (h h' : Hand) (a : Action) (hs : step h a = .ok h') :
    h'.chips.total = h.chips.total := sorry

/-- A new hand holds exactly the chips the two players brought to it. -/
theorem startHand_keeps_chips (stacks : Player → Nat) (button : Player) (seed : Nat) :
    (startHand stacks button seed).chips.total = stacks 0 + stacks 1 := sorry

/-- In every game the engine can reach, there are always exactly 1,000 chips. -/
theorem chips_always_1000 (g : Game) (hg : g.Reachable) : g.hand.chips.total = 1000 := sorry

/-! ## T2: no card is dealt twice -/

/-- The shuffle only changes the order of the cards: nothing is added, lost or copied. -/
theorem shuffle_same_cards {α : Type} (seed : Nat) (l : List α) : (shuffle seed l).Perm l :=
  sorry

/-- Every shuffled deck is fair: it has the 52 cards of a new deck, in some order. -/
theorem shuffle_fair (seed : Nat) : FairDeck (shuffle seed fullDeck) := sorry

/-- In every game the engine can reach, the cards on the table (both players' hidden cards
and the shared cards) are all different, and all come from the 52-card deck. -/
theorem no_card_dealt_twice (g : Game) (hg : g.Reachable) :
    g.hand.dealtCards.Nodup ∧ ∀ c ∈ g.hand.dealtCards, c ∈ fullDeck := sorry

/-! ## T3: only legal moves are accepted -/

/-- If the engine accepts a move, the move is legal under the rules. -/
theorem accepted_move_is_legal (h h' : Hand) (a : Action) (hs : step h a = .ok h') :
    Legal h.chips a := sorry

/-- If the hand is still going and a move is illegal, the engine rejects it with the
message "illegal move" and gives back no new hand. -/
theorem illegal_move_rejected (h : Hand) (a : Action) (hnot : h.ended = none)
    (hbad : ¬ Legal h.chips a) : step h a = .error "illegal move" := sorry

/-- In every game the engine can reach, if the hand is not over, the player whose turn it
is is allowed to act: they have chips and have not bet more than the other player. -/
theorem player_to_act_may_act (g : Game) (hg : g.Reachable) (hnot : g.hand.ended = none) :
    g.hand.chips.MayAct := sorry
