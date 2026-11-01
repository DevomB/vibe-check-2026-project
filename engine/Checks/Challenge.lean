import Engine.Proofs.Reachable
import Engine.Proofs.RiskSpec
import Engine.Proofs.BotSpec
import Engine.Proofs.EquitySpec
import Engine.Proofs.BluffSpec
import Engine.Proofs.ReviewSpec
import Engine.Proofs.EndsSpec
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

/-- T7: value hands are the strongest. Every value hand in the river betting set scores at
least as well as every candidate hand that is not a value hand. -/
theorem value_strongest (bluffPct : Nat) (board : List Card) :
    ∀ v ∈ (riverBettingSet bluffPct board).value, ∀ h ∈ rankRiverHands board,
      h ∉ (riverBettingSet bluffPct board).value → h.score ≤ v.score := sorry

/-- T7: bluffs are the weakest. Every bluff in the river betting set scores no better than
every candidate hand that is not a bluff, so no better than any value hand or any hand
outside the set. -/
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

/-- The game the app plays is reachable. Start with no session and answer any request lines
in order, as `Main.lean` does: whenever a session exists, its game is one the engine can
reach. So the reachable-game theorems (`chips_always_1000`, `no_card_dealt_twice`,
`player_to_act_may_act`, `every_hand_ends`) hold for the game on screen. -/
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

/-- The range viewer's numbers add up. The value hands and bluffs in the bot's river betting
set are exactly the hands your cards block, plus the hands you beat, tie with and lose to. -/
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

/-- The Risk number the bot quotes in its reason never changes its move. So the app's
`Session.botChoice`, which quotes the player's Risk, makes the move every theorem about
`botDecide` describes. -/
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

/-! ## The Risk explorer over the player's Risk (see `Engine/Proofs/Explain.lean`) -/

/-- The Risk explorer shows the real bot. For move number `i` of a hand's recorded bot moves
and every Risk `r` from 0 to 100, the explorer's move at Risk `r` is what `botDecide` returns
with the settings a new game at Risk `r` would use (`Sliders.ofRisk r`) and the move's
recorded seed, cards, board and betting state. -/
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
