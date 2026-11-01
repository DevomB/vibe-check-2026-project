import Engine.Proofs.Reachable
import Engine.Proofs.RiskSpec
import Engine.Proofs.BotSpec
import Engine.Proofs.EquitySpec
import Engine.Proofs.BluffSpec
import Engine.Proofs.ReviewSpec
import Engine.Proofs.EndsSpec

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

/-! ## T7: the river betting set has as many bluffs as Bluff asks for
(see `Engine/Proofs/BluffSpec.lean`) -/

/-- On a river board (five different cards), at any Bluff setting `b` from 0 to 60, the bot's
river betting set has 324 value hands, and its number of bluffs is the whole number nearest to
324 × b / (100 − b), halves up: the number that makes bluffs b% of the set. -/
theorem bluff_frequency (bluffPct : Nat) (board : List Card) (h5 : board.length = 5)
    (hd : board.Nodup) (hb : bluffPct ≤ 60) :
    (riverBettingSet bluffPct board).value.length = 324 ∧
    NearestWhole (riverBettingSet bluffPct board).bluffs.length (324 * bluffPct)
      (100 - bluffPct) := sorry

/-- On a river board, at any Bluff setting from 0 to 60, no hand is both a value hand and a
bluff. -/
theorem value_and_bluffs_apart (bluffPct : Nat) (board : List Card) (h5 : board.length = 5)
    (hd : board.Nodup) (hb : bluffPct ≤ 60) :
    ∀ h ∈ (riverBettingSet bluffPct board).value, h ∉ (riverBettingSet bluffPct board).bluffs :=
  sorry

/-- The bot's river role (`riverRole`: with no bet to face, the slider bot bets on value or
bluff and checks on check) is value or bluff for the hole cards `a`, `b` exactly when they are
one of the value hands or one of the bluffs in the river betting set, in either order. -/
theorem bot_bets_its_set (bluffPct : Nat) (board : List Card) (a b : Card) :
    riverRole bluffPct board [a, b] ≠ RiverRole.check ↔
      ∃ h ∈ (riverBettingSet bluffPct board).value ++ (riverBettingSet bluffPct board).bluffs,
        h.cards = (a, b) ∨ h.cards = (b, a) := sorry

/-- T7, the link to the bot: on the river (five board cards), with nothing to call and some
bet legal, the slider bot `botDecide` bets (its move is a `raiseTo`) exactly when its two
cards `a`, `b` are a value hand or a designated bluff of `riverBettingSet` at its Bluff
setting, in either order; and it checks exactly when they are not. -/
theorem botDecide_river_follows_set (sl : Sliders) (seed : Nat) (a b : Card)
    (board : List Card) (s : State) (h5 : board.length = 5) (h0 : s.toCall = 0)
    (hbet : ∃ n, Legal s (.raiseTo n)) :
    ((∃ n, (botDecide sl seed [a, b] board s).action = .raiseTo n) ↔
      ∃ h ∈ (riverBettingSet sl.bluffPct board).value ++ (riverBettingSet sl.bluffPct board).bluffs,
        h.cards = (a, b) ∨ h.cards = (b, a)) ∧
    ((botDecide sl seed [a, b] board s).action = .check ↔
      ¬ ∃ h ∈ (riverBettingSet sl.bluffPct board).value ++ (riverBettingSet sl.bluffPct board).bluffs,
        h.cards = (a, b) ∨ h.cards = (b, a)) := sorry

/-- T7: `rankRiverHands`, which the betting set is cut from, lists the candidate hands
strongest first: every hand ranks above every hand after it (`RanksAbove`: a higher showdown
score, or the same score and lower card IDs, as MVP §5 asks). -/
theorem rankRiverHands_sorted (board : List Card) :
    (rankRiverHands board).Pairwise RanksAbove := sorry

/-! ## T5 and T8: the river review (see `Engine/Proofs/ReviewSpec.lean`) -/

/-- When the bot can hold at least one hand, the review's worth of calling is the spec's
total for calling over twice the number of hands, in big blinds. Folding is worth 0. -/
theorem review_worth (spot : RiverSpot) (choice : RiverChoice) (hn : spot.botHands ≠ []) :
    (reviewRiver spot choice).worthCall =
      ⟨spot.total .call, 2 * spot.botHands.length * bigBlind⟩ ∧
    (reviewRiver spot choice).worthFold.num = spot.total .fold := sorry

/-- T5: what a choice lost is the better choice's total minus its own, and its denominator is
the same as the worths' (`review_worth`), so it is in big blinds too. With `review_worth`,
this ties the `.lost` field that `review_label_monotone` reads to the chips really lost. -/
theorem review_lost (spot : RiverSpot) (choice : RiverChoice) :
    (reviewRiver spot choice).lost.num =
      max (spot.total .call) (spot.total .fold) - spot.total choice ∧
    (reviewRiver spot choice).lost.den = (reviewRiver spot choice).worthCall.den := sorry

/-- T5: the review labels a call or fold Best exactly when it was worth at least as much as
the other choice. -/
theorem review_best_iff (spot : RiverSpot) (choice : RiverChoice) :
    (reviewRiver spot choice).label = .best ↔ spot.total choice.other ≤ spot.total choice :=
  sorry

/-- T5: a decision that lost fewer big blinds never gets a worse label. -/
theorem review_label_monotone (s₁ s₂ : RiverSpot) (c₁ c₂ : RiverChoice)
    (hle : (reviewRiver s₁ c₁).lost.LE (reviewRiver s₂ c₂).lost) :
    (reviewRiver s₁ c₁).label.rank ≤ (reviewRiver s₂ c₂).label.rank := sorry

/-- Calling is Best exactly when the equity the human had is at least the equity needed. -/
theorem review_call_best_iff_equity (spot : RiverSpot) (hn : spot.botHands ≠ [])
    (hcost : 0 < spot.cost) :
    (reviewRiver spot .call).label = .best ↔
      (reviewRiver spot .call).equityNeeded.LE (reviewRiver spot .call).equityHad := sorry

/-- T8: two hands that look the same to the human get the same review, whatever cards the
bot really holds. -/
theorem no_hindsight (h₁ h₂ : Hand) (bluffPct : Nat) (choice : RiverChoice)
    (hsame : SameForHuman h₁ h₂) :
    reviewRiver (riverSpotOf h₁ bluffPct) choice =
      reviewRiver (riverSpotOf h₂ bluffPct) choice := sorry

/-- The bot's real hand is one of the hands the review considers. -/
theorem bot_hand_in_review (spot : RiverSpot) (botCards : List Card)
    (hbets : riverBets spot.bluffPct spot.board botCards = true)
    (hapart : ∀ c ∈ botCards, c ∉ spot.hole) :
    ∃ h ∈ spot.botHands, h.isHole botCards = true := sorry

/-- When the human, to act in `h`, faces the bot's opening river bet (the bot's move, with
its own cards on this board and nothing to call, was a bet) and no card was dealt twice, the
review's list of hands the bot can hold is not empty: the bot's real hand is in it. -/
theorem review_hands_ne_nil (h : Hand) (sl : Sliders) (seed n : Nat) (s : State)
    (h5 : h.board.length = 5) (h0 : s.toCall = 0)
    (hbet : (botDecide sl seed (h.hole (other h.chips.toAct)) h.board s).action = .raiseTo n)
    (hnd : h.dealtCards.Nodup) :
    (riverSpotOf h sl.bluffPct).botHands ≠ [] := sorry

/-! ## T9: every hand ends (see `Engine/Proofs/EndsSpec.lean`) -/

/-- T9: from any game the engine can reach, every run of accepted moves (`RunsTo`) has at
most 200 moves, the bot loop's `botFuel`. So no hand goes on forever. -/
theorem every_hand_ends (g : Game) (hg : g.Reachable) (as : List Action) (h' : Hand)
    (hrun : RunsTo g.hand as h') : as.length ≤ 200 := sorry
