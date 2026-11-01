import Engine.Explain
import Engine.SessionTests

/-!
# Tests: the river range viewer and the Risk explorer

`#guard` runs in Lean's interpreter while building, where the bot's turn decisions are slow,
so the games here end before the turn. Whole hands through the compiled program are in
`src/app/api/game/insights.test.ts`.
-/

open Lean SessionTests

namespace ExplainTests

/-! ## River range viewer -/

/-- The range viewer's hands left (value plus bluffs, less the blocked ones) are the hands
the review counts, and its beat, tie and lose numbers are the review's counts. -/
def rangeMatchesReview (spot : RiverSpot) : Bool :=
  let r := rangeOf spot
  let c := (reviewRiver spot .call).counts
  r.blocked ≤ r.value + r.bluffs && r.value + r.bluffs - r.blocked == c.total
    && r.beat == c.win && r.tie == c.tie && r.lose == c.loss

#guard rangeMatchesReview exRiverSpot
#guard rangeMatchesReview exWeakSpot
#guard rangeMatchesReview exShortSpot
#guard rangeMatchesReview { exWeakSpot with bluffPct := 0 }
#guard rangeMatchesReview { exWeakSpot with bluffPct := 60 }

-- The king-high straight on 2c 7d Js Qh 9s, Bluff 33%: of the 1,081 hands the bot could
-- hold, it bets 324 for value (30%) and 160 as bluffs. The human's king and ten are in 26 of
-- them. Nothing left beats the straight; 9 tie it (other king-tens).
#guard rangeOf exRiverSpot == ⟨324, 160, 26, 449, 9, 0⟩
-- A pair of twos on the same board loses to every value hand it does not block, and beats
-- only bluffs.
#guard rangeOf exWeakSpot == ⟨324, 160, 36, 144, 0, 304⟩
-- At Bluff 0% there are no bluffs to beat. At Bluff 60% there are 486 (60% of the set).
#guard rangeOf { exWeakSpot with bluffPct := 0 } == ⟨324, 0, 20, 0, 0, 304⟩
#guard rangeOf { exWeakSpot with bluffPct := 60 } == ⟨324, 486, 72, 388, 38, 312⟩

/-! ## River range viewer: the review JSON -/

/-- The JSON of move `i` in the review of hand `n`, or `null`. -/
def reviewLine (s : Session) (n i : Nat) : Json :=
  match s.review n with
  | .ok lines => match (field (reviewJson s n lines) "decisions") with
    | .arr ds => ds[i]?.getD Json.null
    | _ => Json.null
  | .error _ => Json.null

/-- Does this JSON object have key `k` at all? -/
def hasKey (j : Json) (k : String) : Bool := (j.getObjVal? k).toOption.isSome

-- A graded call (the river spot set by hand, as in `SessionTests`) carries the range viewer's
-- numbers, the same ones `rangeOf` gives.
#guard match sessionAfter [start42] with
  | some s =>
    match ({ s with riverSpot := some exRiverSpot }.humanAct .call) with
    | .ok s' =>
      let d := reviewLine s' 1 0
      field d "label" != Json.null
        && field d "range" == Json.mkObj [("value", 324), ("bluffs", 160), ("blocked", 26),
          ("beat", 449), ("tie", 9), ("lose", 0)]
    | .error _ => false
  | none => false

-- A move without a river-set grade has no `range` key at all (here a preflop fold, graded
-- against any hand).
#guard match sessionAfter (foldThenNext.take 2) with
  | some s => reviewLine s 1 0 != Json.null && !hasKey (reviewLine s 1 0) "range"
  | none => false

/-! ## Risk explorer: one move of each kind -/

/-- A recorded move at the start of a hand (`exStart`: the bot is the small blind and owes 5),
holding `hole`. -/
def startRecord (hole : List Card) : BotMoveRecord :=
  { seed := 1, hole, board := [], state := exStart, action := .fold }

/-- The bot faces a bet of 200 into a pot of 100 before the flop, with 400 chips behind. -/
def bigBetState : State :=
  { stack := fun p => if p = 0 then 300 else 400, pot := 100,
    bet := fun p => if p = 0 then 200 else 0, lastRaise := 200, toAct := 1 }

/-- The explorer's entry for one recorded move, in a game at Risk 50. -/
def entryOf (m : BotMoveRecord) : Option RiskExplorerEntry := (exploreHandAt 50 [m]).head?

/-- The 101 moves never go from a call, raise or bet back to a fold or check as Risk goes
up: once the bot goes on, it goes on at every higher Risk. -/
def oneSwitchUp (moves : List Action) : Bool :=
  moves.zipIdx.all fun (a, j) => a.continues || (moves.take j).all (!·.continues)

/-- The explorer's moves are what `decideWithCounts` gives at each Risk, worked out one by
one. This checks the shortcuts `movesBySetting` takes with no bet to face. -/
def movesAreEachRisk (sliderAt : Nat → Sliders) (m : BotMoveRecord) : Bool :=
  let c := countsFor m.seed m.hole m.board
  let each := (List.range 101).map fun r =>
    (decideWithCounts (sliderAt r) c m.hole m.board m.state).action
  let moves := movesBySetting sliderAt c m
  moves.length == 101 && (moves.zip each).all fun (a, b) => a.same b

/-- What the explorer must get right for one entry: 101 moves that never go from call back to
fold, Risk mattering exactly when the move changes, and the move at the game's own Risk
being the move the bot made. -/
def entryOk (e : RiskExplorerEntry) : Bool :=
  e.moves.length == 101 && oneSwitchUp e.moves
    && e.riskMatters == (e.effect matches .callsFrom _ | .bluffsFrom _ | .varies)
    && (e.moves[e.risk]?.map (·.same e.action)) == some true

-- Two aces raise before Risk comes in (a win chance of 85%).
#guard (entryOf (startRecord [card 14 .spades, card 14 .hearts])).map (·.effect) == some .raises
-- Ace-king suited calls the 5 chips at every Risk; so does it facing a bet of 200.
#guard (entryOf (startRecord [card 14 .spades, card 13 .spades])).map (·.effect) == some .callsAlways
#guard (entryOf { startRecord [card 14 .spades, card 13 .spades] with state := bigBetState }).map
  (·.effect) == some .callsAlways
-- Nine-two folds the 5 chips below Risk 26 and calls from Risk 26 up (`exRecord`).
#guard (entryOf (startRecord [card 9 .spades, card 2 .hearts])).map (·.effect) == some (.callsFrom 26)
#guard (entryOf (startRecord [card 9 .spades, card 2 .hearts])).map (·.continuesFrom) == some (some 26)
-- Three-two folds to a bet of 200 at every Risk, even Risk 100.
#guard (entryOf { startRecord [card 3 .spades, card 2 .hearts] with state := bigBetState }).map
  (·.effect) == some .foldsAlways
#guard (entryOf { startRecord [card 3 .spades, card 2 .hearts] with state := bigBetState }).map
  (·.continuesFrom) == some none
-- The pot and the call are as the bot saw them: 200 to call, 300 to win.
#guard
  (entryOf { startRecord [card 3 .spades, card 2 .hearts] with state := bigBetState }).map
    (fun e => (e.pot, e.toCall)) == some (300, 200)

-- The summaries.
#guard RiskEffect.summary (.callsFrom 38) == "Folds at Risk 0-37, calls at 38-100."
#guard RiskEffect.summary (.callsFrom 1) == "Folds at Risk 0, calls at 1-100."
#guard RiskEffect.summary (.callsFrom 100) == "Folds at Risk 0-99, calls at 100."
#guard RiskEffect.summary (.bluffsFrom 41) ==
  "Checks at Risk 0-40, bluffs at 41-100: more Risk, more bluffs."
#guard RiskEffect.summary (.callsUpTo 37) == "Calls at Risk 0-37, folds at 38-100."
#guard RiskEffect.summary (.callsUpTo 0) == "Calls at Risk 0, folds at 1-100."
#guard RiskEffect.summary (.callsUpTo 99) == "Calls at Risk 0-99, folds at 100."
#guard RiskEffect.summary .callsAlways == "Calls at every Risk, 0-100."
#guard RiskEffect.summary .foldsAlways == "Folds at every Risk, 0-100."

-- None of these goes from call back to fold, and each one's moves are the bot's decision at
-- each Risk, through `Sliders.ofRisk` and, for the caution sweep, at a fixed Bluff.
#guard [startRecord [card 14 .spades, card 14 .hearts], startRecord [card 14 .spades, card 13 .spades],
    startRecord [card 9 .spades, card 2 .hearts],
    { startRecord [card 3 .spades, card 2 .hearts] with state := bigBetState }].all fun m =>
  ((entryOf m).map (oneSwitchUp ·.moves)) == some true && movesAreEachRisk Sliders.ofRisk m
    && movesAreEachRisk (fun r => ⟨r, 33⟩) m

/-! ## Risk explorer: the river with no bet to face

Here the Bluff that `Sliders.ofRisk` sets changes the move, and the board is ranked once. -/

/-- The river in `exRiverView`'s spot: board A K 2 5 7, 100 in the pot, 450 behind each, and
the bot to act with nothing to call. -/
def riverState : State :=
  { stack := fun _ => 450, pot := 100, bet := fun _ => 0, lastRaise := 10, toAct := 1 }

/-- A recorded river move with no bet to face, holding `hole`. -/
def riverRecord (hole : List Card) : BotMoveRecord :=
  { seed := 1, hole,
    board := [card 14 .spades, card 13 .diamonds, card 2 .clubs, card 5 .hearts, card 7 .hearts],
    state := riverState, action := .check }

/-- The shortcut's moves agree with deciding at each of these Risks one by one. (Deciding
ranks the board again each time, so only a few Risks are checked here.) -/
def riverMovesMatch (m : BotMoveRecord) (risks : List Nat) : Bool :=
  let c := countsFor m.seed m.hole m.board
  let fast := movesBySetting Sliders.ofRisk c m
  fast.length == 101 && risks.all fun r =>
    (fast[r]?.map (·.same (decideWithCounts (Sliders.ofRisk r) c m.hole m.board m.state).action))
      == some true

-- Two aces are a value hand: the pot bet at every Risk.
#guard (entryOf (riverRecord [card 14 .clubs, card 14 .hearts])).map (·.effect) == some .betsAlways
#guard (entryOf (riverRecord [card 14 .clubs, card 14 .hearts])).map (·.continuesFrom) == some (some 0)
-- A pair of sevens is in neither set at any Bluff up to 60%: checked at every Risk.
#guard (entryOf (riverRecord [card 7 .clubs, card 3 .diamonds])).map (·.effect) == some .checksAlways
-- Eight-six is a bluff once the Bluff share is big enough: checked at low Risk, bet above.
#guard (entryOf (riverRecord [card 8 .clubs, card 6 .diamonds])).map
  (fun e => e.effect matches .bluffsFrom _) == some true
#guard (entryOf (riverRecord [card 8 .clubs, card 6 .diamonds])).map (fun e => e.riskMatters) == some true
-- The shortcut agrees with deciding at each Risk, and no river entry goes from bet back to check.
#guard [riverRecord [card 14 .clubs, card 14 .hearts], riverRecord [card 7 .clubs, card 3 .diamonds],
    riverRecord [card 8 .clubs, card 6 .diamonds]].all fun m =>
  riverMovesMatch m [0, 25, 50, 75, 100] && ((entryOf m).map (oneSwitchUp ·.moves)) == some true

/-! ## Risk explorer: moves recorded in real games -/

/-- An `act` request. -/
def act (a : String) : String := "{\"cmd\":\"act\",\"action\":\"" ++ a ++ "\"}"

/-- Hand 1 of `start42`: the human limps, the bot checks its option and bets 20 on the flop,
and the human folds. Two bot moves, neither facing a bet. -/
def limpThenFold := [start42, act "call", act "fold"]
/-- Hand 1 again: the human raises to 40, the bot calls 30 (it would from Risk 8 up: caution
84 and under) and bets 80 on the flop, and the human folds. -/
def raiseThenFold := [start42, "{\"cmd\":\"act\",\"action\":\"raise\",\"amount\":40}", act "fold"]
/-- Hand 2 of `foldThenNext`: the bot, on the button, calls the 5 chips (it would from Risk 23
up: caution 54 and under), and the human folds. -/
def limpByBot := foldThenNext ++ [act "fold"]

/-- For hand `n` of a game: the explorer has one entry per recorded bot move (and per
reason), each entry passes `entryOk`, and each recorded move is what `botDecide` gives at
the game's sliders from the recorded inputs. -/
def handOk (lines : List String) (n : Nat) : Bool :=
  match sessionAfter lines with
  | some s =>
    match s.logs[n - 1]?, s.riskExplorer n with
    | some log, some es =>
      let ms := log.botMoves.toList.map BotMoveRecord.ofLog
      es.length == ms.length && es.length == log.reasons.size && es.length > 0
        && es.all entryOk
        && ms.all fun m => (botDecide s.sliders m.seed m.hole m.board m.state).action.same m.action
    | _, _ => false
  | none => false

#guard handOk limpThenFold 1
#guard handOk raiseThenFold 1
#guard handOk limpByBot 2

-- What Risk does in those hands: two moves with no bet to face; a call that would be a fold
-- below Risk 8, then a bet; a call that would be a fold below Risk 23.
#guard ((sessionAfter limpThenFold).bind (·.riskExplorer 1)).map (·.map (·.effect))
  == some [.noBet, .noBet]
#guard ((sessionAfter raiseThenFold).bind (·.riskExplorer 1)).map (·.map (·.effect))
  == some [.callsFrom 8, .noBet]
#guard ((sessionAfter limpByBot).bind (·.riskExplorer 2)).map (·.map (·.effect))
  == some [.callsFrom 23]
-- With no bet to face before the river, the one decision stands for every Risk, as deciding
-- at each Risk gives.
#guard match sessionAfter limpThenFold with
  | some s => (s.logs[0]?.map fun l =>
      l.botMoves.toList.all fun r => movesAreEachRisk Sliders.ofRisk (BotMoveRecord.ofLog r)) == some true
  | none => false

-- While a hand is played there is no explorer for it. Hand 0 has none either.
#guard match sessionAfter (limpThenFold.take 2) with
  | some s => s.game.hand.ended.isNone && (s.riskExplorer 1).isNone && (s.riskExplorer 0).isNone
  | none => false

/-! ## Risk explorer: the review JSON -/

/-- The `risk_explorer` of hand `n`'s review, as JSON. -/
def explorerJson (lines : List String) (n : Nat) : Json :=
  match sessionAfter lines with
  | some s => match s.review n with
    | .ok ls => field (reviewJson s n ls) "risk_explorer"
    | .error _ => Json.null
  | none => Json.null

-- The bot's call in `raiseThenFold`, as the screen gets it: 30 more to call, to win the
-- 50 chips bet so far (its own 10 and the human's 40).
#guard match explorerJson raiseThenFold 1 with
  | .arr es => es.size == 2 && match es[0]? with
    | some e =>
      field e "street" == "preflop" && field e "pot" == (50 : Nat) && field e "toCall" == (30 : Nat)
        && field e "risk" == (50 : Nat) && field e "action" == "Call"
        && field e "continuesFrom" == (8 : Nat) && field e "riskMatters" == true
        && field e "effect" == "callsFrom"
        && field e "summary" == "Folds at Risk 0-7, calls at 8-100."
        && (match field e "actions" with
          | .arr as => as.size == 101 && as[50]? == some (Json.str "Call")
              && as[7]? == some (Json.str "Fold") && as[8]? == some (Json.str "Call")
          | _ => false)
    | none => false
  | _ => false

-- The flop bet in the same hand: "Bet 80" at every Risk, and Risk doesn't matter.
#guard match explorerJson raiseThenFold 1 with
  | .arr es => match es[1]? with
    | some e => field e "action" == "Bet 80" && field e "continuesFrom" == (0 : Nat)
        && field e "riskMatters" == false && field e "effect" == "noBet"
    | none => false
  | _ => false

-- While the hand is played, `risk_explorer` is null.
#guard explorerJson (limpThenFold.take 2) 1 == Json.null

end ExplainTests
