import Engine.Bot
import Engine.Tests

/-!
# Tests: the screen's buttons match the rules, and the bot always moves legally

States come from random games (`randomGame` in `Engine/Tests.lean`), stopped after a random
number of moves.
-/

/-- Do the offered buttons say exactly what `Legal` says in state `s`? Checks fold, check,
call, every raise amount in the offered range, and the amounts just outside it. -/
def buttonsMatchRules (s : State) : Bool :=
  let o := legalOptions s
  let legal (a : Action) := decide (Legal s a)
  let raiseOk := match o.raise with
    | some (lo, hi) =>
      (List.range (hi + 1 - lo)).all (fun k => legal (.raiseTo (lo + k)))
        && !legal (.raiseTo (lo - 1)) && !legal (.raiseTo (hi + 1))
    | none => (List.range (s.bet s.toAct + s.stack s.toAct + 2)).all fun n => !legal (.raiseTo n)
  o.fold == legal .fold && o.check == legal .check && (o.call > 0) == legal .call && raiseOk

/-- States from 200 random games, each stopped after a different number of moves. -/
def sampleStates : List State :=
  (List.range 200).filterMap fun seed =>
    (randomGame (seed % 60 + 1) seed (newGame seed)).map (·.hand.chips)

#guard sampleStates.length == 200
#guard sampleStates.all buttonsMatchRules
#guard [exStart, exShortAllIn, exAllInToAct, exAheadToAct].all buttonsMatchRules

/-- A game where both players are the bot: every bot move is accepted, and the game
finishes. -/
def botGame : Nat → Game → Option Game
  | 0, g => some g
  | n + 1, g =>
    if g.over then some g else
    let g := if g.hand.ended.isSome then (g.nextHand.toOption.getD g) else g
    match g.act (botMove g.hand.chips) with
    | .ok g' => botGame n g'
    | .error _ => none

-- Two bots that only check and call reach a showdown every hand. 20 games, each up to
-- 1,000 moves: no bot move is ever rejected. (Kept small: showdowns are slow to evaluate
-- while building.)
#guard (List.range 20).all fun seed => (botGame 1000 (newGame seed)).isSome
