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
  Risk the player could have set, 0 to 100, with everything else kept the same: the betting
  state, the seed, the bot's cards and the board. Each Risk is turned into the bot's two
  internal settings with `Sliders.ofRisk`, as a new game does. The counts are worked out
  once with `countsFor`, then the bot decides at each Risk with `decideWithCounts`. That is
  how `botDecide` itself decides (`botDecide_eq`), so each entry is what the real bot does
  at that Risk (`exploreHandAt_moves`, `Engine/Proofs/Explain.lean`).

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

/-! ### The river, ranked once

On the river with no bet to face, the bot's move depends on its Bluff setting through
`riverRole`, which ranks the board's 1,081 candidate hands every time it is called (about
20 ms compiled). The explorer asks about 101 settings, so it ranks once and cuts the betting
set from that ranking at each Bluff. The three functions below are `riverBettingSet`,
`riverRole` and the river move with the ranking passed in; `Engine/Proofs/Explain.lean`
shows they agree with the originals. -/

/-- `riverBettingSet` with the board's ranking passed in. -/
def bettingSetRanked (ranked : List RankedHand) (bluffPct : Nat) : RiverBettingSet :=
  let values := valueCount ranked.length
  let bluffs := bluffCount values bluffPct
  { value := ranked.take values, bluffs := ranked.drop (ranked.length - bluffs) }

/-- `riverRole` with the board's ranking passed in. -/
def riverRoleRanked (ranked : List RankedHand) (bluffPct : Nat) (hole : List Card) : RiverRole :=
  let set := bettingSetRanked ranked bluffPct
  if set.value.any (·.isHole hole) then .value
  else if set.bluffs.any (·.isHole hole) then .bluff
  else .check

/-- The move `riverOpening` makes, with the board's ranking passed in: bet pot-sized (kept
inside the legal sizes) with a hand in the betting set, else check. -/
def riverMoveRanked (ranked : List RankedHand) (v : View) : Action :=
  match riverRoleRanked ranked v.sliders.bluffPct v.hole with
  | .check => .check
  | _ =>
    match v.raise with
    | some (lo, hi) => .raiseTo (clampTo v.potBetTarget lo hi)
    | none => .check

/-! ### The moves at each Risk -/

/-- The bot's move at each Risk from 0 to 100, for counts `c`, with every input of the
recorded move kept the same. `sliderAt r` gives the bot's two internal settings at Risk `r`.
Entry `r` is the move at Risk `r`.

With no bet to face before the river, the bot reads no setting at all
(`decideView_no_bet_sliders`), so it decides once and that move fills all 101 places. On the
river with no bet to face, the board's hands are ranked once and the betting set is cut
from that ranking at each Risk's Bluff (`riverMoveRanked`). -/
def movesBySetting (sliderAt : Nat → Sliders) (c : Counts) (m : BotMoveRecord) : List Action :=
  if m.state.toCall = 0 then
    if m.board.length = 5 then
      let ranked := rankRiverHands m.board
      (List.range 101).map fun r =>
        riverMoveRanked ranked (viewOf (sliderAt r) m.hole m.board m.state)
    else List.replicate 101 (decideWithCounts (sliderAt 0) c m.hole m.board m.state).action
  else
    (List.range 101).map fun r => (decideWithCounts (sliderAt r) c m.hole m.board m.state).action

/-- Are two moves the same move? (`Action` has no equality test of its own.) -/
def Action.same : Action → Action → Bool
  | .fold, .fold | .check, .check | .call, .call => true
  | .raiseTo a, .raiseTo b => a == b
  | _, _ => false

/-- The lowest Risk at which the move calls, raises or bets, or `none` if it never does. -/
def continuesFrom (moves : List Action) : Option Nat :=
  (moves.zipIdx.find? (·.1.continues)).map (·.2)

/-- The highest Risk at which the move calls, raises or bets, or `none` if it never does. -/
def continuesUpTo (moves : List Action) : Option Nat :=
  (moves.zipIdx.filter (·.1.continues)).getLast?.map (·.2)

/-- How Risk affects one bot move. -/
inductive RiskEffect where
  /-- No bet to face before the river: the bot bets or checks without reading any setting. -/
  | noBet
  /-- Facing a bet, the bot raises at every Risk: with a win chance of 75% or more it raises
  before it looks at Risk. -/
  | raises
  /-- Facing a bet, the bot calls at every Risk from 0 to 100. -/
  | callsAlways
  /-- Facing a bet, the bot folds at every Risk from 0 to 100. -/
  | foldsAlways
  /-- Facing a bet, the bot folds below Risk `first` and calls from `first` up. -/
  | callsFrom (first : Nat)
  /-- Facing a bet, the bot calls up to `last` and folds above it. This is the shape when the
  sweep is over the internal caution (`exploreHand`), which runs opposite to the player's
  Risk. -/
  | callsUpTo (last : Nat)
  /-- The river with no bet to face: a value hand, bet at every Risk. -/
  | betsAlways
  /-- The river with no bet to face: never in the betting set, or no bet allowed, so checked
  at every Risk. -/
  | checksAlways
  /-- The river with no bet to face: checked below Risk `first`, bet as a bluff from `first`
  up. -/
  | bluffsFrom (first : Nat)
  /-- Any other pattern. -/
  | varies
  deriving Repr, DecidableEq

/-- How Risk affects a recorded move, from its 101 moves. Facing a bet, more Risk never
turns a call into a fold (`exploreHandAt_more_risk_continues`), so the move changes at most
once, from folding to calling; `varies` is for patterns the theorems do not rule out
elsewhere. -/
def riskEffect (m : BotMoveRecord) (moves : List Action) : RiskEffect :=
  let allContinue := moves.all (·.continues)
  let noneContinue := moves.all (!·.continues)
  -- One switch, from folding or checking to going on: continues from `k` up and not before.
  let switchUp : Option Nat :=
    match continuesFrom moves with
    | some k => if (moves.drop k).all (·.continues) then some k else none
    | none => none
  if m.state.toCall = 0 then
    if m.board.length ≠ 5 then .noBet
    else if allContinue then .betsAlways
    else if noneContinue then .checksAlways
    else match switchUp with
      | some k => .bluffsFrom k
      | none => .varies
  else if moves.all (· matches .raiseTo _) then .raises
  else if allContinue then .callsAlways
  else if noneContinue then .foldsAlways
  else match switchUp with
    | some k => .callsFrom k
    | none =>
      match continuesUpTo moves with
      | some j => if (moves.take (j + 1)).all (·.continues) then .callsUpTo j else .varies
      | none => .varies

/-- "0" or "3-17": a span of Risk values. -/
def riskSpan (lo hi : Nat) : String := if lo = hi then s!"{lo}" else s!"{lo}-{hi}"

/-- The explorer's one-sentence summary, such as "Folds at Risk 0-37, calls at 38-100." -/
def RiskEffect.summary : RiskEffect → String
  | .noBet =>
    "Risk doesn't change this move: with no bet to face before the river, the bot doesn't look at its settings."
  | .raises =>
    "Raises at every Risk: with a win chance of 75% or more, the bot raises before it looks at Risk."
  | .callsAlways => "Calls at every Risk, 0-100."
  | .foldsAlways => "Folds at every Risk, 0-100."
  | .callsFrom k => s!"Folds at Risk {riskSpan 0 (k - 1)}, calls at {riskSpan k 100}."
  | .callsUpTo k => s!"Calls at Risk {riskSpan 0 k}, folds at {riskSpan (k + 1) 100}."
  | .betsAlways => "Bets at every Risk: a value hand on this river."
  | .checksAlways => "Checks at every Risk: this hand is never in the river betting set."
  | .bluffsFrom k =>
    s!"Checks at Risk {riskSpan 0 (k - 1)}, bluffs at {riskSpan k 100}: more Risk, more bluffs."
  | .varies => "Changes with Risk more than once."

/-- The effect's name in the review JSON. -/
def RiskEffect.name : RiskEffect → String
  | .noBet => "noBet" | .raises => "raises" | .callsAlways => "callsAlways"
  | .foldsAlways => "foldsAlways" | .callsFrom _ => "callsFrom" | .callsUpTo _ => "callsUpTo"
  | .betsAlways => "betsAlways" | .checksAlways => "checksAlways" | .bluffsFrom _ => "bluffsFrom"
  | .varies => "varies"

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
  /-- The Risk set in this game. -/
  risk : Nat
  /-- The move the bot made. -/
  action : Action
  /-- The move at each Risk from 0 to 100. -/
  moves : List Action
  /-- The lowest Risk at which the bot calls, raises or bets, if any. -/
  continuesFrom : Option Nat
  /-- Does Risk change the move at all? -/
  riskMatters : Bool
  effect : RiskEffect
  /-- The chips when the bot moved, to name the moves ("Bet 60"). -/
  state : State

/-- The explorer's entry for recorded move `m`, from its counts `c`. `sliderAt` gives the
settings at each Risk, and `risk` is this game's Risk. -/
def exploreMoveWith (sliderAt : Nat → Sliders) (risk : Nat) (c : Counts) (m : BotMoveRecord) :
    RiskExplorerEntry :=
  let moves := movesBySetting sliderAt c m
  let v := viewOf (sliderAt risk) m.hole m.board m.state
  { street := streetOfBoard m.board, pot := v.pot, toCall := v.toCall, counts := c,
    risk, action := m.action, moves, continuesFrom := continuesFrom moves,
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

/-- The Risk explorer for one hand's bot moves, in order, with `sliderAt` giving the settings
at each Risk and `risk` the game's own Risk. -/
def exploreHandWith (sliderAt : Nat → Sliders) (risk : Nat) (ms : List BotMoveRecord) :
    List RiskExplorerEntry :=
  let table := countsTable ms
  ms.map fun m => exploreMoveWith sliderAt risk (countsIn table m) m

/-- **The Risk explorer the app shows.** For one hand's bot moves, in order: the move at each
Risk the player could have set, through `Sliders.ofRisk`, as a new game at that Risk would
set the bot. `risk` is the game's Risk. -/
def exploreHandAt (risk : Nat) (ms : List BotMoveRecord) : List RiskExplorerEntry :=
  exploreHandWith Sliders.ofRisk risk ms

/-- The sweep over the internal caution, at the game's Bluff `sl.bluffPct`: entry `r` is the
move at caution `r`. The app showed this before the one-slider change. `exploreHand_moves`
and `exploreHand_risk_monotone` are stated about it; `exploreHandAt` is the same function
with `Sliders.ofRisk` in place of `fun r => ⟨r, sl.bluffPct⟩`. -/
def exploreHand (sl : Sliders) (ms : List BotMoveRecord) : List RiskExplorerEntry :=
  exploreHandWith (fun r => ⟨r, sl.bluffPct⟩) sl.risk ms

/-! ### Example -/

/-- A recorded move: the bot is the small blind at the start of a hand (`exStart`: it owes
5 to call) with nine-two offsuit. At Risk 50 it folded. -/
def exRecord : BotMoveRecord :=
  { seed := 1, hole := [card 9 .spades, card 2 .hearts], board := [], state := exStart,
    action := .fold }

-- Nine-two folds the 5 chips below Risk 26 and calls from Risk 26 up: Risk 26 is the first
-- setting whose caution (48) is under 50.
#guard (exploreHandAt 50 [exRecord]).map (·.effect) == [.callsFrom 26]
#guard (exploreHandAt 50 [exRecord]).map (·.effect.summary) ==
  ["Folds at Risk 0-25, calls at 26-100."]
-- Swept over the internal caution instead, it calls up to caution 49.
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
      exploreHandAt s.risk (log.botMoves.toList.map BotMoveRecord.ofLog)
  else none

/-- The range viewer's numbers for each of the human's moves in hand `n`, in order: `none`
for a move that is not graded. -/
def Session.ranges (s : Session) (n : Nat) : Array (Option RangeSummary) :=
  match s.logs[n - 1]? with
  | some log => log.decisions.map fun d => d.graded.map fun (spot, _) => rangeOf spot
  | none => #[]
