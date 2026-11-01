import Engine.Session

/-!
# Engine: panels that explain a finished hand

These panels only read what the game recorded. They change nothing and use no randomness.

- **River range viewer**, next to each graded river decision. How many hands the bot's
  river betting set has on that board (value hands and bluffs), how many of them use one of
  your cards, and how many of the rest your hand beats, ties and loses to. It uses the
  review's own functions: `riverBettingSet`, `RiverSpot.blocks`, `RiverSpot.botHands` and
  `scoreCounts`.
- **Risk explorer**, for each bot move in the hand. The move the bot would have made at each
  Risk from 0 to 100, with everything else kept the same: the betting state, the seed, the
  bot's cards, the board and Bluff. The counts are worked out once with `countsFor`, then the
  bot decides at each Risk with `decideWithCounts`. That is how `botDecide` itself decides
  (`botDecide_eq`), so each entry is what the real bot does at that Risk
  (`exploreHand_moves`, `Engine/Proofs/Explain.lean`).

While it plays, the game only records each bot move's inputs (`HandLog.botMoves`) and works
out nothing extra. The counts are worked out again here, when a review is asked for.
-/

/-! ## River range viewer -/

/-- The six numbers of the river range viewer. -/
structure RangeSummary where
  /-- Value hands in the bot's river betting set on this board. -/
  value : Nat
  /-- Bluff hands in that set. -/
  bluffs : Nat
  /-- Hands in the set that use one of your cards. The bot cannot hold them. -/
  blocked : Nat
  /-- Of the hands left, how many your hand beats. -/
  beat : Nat
  /-- Of the hands left, how many your hand ties. -/
  tie : Nat
  /-- Of the hands left, how many your hand loses to. -/
  lose : Nat
  deriving Repr, BEq, DecidableEq

/-- The range viewer's numbers for a river spot. The hands left are the review's own
`botHands`, counted with the review's own `scoreCounts`, so `beat`, `tie` and `lose` are
the counts the grade uses. -/
def rangeOf (spot : RiverSpot) : RangeSummary :=
  let set := riverBettingSet spot.bluffPct spot.board
  let c := scoreCounts spot.myScore spot.botHands
  { value := set.value.length, bluffs := set.bluffs.length,
    blocked := ((set.value ++ set.bluffs).filter spot.blocks).length,
    beat := c.win, tie := c.tie, lose := c.loss }

/-! ## Risk explorer -/

/-- One bot move as the game recorded it in `HandLog.botMoves`: what `botDecide` was given,
apart from the sliders, and the move the bot made. -/
structure BotMoveRecord where
  /-- The hand's seed (`handSeed`). Only the flop's random deals use it. -/
  seed : Nat
  /-- The bot's two cards. -/
  hole : List Card
  /-- The board when the bot moved. -/
  board : List Card
  /-- The chips when the bot moved: stacks, pot, bets, and whose turn it is. -/
  state : State
  /-- The move the bot made. -/
  action : Action

/-- Read one entry of `HandLog.botMoves`. -/
def BotMoveRecord.ofLog : Nat × List Card × List Card × State × Action → BotMoveRecord
  | (seed, hole, board, state, action) => { seed, hole, board, state, action }

/-- What the bot's counts depend on: the seed, its cards and the board. -/
def BotMoveRecord.countsKey (m : BotMoveRecord) : Nat × List Card × List Card :=
  (m.seed, m.hole, m.board)

/-- The street a board belongs to: no cards before the flop, then 3, 4 and 5. -/
def streetOfBoard (board : List Card) : Street :=
  match board.length with
  | 0 => .preflop | 3 => .flop | 4 => .turn | _ => .river

/-- The bot's move at each Risk from 0 to 100, for counts `c`, with Bluff and every input of
the recorded move kept the same. Entry `r` is the move at Risk `r`.

With no bet to face, the bot never looks at Risk (`decideView_no_bet`), so it decides once
and that move fills all 101 places. This matters on the river, where each such decision
ranks the board's 1,081 hands again. -/
def movesByRisk (sl : Sliders) (c : Counts) (m : BotMoveRecord) : List Action :=
  if m.state.toCall = 0 then
    List.replicate 101 (decideWithCounts sl c m.hole m.board m.state).action
  else
    (List.range 101).map fun r =>
      (decideWithCounts ⟨r, sl.bluffPct⟩ c m.hole m.board m.state).action

/-- Are two moves the same move? (`Action` has no equality test of its own.) -/
def Action.same : Action → Action → Bool
  | .fold, .fold | .check, .check | .call, .call => true
  | .raiseTo a, .raiseTo b => a == b
  | _, _ => false

/-- The highest Risk at which the move calls or raises, or `none` if it does neither at any
Risk. -/
def continuesUpTo (moves : List Action) : Option Nat :=
  (moves.zipIdx.filter (·.1.continues)).getLast?.map (·.2)

/-- How Risk affects one bot move. -/
inductive RiskEffect where
  /-- No bet to face: the bot bets or checks without looking at Risk. -/
  | noBet
  /-- Facing a bet, the bot raises at every Risk: with a win chance of 75% or more it raises
  before it looks at Risk. -/
  | raises
  /-- Facing a bet, the bot calls at every Risk from 0 to 100. -/
  | callsAlways
  /-- Facing a bet, the bot folds at every Risk from 0 to 100. -/
  | foldsAlways
  /-- Facing a bet, the bot calls at Risk 0 to `last`, and folds above `last`. -/
  | callsUpTo (last : Nat)
  deriving Repr, DecidableEq

/-- How Risk affects a recorded move, from its 101 moves. By T4 (`risk_monotone`), a move
that faces a bet can change only once as Risk goes up: from calling to folding. -/
def riskEffect (m : BotMoveRecord) (moves : List Action) : RiskEffect :=
  if m.state.toCall = 0 then .noBet
  else if moves.all (· matches .raiseTo _) then .raises
  else match continuesUpTo moves with
    | none => .foldsAlways
    | some k => if k + 1 = moves.length then .callsAlways else .callsUpTo k

/-- The explorer's one-sentence summary, such as "Calls at Risk 0-37, folds at 38-100." -/
def RiskEffect.summary : RiskEffect → String
  | .noBet => "Risk doesn't change this move: with no bet to face, the bot doesn't look at Risk."
  | .raises =>
    "Raises at every Risk: with a win chance of 75% or more, the bot raises before it looks at Risk."
  | .callsAlways => "Calls at every Risk, 0-100."
  | .foldsAlways => "Folds at every Risk, 0-100."
  | .callsUpTo k =>
    let calls := if k = 0 then "Risk 0" else s!"Risk 0-{k}"
    let folds := if k = 99 then "100" else s!"{k + 1}-100"
    s!"Calls at {calls}, folds at {folds}."

/-- The effect's name in the review JSON. -/
def RiskEffect.name : RiskEffect → String
  | .noBet => "noBet" | .raises => "raises" | .callsAlways => "callsAlways"
  | .foldsAlways => "foldsAlways" | .callsUpTo _ => "callsUpTo"

/-- A move as the table shows it in state `s`: "Fold", "Check", "Call", "Bet 60",
"Raise to 120" or "All-in". The same words as the move labels during play. -/
def moveText (s : State) (a : Action) : String :=
  moveLabel s a ((applyMove s a).stack s.toAct == 0)

/-- The explorer's entry for one bot move. -/
structure RiskExplorerEntry where
  street : Street
  /-- The pot the bot could win, as the bot saw it (`viewOf`). -/
  pot : Nat
  /-- The chips the bot had to add to call, or 0 with no bet to face. -/
  toCall : Nat
  /-- The bot's win, tie and loss counts, from `countsFor`. -/
  counts : Counts
  /-- The bot's Risk in this game. -/
  risk : Nat
  /-- The move the bot made. -/
  action : Action
  /-- The move at each Risk from 0 to 100. -/
  moves : List Action
  /-- The highest Risk at which the bot calls or raises, if any. -/
  continuesUpTo : Option Nat
  /-- Does Risk change the move at all? -/
  riskMatters : Bool
  effect : RiskEffect
  /-- The chips when the bot moved, to name the moves ("Bet 60"). -/
  state : State

/-- The explorer's entry for recorded move `m`, from its counts `c`. -/
def exploreMove (sl : Sliders) (c : Counts) (m : BotMoveRecord) : RiskExplorerEntry :=
  let moves := movesByRisk sl c m
  let v := viewOf sl m.hole m.board m.state
  { street := streetOfBoard m.board, pot := v.pot, toCall := v.toCall, counts := c,
    risk := sl.risk, action := m.action, moves, continuesUpTo := continuesUpTo moves,
    riskMatters := moves.any fun a => !a.same (moves.headD .fold),
    effect := riskEffect m moves, state := m.state }

/-- The counts for each different (seed, cards, board) among the moves, each worked out
once with `countsFor`. The moves on one street of a hand share them, so a hand needs at most
four, and the turn's (about a second) is worked out once. -/
def countsTable (ms : List BotMoveRecord) : List ((Nat × List Card × List Card) × Counts) :=
  (ms.map (·.countsKey)).eraseDups.map fun k => (k, countsFor k.1 k.2.1 k.2.2)

/-- The counts for move `m`, from the table. The table always has them for the hand's own
moves; otherwise they are worked out here. Either way they are `countsFor`'s
(`countsIn_countsTable`). -/
def countsIn (table : List ((Nat × List Card × List Card) × Counts)) (m : BotMoveRecord) :
    Counts :=
  match table.lookup m.countsKey with
  | some c => c
  | none => countsFor m.seed m.hole m.board

/-- The Risk explorer for one hand's bot moves, in order, at the game's sliders `sl`. -/
def exploreHand (sl : Sliders) (ms : List BotMoveRecord) : List RiskExplorerEntry :=
  let table := countsTable ms
  ms.map fun m => exploreMove sl (countsIn table m) m

/-! ### Example -/

/-- A recorded move: the bot is the small blind at the start of a hand (`exStart`: it owes
5 to call) with nine-two offsuit. At Risk 50 it folded. -/
def exRecord : BotMoveRecord :=
  { seed := 1, hole := [card 9 .spades, card 2 .hearts], board := [], state := exStart,
    action := .fold }

-- Nine-two calls the 5 chips up to Risk 49 and folds from Risk 50.
#guard (exploreHand ⟨50, 33⟩ [exRecord]).map (·.effect) == [.callsUpTo 49]
#guard (exploreHand ⟨50, 33⟩ [exRecord]).map (·.effect.summary) ==
  ["Calls at Risk 0-49, folds at 50-100."]

/-! ## For the review -/

/-- Is hand `n` over? Every earlier hand is; the current one once it has ended. -/
def Session.handOver (s : Session) (n : Nat) : Bool :=
  0 < n && n ≤ s.logs.size && (n < s.game.handNo || s.game.hand.ended.isSome)

/-- The Risk explorer for hand `n`, only once that hand is over: the counts show how strong
the bot's hand was, so they stay hidden while it is played (MVP §2). -/
def Session.riskExplorer (s : Session) (n : Nat) : Option (List RiskExplorerEntry) :=
  if s.handOver n then
    s.logs[n - 1]?.map fun log =>
      exploreHand s.sliders (log.botMoves.toList.map BotMoveRecord.ofLog)
  else none

/-- The range viewer's numbers for each of the human's moves in hand `n`, in order: `none`
for a move that is not graded. -/
def Session.ranges (s : Session) (n : Nat) : Array (Option RangeSummary) :=
  match s.logs[n - 1]? with
  | some log => log.decisions.map fun d => d.graded.map fun (spot, _) => rangeOf spot
  | none => #[]
