import Engine.Protocol

/-!
# Tests: the game session and its JSON replies

Short games only: `#guard` runs in Lean's interpreter while building, where the bot's turn
decisions are slow. Whole games against the compiled program are in
`src/lean/program.test.ts`.
-/

open Lean

namespace SessionTests

/-- Run requests in order from no game, keeping the session as the program does. Returns
every reply. -/
def runLines (lines : List String) : Array Json := Id.run do
  let mut cur : Option Session := none
  let mut out := #[]
  for line in lines do
    let (next, reply) := respond cur line
    cur := next
    out := out.push reply
  return out

/-- Run requests in order and return the last session. -/
def sessionAfter (lines : List String) : Option Session :=
  lines.foldl (fun cur line => (respond cur line).1) none

def isError (j : Json) : Bool := (j.getObjVal? "error").toBool
def stateOf (j : Json) : Json := (j.getObjVal? "state").toOption.getD Json.null
def field (j : Json) (k : String) : Json := (j.getObjVal? k).toOption.getD Json.null

/-- A new game with seed 42 at Risk 50: the textbook setting, internal pair (0, 33). -/
def start42 := "{\"cmd\":\"new_game\",\"seed\":\"42\",\"risk\":50}"

-- A Risk out of range, or missing, is rejected. So is the old Bluff slider, even in range.
#guard (runLines ["{\"cmd\":\"new_game\",\"seed\":1,\"risk\":101}"]).all isError
#guard (runLines ["{\"cmd\":\"new_game\",\"seed\":1}"]).all isError
#guard (runLines ["{\"cmd\":\"new_game\",\"seed\":1,\"risk\":50,\"bluff_pct\":33}"]).all isError
#guard (runLines ["{\"cmd\":\"new_game\",\"seed\":1,\"risk\":50,\"bluff_pct\":33}"]).map
  (field · "error") == #[Json.str "bluff_pct was removed; Risk sets both"]
-- The `bot` command is gone: the bot moves inside Lean.
#guard (runLines [start42, "{\"cmd\":\"bot\"}"]).map isError == #[false, true]

-- Hand 1: the human is on the button and acts first before the flop. Risk 50 is the internal
-- pair (0, 33), and the state reports all three numbers.
#guard match sessionAfter [start42] with
  | some s => s.game.hand.chips.toAct == human && s.risk == 50 && s.sliders == ⟨0, 33⟩
      && s.botReasons.isNone
  | none => false
#guard (runLines [start42]).map (fun r => field (stateOf r) "sliders")
  == #[Json.mkObj [("risk", 50), ("caution", 0), ("bluffPct", 33)]]
-- Risk 0 is the rock: internal pair (100, 0).
#guard (runLines ["{\"cmd\":\"new_game\",\"seed\":\"42\",\"risk\":0}"]).map
  (fun r => field (stateOf r) "sliders")
  == #[Json.mkObj [("risk", 0), ("caution", 100), ("bluffPct", 0)]]

-- A rejected command gives the state unchanged: the same reply as `state`.
#guard
  let r := runLines [start42, "{\"cmd\":\"act\",\"action\":\"check\"}", "{\"cmd\":\"state\"}"]
  isError r[1]! && stateOf r[1]! == stateOf r[2]!

-- The human folds hand 1. The hand is over; the bot made no move, so it has no reasons.
-- Then hand 2: the bot is on the button and moves first, inside Lean, before the reply.
def foldThenNext := [start42, "{\"cmd\":\"act\",\"action\":\"fold\"}", "{\"cmd\":\"next_hand\"}"]

#guard match sessionAfter (foldThenNext.take 2) with
  | some s => s.game.hand.ended.isSome && s.botReasons == some #[]
  | none => false

#guard match sessionAfter foldThenNext with
  | some s =>
    let botMoves := s.events.filter fun | .move p .. => p == bot | _ => false
    s.game.handNo == 2 && botMoves.size == 1 && (s.logs.back?.map (·.reasons.size)) == some 1
      -- Every reply leaves the human to act, or the hand over.
      && (s.game.hand.ended.isSome || s.game.hand.chips.toAct == human)
      -- While the hand is played, the bot's reasons stay hidden.
      && (s.game.hand.ended.isSome || s.botReasons.isNone)
  | none => false

-- The review of hand 1 lists the human's one move, not graded. Reviewing changes nothing.
#guard
  let r := runLines (foldThenNext ++ ["{\"cmd\":\"review\",\"hand\":1}", "{\"cmd\":\"state\"}"])
  let review := field r[3]! "review"
  !isError r[3]! && stateOf r[3]! == stateOf r[4]!
    && field review "decisions" == Json.arr #[Json.mkObj
      [("street", "preflop"), ("your_action", "fold"), ("label", Json.null),
       ("worth_bb", Json.null), ("equity_had", Json.null), ("equity_needed", Json.null)]]

-- No review for a hand not dealt yet, or hand 0.
#guard (runLines (foldThenNext ++ ["{\"cmd\":\"review\",\"hand\":3}"])).map isError
  == #[false, false, false, true]
#guard (runLines [start42, "{\"cmd\":\"review\",\"hand\":0}"]).map isError == #[false, true]

-- A call that answers the bot's opening river bet is graded. Here the river spot is set by
-- hand on hand 1, where the human must call 5: the call is kept with the spot to grade.
#guard match sessionAfter [start42] with
  | some s =>
    match ({ s with riverSpot := some exRiverSpot }.humanAct .call) with
    | .ok s' =>
      match s'.review 1 with
      | .ok lines => lines.size == 1 && lines.all (·.verdict.isSome) && s'.riverSpot.isNone
      | .error _ => false
    | .error _ => false
  | none => false

-- A raise answering that bet is not graded.
#guard match sessionAfter [start42] with
  | some s =>
    match ({ s with riverSpot := some exRiverSpot }.humanAct (.raiseTo 30)) with
    | .ok s' => match s'.review 1 with
      | .ok lines => lines.size == 1 && lines.all (·.verdict.isNone)
      | .error _ => false
    | .error _ => false
  | none => false

-- A review of the hand being played keeps the bot's reasons hidden.
#guard
  let r := runLines [start42, "{\"cmd\":\"review\",\"hand\":1}"]
  field (field r[1]! "review") "bot_reasons" == Json.null

-- A short caller pays 50 against a bet of 100, but the review must retain the full gap
-- to refund the other 50. Playing the royal-flush board gains 50 chips (5 BB), not 75.
#guard
  let h : Hand := { (startHand (fun _ => 500) 1 7) with
    street := .river
    board := [card 10 .clubs, card 11 .clubs, card 12 .clubs, card 13 .clubs, card 14 .clubs]
    hole := fun p => if p = 0 then [card 2 .diamonds, card 3 .diamonds]
      else [card 4 .hearts, card 5 .hearts]
    chips := { stack := fun p => if p = 0 then 50 else 750
               pot := 100, bet := fun p => if p = 0 then 0 else 100
               lastRaise := 100, toAct := 0 } }
  let spot := riverSpotOf h 33
  let verdict := reviewRiver spot .call
  decide (ValidDeal (h.hole 0) (h.hole 1) h.board) && h.chips.total == 1000
    && h.chips.toCall == 50 && spot.toCall == 100
    && verdict.worthCall.num == 5 * (verdict.worthCall.den : Int)

end SessionTests
