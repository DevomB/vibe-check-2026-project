import Engine.Proofs.Reachable
import Engine.Proofs.RiskSpec
import Engine.Proofs.BotSpec
import Engine.Proofs.EquitySpec
import Engine.Proofs.BluffSpec
import Engine.Proofs.ReviewSpec
import Engine.Proofs.BluffCatcherSpec
import Engine.Proofs.EquilibriumSpec
import Engine.Proofs.EndsSpec
import Engine.Proofs.BoardSpec
import Engine.Protocol

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

/-! ## T1b: the right player wins the pot (see `Engine/Proofs/Payout.lean`)

T1 says no chip is created or destroyed; paying the pot to the loser would also keep the
total. These say who gets the chips. -/

/-- At a showdown, the better hand wins the pot. Deal a hand from stacks `S` (both above 0)
and play any accepted moves. If the hand ends at a showdown with result `r`, then `r` is the
spec's `showdown` on the players' real cards and the board; the winner ends the hand with
more chips than they started it with and the loser with fewer; and on a tie both end with
exactly what they started with. -/
theorem showdown_pays_better_hand (S : Player → Nat) (button : Player) (seed : Nat)
    (h0 : 0 < S 0) (h1 : 0 < S 1) (as : List Action) (h' : Hand)
    (hrun : RunsTo (startHand S button seed) as h') (r : Outcome)
    (hend : h'.ended = some (.showdown r)) :
    r = showdown (h'.hole 0) (h'.hole 1) h'.board ∧
    (r = .player0 → S 0 < h'.chips.stack 0 ∧ h'.chips.stack 1 < S 1) ∧
    (r = .player1 → S 1 < h'.chips.stack 1 ∧ h'.chips.stack 0 < S 0) ∧
    (r = .tie → h'.chips.stack 0 = S 0 ∧ h'.chips.stack 1 = S 1) := sorry

/-- A fold pays the other player. Deal a hand from stacks `S` (both above 0) and play any
accepted moves. If the hand ends with `w` recorded as the winner of a fold, then `w` ends
the hand with more chips than they started it with, and the other player with fewer. -/
theorem fold_pays_other_player (S : Player → Nat) (button : Player) (seed : Nat)
    (h0 : 0 < S 0) (h1 : 0 < S 1) (as : List Action) (h' : Hand)
    (hrun : RunsTo (startHand S button seed) as h') (w : Player)
    (hend : h'.ended = some (.folded w)) :
    S w < h'.chips.stack w ∧ h'.chips.stack (other w) < S (other w) := sorry

/-- Folding gives the hand to the other player: when the engine accepts a fold, the hand
ends and the recorded winner is the player who did not fold. -/
theorem fold_records_other_player (h h' : Hand) (hs : step h .fold = .ok h') :
    h'.ended = some (.folded (other h.chips.toAct)) := sorry

/-- Every hand of a game is a real deal: in every game the engine can reach, the current hand
was dealt with `startHand` from two stacks that both had chips, and then played with moves
the engine accepted. So the hand theorems above and below (who wins the pot, the board's
size) hold for every hand the app plays. -/
theorem game_hand_from_deal (g : Game) (hg : g.Reachable) :
    ∃ (stacks : Player → Nat) (button : Player) (seed : Nat) (as : List Action),
      0 < stacks 0 ∧ 0 < stacks 1 ∧ RunsTo (startHand stacks button seed) as g.hand := sorry

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

/-- The board matches the street: while a hand dealt with `startHand` and played with any
accepted moves is not over, the board has exactly as many cards as the street says (0 before
the flop, 3 on the flop, 4 on the turn, 5 on the river). -/
theorem board_matches_street (stacks : Player → Nat) (button : Player) (seed : Nat)
    (as : List Action) (h' : Hand) (hrun : RunsTo (startHand stacks button seed) as h')
    (hnot : h'.ended = none) : h'.board.length = h'.street.boardCards := sorry

/-- A showdown has all five board cards: if a hand dealt with `startHand` and played with any
accepted moves ends at a showdown, the board has 5 cards. -/
theorem showdown_has_five_cards (stacks : Player → Nat) (button : Player) (seed : Nat)
    (as : List Action) (h' : Hand) (hrun : RunsTo (startHand stacks button seed) as h')
    (r : Outcome) (hend : h'.ended = some (.showdown r)) : h'.board.length = 5 := sorry

/-! ## T3: only legal moves are accepted -/

/-- If the engine accepts a move, the move is legal under the rules. -/
theorem accepted_move_is_legal (h h' : Hand) (a : Action) (hs : step h a = .ok h') :
    Legal h.chips a := sorry

/-- If the hand is still going and a move is illegal, the engine rejects it with the
message "illegal move" and gives back no new hand. -/
theorem illegal_move_rejected (h : Hand) (a : Action) (hnot : h.ended = none)
    (hbad : ¬ Legal h.chips a) : step h a = .error "illegal move" := sorry

/-- The other half of T3: a legal move in a hand that is not over is always accepted. (Without
it, an engine that rejects every move would satisfy the two theorems above.) -/
theorem legal_move_accepted (h : Hand) (a : Action) (hnot : h.ended = none)
    (hl : Legal h.chips a) : ∃ h', step h a = .ok h' := sorry

/-- The buttons match the rules (`legalOptions` is what the app offers the human): Fold and
Check work exactly when they are legal; the call amount is above 0 exactly when calling is
legal, and is then what a call costs; and a raise to `n` is legal exactly when a raise range
is offered and `n` is inside it. -/
theorem legalOptions_exact (s : State) :
    ((legalOptions s).fold = true ↔ Legal s .fold) ∧
    ((legalOptions s).check = true ↔ Legal s .check) ∧
    (0 < (legalOptions s).call ↔ Legal s .call) ∧
    (Legal s .call → (legalOptions s).call = s.toCall) ∧
    (∀ n, Legal s (.raiseTo n) ↔
      ∃ lo hi, (legalOptions s).raise = some (lo, hi) ∧ lo ≤ n ∧ n ≤ hi) := sorry

/-- In every game the engine can reach, if the hand is not over, the player whose turn it
is is allowed to act: they have chips and have not bet more than the other player. -/
theorem player_to_act_may_act (g : Game) (hg : g.Reachable) (hnot : g.hand.ended = none) :
    g.hand.chips.MayAct := sorry

/-! ## Caution: the bot follows its internal caution setting, the `risk` field (see
`Engine/Proofs/RiskSpec.lean`). The player's Risk runs the other way; see the one-slider section. -/

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
internal caution (the `risk` field), it also calls or raises at every lower caution. -/
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

/-- T7: value hands are the strongest. Every value hand in the river betting set scores at
least as well as every candidate hand that is not a value hand. -/
theorem value_strongest (bluffPct : Nat) (board : List Card) :
    ∀ v ∈ (riverBettingSet bluffPct board).value, ∀ h ∈ rankRiverHands board,
      h ∉ (riverBettingSet bluffPct board).value → h.score ≤ v.score := sorry

/-- T7: bluffs are the weakest. Every bluff in the river betting set scores no better than
every candidate hand that is not a bluff. So, when the value hands and the bluffs are apart
(`value_and_bluffs_apart`), no bluff scores better than any value hand. -/
theorem bluffs_weakest (bluffPct : Nat) (board : List Card) :
    ∀ b ∈ (riverBettingSet bluffPct board).bluffs, ∀ h ∈ rankRiverHands board,
      h ∉ (riverBettingSet bluffPct board).bluffs → b.score ≤ h.score := sorry

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

/-- The review always has a hand to consider, on any river board: five different board
cards and at most two cards in the human's hand leave the bot at least one hand of its
betting set, at every Bluff setting. Unlike `review_hands_ne_nil`, this needs no bot bet. -/
theorem botHands_ne_nil_of_board (spot : RiverSpot) (h5 : spot.board.length = 5)
    (hd : spot.board.Nodup) (hhole : spot.hole.length ≤ 2) : spot.botHands ≠ [] := sorry

/-! ## T9: every hand ends (see `Engine/Proofs/EndsSpec.lean`) -/

/-- T9: from any game the engine can reach, every run of accepted moves (`RunsTo`) has at
most 200 moves, the bot loop's `botFuel`. So no hand goes on forever. -/
theorem every_hand_ends (g : Game) (hg : g.Reachable) (as : List Action) (h' : Hand)
    (hrun : RunsTo g.hand as h') : as.length ≤ 200 := sorry
/-! ## The game session the app runs (see `Engine/Proofs/Session.lean`) -/

/-- In a reachable game where the hand is not over, the engine accepts the move the slider
bot picks, for any sliders, seed and cards. -/
theorem bot_move_accepted (g : Game) (hg : g.Reachable) (hnot : g.hand.ended = none)
    (sl : Sliders) (seed : Nat) (hole board : List Card) :
    ∃ h', step g.hand (botDecide sl seed hole board g.hand.chips).action = .ok h' := sorry

/-- If the session's game is reachable (or there is no game yet), then after any command
`Session.handle` accepts, the new session's game is reachable. -/
theorem handle_keeps_reachable (cur : Option Session) (c : Command) (s' : Session)
    (hcur : ∀ s, cur = some s → s.game.Reachable)
    (hok : Session.handle cur c = .ok s') :
    s'.game.Reachable := sorry

open Lean (Json toJson) in
/-- If a request line holds a game command and `Session.handle` rejects it, `respond` keeps
the session exactly as it was, and replies with the error and the table as it was before,
with no new events. -/
theorem handle_error_unchanged (cur : Option Session) (line : String) (j : Json)
    (c : Command) (e : String) (peek : Bool) (commit : String)
    (hjson : Json.parse line = .ok j) (hreq : parseRequest j = .ok (.game c))
    (hpeek : parsePeek j = .ok peek)
    (hrej : Session.handle cur c = .error e) :
    respond cur line commit =
      (cur, Json.mkObj [("error", toJson e),
        ("state", match cur with
          | some s => stateJson { s with events := #[] } peek commit
          | none => Json.null)]) := sorry

/-- In every state, the chips the bot must add to call are at most the pot it can win. So
`bot_calls_only_when_worth_it` and `bot_folds_only_when_not_worth_it` apply to every view
the bot really gets. -/
theorem viewOf_toCall_le_pot (sl : Sliders) (hole board : List Card) (s : State) :
    (viewOf sl hole board s).toCall ≤ (viewOf sl hole board s).pot := sorry

/-! ## App protocol and review panels: integration guarantees -/

open Lean (Json toJson)

/-- The game the engine's session plays is reachable. Start with no session and answer any
request lines in order: whenever a session exists, its game is one the engine can reach. So
the reachable-game theorems (`chips_always_1000`, `no_card_dealt_twice`,
`player_to_act_may_act`, `every_hand_ends`) hold for the engine's session. -/
theorem app_game_reachable (lines : List String) (s : Session) (commit : String)
    (hs : lines.foldl (fun cur line => (respond cur line commit).1) none = some s) :
    s.game.Reachable := sorry

/-- `respond` changes the session only when `Session.handle` accepts a game command. Every
other line (bad JSON, an unknown command, a review request, a rejected command) keeps the
session exactly as it was. -/
theorem respond_keeps_session_unless_accepted (cur : Option Session) (line : String) (commit : String) :
    (respond cur line commit).1 = cur ∨
    ∃ j c s, Json.parse line = .ok j ∧ parseRequest j = .ok (.game c) ∧
      Session.handle cur c = .ok s ∧ (respond cur line commit).1 = some s := sorry

/-- The caution sweep shows the real bot. `exploreHand` is the explorer the app showed before
the one-slider change: entry `r` is the move at internal caution `r` with the game's Bluff.
For move number `i` of a hand's recorded bot moves and every `r` from 0 to 100, that entry is
exactly the action `botDecide` returns at caution `r`, with the game's Bluff and the move's
recorded seed, cards, board and betting state. (The app's explorer is `exploreHandAt`, below.) -/
theorem exploreHand_moves (sl : Sliders) (ms : List BotMoveRecord) (i r : Nat)
    (hi : i < ms.length) (hr : r ≤ 100) :
    ((exploreHand sl ms)[i]?.bind fun e => e.moves[r]?) =
      some (botDecide ⟨r, sl.bluffPct⟩ ms[i].seed ms[i].hole ms[i].board ms[i].state).action := sorry

/-- The caution sweep never goes from fold back to call. For each recorded move, if it shows
a call or raise at some caution, it shows a call or raise at every lower caution too. (Past
100 there is no entry; that counts as a fold.) -/
theorem exploreHand_risk_monotone (sl : Sliders) (ms : List BotMoveRecord) (i : Nat)
    (hi : i < ms.length) :
    RiskMonotone fun r => ((exploreHand sl ms)[i]?.bind fun e => e.moves[r]?).getD .fold := sorry

/-- The range viewer's numbers add up. The number of value hands plus bluffs in the bot's
river betting set equals the number your cards block plus the numbers of hands you beat, tie
with and lose to. -/
theorem rangeOf_adds_up (spot : RiverSpot) :
    (rangeOf spot).value + (rangeOf spot).bluffs =
      (rangeOf spot).blocked + ((rangeOf spot).beat + (rangeOf spot).tie + (rangeOf spot).lose) := sorry

/-- The range viewer's beat, tie and lose numbers are the very win, tie and loss counts the
review grades the decision with, whether you called or folded. -/
theorem rangeOf_counts (spot : RiverSpot) (choice : RiverChoice) :
    (reviewRiver spot choice).counts =
      ⟨(rangeOf spot).beat, (rangeOf spot).tie, (rangeOf spot).lose⟩ := sorry

/-! ## The one Risk slider (see `Engine/Proofs/OneSlider.lean`)

The player sets one number, Risk (0 to 100). `Sliders.ofRisk` turns it into the bot's two
internal settings: caution (the `risk` field: how heavily a lost chip counts) and Bluff. -/

/-- The Risk number the bot quotes in its reason never changes its move. (This is the link
between the theorems about `botDecide` and the app's `Session.botChoice`, which passes the
player's Risk; that link itself is in `Engine/Proofs/Session.lean`.) -/
theorem botDecide_action_shown (sl : Sliders) (seed : Nat) (hole board : List Card) (s : State)
    (shown : Option Nat) :
    (botDecide sl seed hole board s shown).action = (botDecide sl seed hole board s).action := sorry

/-- At every Risk the bluff share is at most 60, the most T7 `bluff_frequency` allows. -/
theorem ofRisk_bluff_le_60 (r : Nat) : (Sliders.ofRisk r).bluffPct ≤ 60 := sorry

/-- More Risk never bluffs less. -/
theorem ofRisk_bluff_monotone {r r' : Nat} (h : r ≤ r') :
    (Sliders.ofRisk r).bluffPct ≤ (Sliders.ofRisk r').bluffPct := sorry

/-- More Risk never weighs a lost chip more: the internal caution falls or stays. -/
theorem ofRisk_caution_antitone {r r' : Nat} (h : r ≤ r') :
    (Sliders.ofRisk r').risk ≤ (Sliders.ofRisk r).risk := sorry

/-- Facing a bet in one spot (the same seed, cards, board and chips), if the bot calls or
raises at Risk `r`, it also calls or raises at every higher Risk `r'`. -/
theorem more_risk_never_folds_a_call (seed : Nat) (hole board : List Card) (s : State)
    {r r' : Nat} (hr : r ≤ r') (hbet : 0 < s.toCall)
    (hc : (botDecide (Sliders.ofRisk r) seed hole board s).action.continues) :
    (botDecide (Sliders.ofRisk r') seed hole board s).action.continues := sorry

/-- Risk 50 is plain chip profit (caution 0) with a 33% bluff share. -/
theorem ideal_is_textbook : Sliders.ofRisk 50 = ⟨0, 33⟩ := sorry

/-- At Risk 50, on every river board with no card twice, the bot's betting set has 324 value
hands and 160 bluffs: 160 of 484 bets, the whole number of hands nearest to a 33% share. -/
theorem ideal_river_set (board : List Card) (h5 : board.length = 5) (hd : board.Nodup) :
    (riverBettingSet (Sliders.ofRisk 50).bluffPct board).value.length = 324 ∧
    (riverBettingSet (Sliders.ofRisk 50).bluffPct board).bluffs.length = 160 := sorry

/-- With no bet to face before the river, the bot reads neither setting: any two settings give
the same move. (This is why the explorer's `noBet` entries say Risk plays no part.) -/
theorem botDecide_no_bet_off_river (sl sl' : Sliders) (seed : Nat) (hole board : List Card)
    (s : State) (hc : s.toCall = 0) (h5 : board.length ≠ 5) :
    (botDecide sl seed hole board s).action = (botDecide sl' seed hole board s).action := sorry

/-- On a river board, with nothing to call and a bet allowed: if the bot bets its two cards at
one setting, it bets them at every setting with a Bluff share at least as big (and below 100).
The value hands are the same, and the bluffs only grow (see `Engine/Proofs/OneSliderRiver.lean`). -/
theorem more_bluff_never_checks_a_bet (sl sl' : Sliders) (seed : Nat) (a b : Card)
    (board : List Card) (s : State) (h5 : board.length = 5) (h0 : s.toCall = 0)
    (hbet : ∃ n, Legal s (.raiseTo n)) (hb : sl.bluffPct ≤ sl'.bluffPct)
    (hb' : sl'.bluffPct < 100)
    (hc : ∃ n, (botDecide sl seed [a, b] board s).action = .raiseTo n) :
    ∃ n, (botDecide sl' seed [a, b] board s).action = .raiseTo n := sorry

/-- The same along the slider: on a river board, with nothing to call and a bet allowed, if
the bot bets its two cards at Risk `r`, it bets them at every higher Risk `r'`. -/
theorem more_risk_never_checks_a_bet (seed : Nat) (a b : Card) (board : List Card) (s : State)
    (h5 : board.length = 5) (h0 : s.toCall = 0) (hbet : ∃ n, Legal s (.raiseTo n))
    {r r' : Nat} (hr : r ≤ r')
    (hc : ∃ n, (botDecide (Sliders.ofRisk r) seed [a, b] board s).action = .raiseTo n) :
    ∃ n, (botDecide (Sliders.ofRisk r') seed [a, b] board s).action = .raiseTo n := sorry

/-! ## The Risk explorer over the player's Risk (see `Engine/Proofs/Explain.lean`) -/

/-- The Risk explorer shows the real bot. For move number `i` of a hand's recorded bot moves
and every Risk `r` from 0 to 100, the explorer's move at Risk `r` is what `botDecide` returns
with the settings `Sliders.ofRisk r` (which `Session.start` uses for a new game at Risk `r`)
and the move's recorded seed, cards, board and betting state. -/
theorem exploreHandAt_moves (risk : Nat) (ms : List BotMoveRecord) (i r : Nat)
    (hi : i < ms.length) (hr : r ≤ 100) :
    ((exploreHandAt risk ms)[i]?.bind fun e => e.moves[r]?) =
      some (botDecide (Sliders.ofRisk r) ms[i].seed ms[i].hole ms[i].board ms[i].state).action := sorry

/-- Facing a bet, the explorer never goes from call back to fold as Risk rises: if it shows a
call or raise at Risk `r`, it shows one at every higher Risk `r'` up to 100. -/
theorem exploreHandAt_more_risk_continues (risk : Nat) (ms : List BotMoveRecord) (i : Nat)
    (hi : i < ms.length) (hbet : 0 < ms[i].state.toCall) (r r' : Nat) (hr : r ≤ r')
    (hr' : r' ≤ 100)
    (h : (((exploreHandAt risk ms)[i]?.bind fun e => e.moves[r]?).getD Action.fold).continues) :
    (((exploreHandAt risk ms)[i]?.bind fun e => e.moves[r']?).getD Action.fold).continues := sorry

/-! ## Game theory on the river: the bluff catcher (see `Engine/Proofs/BluffCatcher.lean`)

The definitions (`CatchesBluffs`, `RiverSpot.valueHands`, `RiverSpot.bluffHands`) are in
`Engine/Proofs/BluffCatcherSpec.lean`. -/

/-- **What calling is worth with a bluff catcher.** In half-chips (the review's unit), calling
wins `2 × prize` against each bluff and loses `2 × cost` against each value hand. -/
theorem bluff_catcher_call_total (mine : List Nat) (value bluffs : List RankedHand)
    (prize cost : Nat) (hc : CatchesBluffs mine value bluffs) :
    choiceTotal (value ++ bluffs) mine prize cost .call =
      2 * ((bluffs.length : Int) * prize - (value.length : Int) * cost) := sorry

/-- **When calling and folding are worth the same, for any bet.** With a bluff catcher, calling
pays `cost` chips to win `prize` chips (the pot, including the bet). Calling and folding are
worth the same exactly when bluffs × prize = value hands × cost. -/
theorem bluff_catcher_indifferent (mine : List Nat) (value bluffs : List RankedHand)
    (prize cost : Nat) (hc : CatchesBluffs mine value bluffs) :
    choiceTotal (value ++ bluffs) mine prize cost .call =
        choiceTotal (value ++ bluffs) mine prize cost .fold ↔
      bluffs.length * prize = value.length * cost := sorry

/-- **One bluff in three makes calling and folding worth the same (pot-sized bet).** The bot
bets `cost` into a pot of `cost`, so calling pays `cost` to win `2 × cost`. Then a bluff
catcher's call and fold are worth the same exactly when bluffs are one third of the bot's
bets. -/
theorem one_third_bluffs_indifferent (mine : List Nat) (value bluffs : List RankedHand)
    (cost : Nat) (hcost : 0 < cost) (hc : CatchesBluffs mine value bluffs) :
    choiceTotal (value ++ bluffs) mine (2 * cost) cost .call =
        choiceTotal (value ++ bluffs) mine (2 * cost) cost .fold ↔
      3 * bluffs.length = value.length + bluffs.length := sorry

/-- **More than one bluff in three: calling is better** (pot-sized bet, bluff catcher). -/
theorem more_bluffs_call_better (mine : List Nat) (value bluffs : List RankedHand)
    (cost : Nat) (hcost : 0 < cost) (hc : CatchesBluffs mine value bluffs) :
    choiceTotal (value ++ bluffs) mine (2 * cost) cost .fold <
        choiceTotal (value ++ bluffs) mine (2 * cost) cost .call ↔
      value.length + bluffs.length < 3 * bluffs.length := sorry

/-- **Fewer than one bluff in three: folding is better** (pot-sized bet, bluff catcher). -/
theorem fewer_bluffs_fold_better (mine : List Nat) (value bluffs : List RankedHand)
    (cost : Nat) (hcost : 0 < cost) (hc : CatchesBluffs mine value bluffs) :
    choiceTotal (value ++ bluffs) mine (2 * cost) cost .call <
        choiceTotal (value ++ bluffs) mine (2 * cost) cost .fold ↔
      3 * bluffs.length < value.length + bluffs.length := sorry

/-- **The review agrees: both choices are Best exactly at one bluff in three.** The bot opened
the river with a pot-sized bet (the pot, with the bet, is twice the bet) that you can afford,
and your hand catches bluffs against the bot hands you do not block. Then the review grades
both call and fold Best exactly when one third of those hands are bluffs. -/
theorem review_both_best_iff_one_third (spot : RiverSpot)
    (hpot : spot.pot = 2 * spot.toCall) (hafford : spot.toCall ≤ spot.stack)
    (hbet : 0 < spot.toCall)
    (hc : CatchesBluffs spot.myScore spot.valueHands spot.bluffHands) :
    ((reviewRiver spot .call).label = .best ∧ (reviewRiver spot .fold).label = .best) ↔
      3 * spot.bluffHands.length = spot.valueHands.length + spot.bluffHands.length := sorry

/-- **Risk 50 is two bluffs short of one third.** On every river board the Risk 50 set has
324 value hands and 160 bluffs. One third would need 162 bluffs (value = 2 × bluffs). -/
theorem risk50_two_bluffs_short (board : List Card) (h5 : board.length = 5)
    (hd : board.Nodup) :
    (riverBettingSet (Sliders.ofRisk 50).bluffPct board).value.length =
      2 * (riverBettingSet (Sliders.ofRisk 50).bluffPct board).bluffs.length + 4 := sorry

/-- **So at Risk 50 a bluff catcher loses a little by calling a pot-sized bet.** Against the
whole Risk 50 set (before your own cards remove any hands), calling totals `-8 × cost`
half-chips over the 484 hands: on average you lose `cost / 121` chips, under 1% of the bet. -/
theorem risk50_bluff_catcher_call_loses (board : List Card) (h5 : board.length = 5)
    (hd : board.Nodup) (mine : List Nat) (cost : Nat)
    (hc : CatchesBluffs mine (riverBettingSet (Sliders.ofRisk 50).bluffPct board).value
      (riverBettingSet (Sliders.ofRisk 50).bluffPct board).bluffs) :
    choiceTotal ((riverBettingSet (Sliders.ofRisk 50).bluffPct board).value ++
        (riverBettingSet (Sliders.ofRisk 50).bluffPct board).bluffs) mine (2 * cost) cost .call =
      -8 * (cost : Int) := sorry

/-- **No Bluff setting gives exactly one third.** Beside the 324 value hands of every river
set, no whole-number Bluff share from 0 to 60 gives 162 bluffs. -/
theorem no_bluff_setting_is_exact : ∀ b ≤ 60, 2 * bluffCount 324 b ≠ 324 := sorry

/-- **33% is the closest.** Every Bluff share from 0 to 60 is at least 4 hands away from
value = 2 × bluffs, and 33% (Risk 50) is exactly 4 away. -/
theorem bluff_33_is_closest :
    (∀ b ≤ 60, 4 ≤ ((324 : Int) - 2 * bluffCount 324 b).natAbs) ∧
      ((324 : Int) - 2 * bluffCount 324 33).natAbs = 4 := sorry

/-! ## Game theory on the river: the bot's side and the equilibrium (see `Engine/Proofs/Equilibrium.lean`)

The definitions (`bluffTotal`, `valueTotal`, `callCount`, `RiverEquilibrium`) are in
`Engine/Proofs/EquilibriumSpec.lean`. -/

/-- **What a bluff wins.** Betting a bluff of `bet` into `pot` wins the pot for each fold and
loses the bet for each call, compared with checking it. -/
theorem bluff_total (answers : List RiverChoice) (pot bet : Nat) :
    bluffTotal answers pot bet =
      (answers.count .fold : Int) * pot - (callCount answers : Int) * bet := sorry

/-- **When a bluff breaks even, for any bet.** It gains nothing over checking exactly when
calls × bet = folds × pot. -/
theorem bluff_breaks_even_iff (answers : List RiverChoice) (pot bet : Nat) :
    bluffTotal answers pot bet = 0 ↔ callCount answers * bet = answers.count .fold * pot := sorry

/-- **Calling half the time makes a pot-sized bluff break even.** The bot bets `pot` into
`pot`. Its bluff gains nothing over checking exactly when you call with half of your hands. -/
theorem half_calls_bluff_breaks_even (answers : List RiverChoice) (pot : Nat) (hpot : 0 < pot) :
    bluffTotal answers pot pot = 0 ↔ 2 * callCount answers = answers.length := sorry

/-- **Call more than half the time, and a pot-sized bluff loses chips.** -/
theorem more_calls_bluff_loses (answers : List RiverChoice) (pot : Nat) (hpot : 0 < pot) :
    bluffTotal answers pot pot < 0 ↔ answers.length < 2 * callCount answers := sorry

/-- **Call less than half the time, and a pot-sized bluff wins chips.** -/
theorem fewer_calls_bluff_wins (answers : List RiverChoice) (pot : Nat) (hpot : 0 < pot) :
    0 < bluffTotal answers pot pot ↔ 2 * callCount answers < answers.length := sorry

/-- **Betting a value hand is never worse than checking it.** It gains the bet for each call
and nothing for each fold. -/
theorem value_bet_never_worse (answers : List RiverChoice) (bet : Nat) :
    valueTotal answers bet = (callCount answers : Int) * bet ∧ 0 ≤ valueTotal answers bet := sorry

/-- **The river equilibrium.** You hold a bluff catcher and the bot bets `pot` into `pot`.
Neither of you can gain by changing your own play alone exactly when one of the bot's bets in
three is a bluff and you call with half of your hands. -/
theorem river_equilibrium_iff (mine : List Nat) (value bluffs : List RankedHand)
    (answers : List RiverChoice) (pot : Nat) (hpot : 0 < pot)
    (hc : CatchesBluffs mine value bluffs) :
    RiverEquilibrium mine value bluffs answers pot ↔
      3 * bluffs.length = value.length + bluffs.length ∧
        2 * callCount answers = answers.length := sorry

/-- **The bot's river bet is pot-sized.** On the river with nothing to call, if the bot bets
(street total `n`) and the pot-sized total, its street bet plus the pot it can win, is a legal
size, then `n` is exactly that pot-sized total. (When the pot is not a legal size, the bot
bets the nearest legal size instead: all-in if it has less than the pot.) -/
theorem bot_river_bet_is_pot_sized (sl : Sliders) (seed : Nat) (hole board : List Card)
    (s : State) (shown : Option Nat) (h5 : board.length = 5) (h0 : s.toCall = 0)
    (lo hi : Nat) (hr : s.raiseBounds = some (lo, hi))
    (hlo : lo ≤ s.bet s.toAct + s.potToWin) (hhi : s.bet s.toAct + s.potToWin ≤ hi)
    (n : Nat) (hbet : (botDecide sl seed hole board s shown).action = .raiseTo n) :
    n = s.bet s.toAct + s.potToWin := sorry

/-! ## The bluff catcher against the other Risk settings (see `Engine/Proofs/RiverGame.lean`)

Risk 100 and Risk 0 against a bluff catcher, and more bluffs never lowering the call for any
bet size. Totals are over the whole betting set, before blocked hands are removed. One street,
a bluff catcher, the bot as bettor; nothing here says the bot plays well. -/

/-- Against a bluff catcher, adding bluffs to the range never makes calling worth less, for any
prize and cost. -/
theorem more_bluffs_more_call_total (mine : List Nat) (value bluffs bluffs' : List RankedHand)
    (prize cost : Nat) (hc : CatchesBluffs mine value bluffs)
    (hc' : CatchesBluffs mine value bluffs') (hlen : bluffs.length ≤ bluffs'.length) :
    choiceTotal (value ++ bluffs) mine prize cost .call ≤
      choiceTotal (value ++ bluffs') mine prize cost .call := sorry

/-- **Calling the maniac down wins.** On a river board with no card twice, a bluff catcher
facing the Risk 100 bot's pot-sized bet of `cost` gains `1296·cost` half-chips over the 810
hands the bot bets: `648·cost` chips, or 0.8 bets per call. The total is over the whole
betting set, before the hands the caller's cards block are removed. -/
theorem maniac_bluff_catcher_total (board : List Card) (h5 : board.length = 5) (hd : board.Nodup)
    (mine : List Nat) (cost : Nat)
    (hc : CatchesBluffs mine (riverBettingSet (Sliders.ofRisk 100).bluffPct board).value
      (riverBettingSet (Sliders.ofRisk 100).bluffPct board).bluffs) :
    choiceTotal ((riverBettingSet (Sliders.ofRisk 100).bluffPct board).value ++
        (riverBettingSet (Sliders.ofRisk 100).bluffPct board).bluffs) mine (2 * cost) cost .call =
      1296 * (cost : Int) := sorry

/-- **Folding to the rock is right.** At Risk 0 the bot never bluffs, so a bluff catcher facing
its pot-sized bet of `cost` loses `648·cost` half-chips over the 324 hands it bets: the whole
call, every time. The total is over the whole betting set, before the hands the caller's
cards block are removed. -/
theorem rock_bluff_catcher_total (board : List Card) (h5 : board.length = 5) (hd : board.Nodup)
    (mine : List Nat) (cost : Nat)
    (hc : CatchesBluffs mine (riverBettingSet (Sliders.ofRisk 0).bluffPct board).value
      (riverBettingSet (Sliders.ofRisk 0).bluffPct board).bluffs) :
    choiceTotal ((riverBettingSet (Sliders.ofRisk 0).bluffPct board).value ++
        (riverBettingSet (Sliders.ofRisk 0).bluffPct board).bluffs) mine (2 * cost) cost .call =
      -(648 * (cost : Int)) := sorry
