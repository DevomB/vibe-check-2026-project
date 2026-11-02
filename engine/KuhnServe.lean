import Engine.KuhnGame
import Lean.Data.Json

/-!
# Kuhn poker for the web page: one JSON request per line in, one JSON reply per line out

The page at `/kuhn` (through `src/app/api/kuhn/route.ts`) sends the human's moves; this program
deals, plays the bot's moves, and answers with the table as the human may see it. Every rule
decision is made by `Engine/KuhnGame.lean` (`kStep`, `kLegal`, `kResult`, the bot), whose
proofs are in `Engine/Proofs/KuhnGame.lean`. This file only reads requests and writes replies.

Requests:
- `{"cmd":"new_hand"}`: deal the next hand. Seats alternate: you are player 1 in hands 1, 3, ...
- `{"cmd":"move","move":"bet"}`: your move: check, bet, call or fold.
- `{"cmd":"reset"}`: start over from 0 chips.
- `{"cmd":"state"}`

The bot's card is only sent at a showdown. A rejected request changes nothing.
-/

open Lean

/-- One hand in progress. -/
structure KHandState where
  c1 : KCard
  c2 : KCard
  /-- The bot's random number for this hand (0, 1 or 2). -/
  roll : Nat
  /-- 0 if you are player 1, 1 if you are player 2. -/
  yourSeat : Nat
  moves : List KMove

/-- What the program remembers between requests. -/
structure KServer where
  hand : Option KHandState := none
  hands : Nat := 0
  /-- Your winnings over all finished hands, in chips. -/
  total : Int := 0

def kCardName : KCard → String
  | .jack => "jack" | .queen => "queen" | .king => "king"

def kMoveName : KMove → String
  | .check => "check" | .bet => "bet" | .call => "call" | .fold => "fold"

def parseMove : String → Option KMove
  | "check" => some .check | "bet" => some .bet | "call" => some .call | "fold" => some .fold
  | _ => none

/-- The bot's move when it is to act. -/
def KHandState.botMove (h : KHandState) : KMove :=
  if h.yourSeat = 0 then botP2Move h.c2 h.roll h.moves else (botP1Line h.c1 h.roll).move h.moves

/-- Let the bot move while it is the bot's turn (at most three moves in a hand). -/
def KHandState.runBot : Nat → KHandState → KHandState
  | 0, h => h
  | fuel + 1, h =>
    match kToAct h.moves with
    | some who =>
      if who ≠ h.yourSeat then
        match kStep h.moves h.botMove with
        | .ok ms => KHandState.runBot fuel { h with moves := ms }
        | .error _ => h
      else h
    | none => h

/-- Your result for a finished hand, in chips. -/
def KHandState.yourResult (h : KHandState) : Int :=
  let p1 := kResult h.c1 h.c2 h.moves
  if h.yourSeat = 0 then p1 else -p1

def KHandState.over (h : KHandState) : Bool := (kToAct h.moves).isNone

/-- The table as you may see it. -/
def stateJson (srv : KServer) : Json :=
  let base := [("hands", toJson srv.hands), ("total", toJson srv.total)]
  match srv.hand with
  | none => Json.mkObj (base ++ [("hand", Json.null)])
  | some h =>
    let over := h.over
    let showdown := over && h.moves.getLast? != some .fold
    let yourCard := if h.yourSeat = 0 then h.c1 else h.c2
    let botCard := if h.yourSeat = 0 then h.c2 else h.c1
    -- Who made each move: moves alternate player 1, player 2, player 1.
    let moveList := (h.moves.zipIdx).map fun (m, i) =>
      Json.mkObj [("by", toJson (if i % 2 = h.yourSeat then "you" else "bot")),
                  ("move", toJson (kMoveName m))]
    let yourTurn := kToAct h.moves = some h.yourSeat
    Json.mkObj (base ++
      [("hand", Json.mkObj
        [ ("yourSeat", toJson (h.yourSeat + 1)),
          ("yourCard", toJson (kCardName yourCard)),
          ("botCard", if showdown then toJson (kCardName botCard) else Json.null),
          ("moves", toJson moveList),
          ("toAct", if over then Json.null else toJson (if yourTurn then "you" else "bot")),
          ("legal", toJson (if yourTurn then (kLegal h.moves).map kMoveName else [])),
          ("over", toJson over),
          ("showdown", toJson showdown),
          ("result", if over then toJson h.yourResult else Json.null) ])])

/-- Finish the bookkeeping when a hand has just ended. -/
def settle (srv : KServer) (h : KHandState) (wasOver : Bool) : KServer :=
  if h.over && !wasOver then
    { srv with hand := some h, hands := srv.hands + 1, total := srv.total + h.yourResult }
  else { srv with hand := some h }

/-- Run one request. `deal` and `roll` are fresh random numbers for a new hand. -/
def handle (srv : KServer) (j : Json) (deal roll : Nat) : Except String KServer := do
  match ← j.getObjValAs? String "cmd" with
  | "state" => pure srv
  | "reset" => pure {}
  | "new_hand" =>
    if let some h := srv.hand then
      if !h.over then throw "finish this hand first"
    let (c1, c2) := kDeal deal
    let h : KHandState := { c1, c2, roll, yourSeat := srv.hands % 2, moves := [] }
    pure (settle srv (h.runBot 3) false)
  | "move" =>
    let some h := srv.hand | throw "no hand yet: send new_hand first"
    if h.over then throw "the hand is over"
    if kToAct h.moves ≠ some h.yourSeat then throw "it is not your turn"
    let some m := parseMove (← j.getObjValAs? String "move") | throw "unknown move"
    match kStep h.moves m with
    | .error e => throw e
    | .ok ms => pure (settle srv ({ h with moves := ms }.runBot 3) false)
  | other => throw s!"unknown command '{other}'"

def main : IO Unit := do
  let stdin ← IO.getStdin
  let stdout ← IO.getStdout
  let srv ← IO.mkRef ({} : KServer)
  repeat
    let line ← stdin.getLine
    if line.isEmpty then break
    if line.trimAscii.isEmpty then continue
    let current ← srv.get
    let deal ← IO.rand 0 5
    let roll ← IO.rand 0 2
    let result : Except String KServer := match Json.parse line.trimAscii.toString with
      | .error e => .error s!"bad JSON: {e}"
      | .ok j => handle current j deal roll
    let out : Json ← match result with
      | .ok next => do srv.set next; pure (Json.mkObj [("ok", toJson true), ("state", stateJson next)])
      | .error e => pure (Json.mkObj [("error", toJson e), ("state", stateJson current)])
    stdout.putStrLn out.compress
    stdout.flush
