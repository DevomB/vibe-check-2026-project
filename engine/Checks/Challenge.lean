import Engine.Proofs.Reachable
import Engine.Proofs.RiskSpec
import Engine.Proofs.BotSpec
import Engine.Proofs.EquitySpec

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

/-! ## Risk: the bot follows its Risk setting (see `Engine/Proofs/RiskSpec.lean`) -/

/-- The bot's call rule calls exactly when the call, weighted by Risk, is worth at least as
much as folding. -/
theorem callPays_iff_takes (c : Counts) (pot toCall risk : Nat) (h : toCall ≤ pot) :
    callPays c pot toCall risk = true ↔ (callGamble c pot toCall).Takes risk := sorry

/-- If the bot calls, the call is worth it at the bot's Risk. -/
theorem bot_calls_only_when_worth_it (v : View) (c : Counts) (h : v.toCall ≤ v.pot)
    (hcall : (decideView v c).action = .call) :
    (callGamble c v.pot v.toCall).Takes v.sliders.risk := sorry

/-- If the bot folds, the call is not worth it at the bot's Risk. -/
theorem bot_folds_only_when_not_worth_it (v : View) (c : Counts) (h : v.toCall ≤ v.pot)
    (hfold : (decideView v c).action = .fold) :
    ¬ (callGamble c v.pot v.toCall).Takes v.sliders.risk := sorry

/-- For any gamble, if a bot with more Risk takes it, a bot with less Risk takes it too. -/
theorem more_risk_takes_fewer_gambles (g : Gamble) {r₁ r₂ : Nat} (hr : r₁ ≤ r₂)
    (h : g.Takes r₂) : g.Takes r₁ := sorry

/-- A gamble that can never lose is taken at every Risk. -/
theorem no_loss_always_taken (g : Gamble) (risk : Nat) (h : ∀ o ∈ g, 0 ≤ o.2) :
    g.Takes risk := sorry

/-! ## T3 (bot half) and T4: the slider bot (see `Engine/Proofs/BotSpec.lean`) -/

/-- Whenever the player to act may act at all, the slider bot's move is legal, for every
slider setting, seed, hole cards and board. -/
theorem botDecide_legal (sl : Sliders) (seed : Nat) (hole board : List Card) :
    AlwaysLegal fun s => (botDecide sl seed hole board s).action := sorry

/-- For one spot (same state, counts, cards and Bluff): if the bot calls or raises at some
Risk, it also calls or raises at every lower Risk. -/
theorem risk_monotone (bluff : Nat) (c : Counts) (hole board : List Card) (s : State) :
    RiskMonotone fun r => (decideWithCounts ⟨r, bluff⟩ c hole board s).action := sorry

/-- The same for the whole bot, counts included: the counts have no Risk input. -/
theorem botDecide_risk_monotone (bluff seed : Nat) (hole board : List Card) (s : State) :
    RiskMonotone fun r => (botDecide ⟨r, bluff⟩ seed hole board s).action := sorry

/-! ## T6: the exact counts look at every outcome once (see `Engine/Proofs/EquitySpec.lean`) -/

/-- On the river and the turn, every entry of the list the bot counts over is an outcome that
can happen, every outcome that can happen is listed exactly once, and the counts are the
spec's `showdown` results over that list. -/
theorem enumeration_exact (hole board : List Card) :
    ((∀ h ∈ riverOpponentHands hole board, ∃ a b, h = [a, b] ∧ OpponentCanHold hole board a b) ∧
     (∀ a b, OpponentCanHold hole board a b → timesListed (riverOpponentHands hole board) a b = 1) ∧
     riverCounts hole board =
      countResults ((riverOpponentHands hole board).map fun opp => showdown hole opp board)) ∧
    ((∀ o ∈ turnOutcomes hole board,
       ∃ r a b, o = (r, [a, b]) ∧ TurnOutcomePossible hole board r a b) ∧
     (∀ r a b, TurnOutcomePossible hole board r a b →
       timesListedTurn (turnOutcomes hole board) r a b = 1) ∧
     turnCounts hole board =
      countResults ((turnOutcomes hole board).map fun o => showdown hole o.2 (board ++ [o.1]))) :=
  sorry

/-- With two hole cards and five board cards, all different, the opponent can hold 990 hands. -/
theorem riverOpponentHands_length {hole board : List Card} (h2 : hole.length = 2)
    (h5 : board.length = 5) (hd : (hole ++ board).Nodup) :
    (riverOpponentHands hole board).length = 990 := sorry

/-- With two hole cards and four board cards, all different, there are 45,540 turn outcomes. -/
theorem turnOutcomes_length {hole board : List Card} (h2 : hole.length = 2)
    (h4 : board.length = 4) (hd : (hole ++ board).Nodup) :
    (turnOutcomes hole board).length = 45540 := sorry

/-- On the river, the counts the bot uses are the river counts above. -/
theorem countsFor_river {seed : Nat} {hole board : List Card} (h : board.length = 5) :
    countsFor seed hole board = riverCounts hole board := sorry

/-- On the turn, the counts the bot uses are the turn counts above. -/
theorem countsFor_turn {seed : Nat} {hole board : List Card} (h : board.length = 4) :
    countsFor seed hole board = turnCounts hole board := sorry
