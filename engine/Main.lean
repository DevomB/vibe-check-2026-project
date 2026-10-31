import Engine
import Lean.Data.Json

/-!
# The game program: one JSON request per line in, one JSON reply per line out

The browser (through the Node bridge in `src/app/api/game/route.ts`) sends commands, and
this program answers with the table as the human may see it. Every rule decision is made by
the engine (`step`, `Legal`, `showdown`, `botMove`); this file only reads commands and
writes replies. Player 0 is the human, player 1 is the bot.

Commands:
- `{"cmd":"new_game","seed":42}`
- `{"cmd":"act","action":"call"}`, with `action` one of fold, check, call, raise;
  a raise also needs `"amount"`, the player's total bet for this round.
- `{"cmd":"bot"}`: the bot makes its move (only when it is the bot's turn).
- `{"cmd":"next_hand"}`
- `{"cmd":"state"}`

A rejected command gets `{"error":"...","state":...}` and changes nothing.
The bot's cards are only sent once the hand reaches a showdown.
-/

open Lean

/-- The human is player 0, the bot is player 1. -/
def human : Player := 0
def bot : Player := 1

/-- What the program remembers between commands. -/
structure Server where
  game : Option Game := none
  /-- Each player's latest move this betting round, for display ("Call", "Raise to 60"). -/
  labels : Player → Option String := fun _ => none
  /-- What happened since the last reply: blinds, moves, cards dealt, who won. -/
  events : Array Json := #[]
  /-- Chips each player won in the hand that just ended (the pot or their share of it). -/
  winnings : Player → Nat := fun _ => 0

/-! ## Turning game values into JSON -/

def cardsJson (cs : List Card) : Json := toJson (cs.map Card.toString)

def streetName : Street → String
  | .preflop => "preflop" | .flop => "flop" | .turn => "turn" | .river => "river"

def actionName : Action → String
  | .fold => "fold" | .check => "check" | .call => "call" | .raiseTo _ => "raise"

/-- The chips in the middle just before a showdown pays out: earlier rounds plus this
round's matched bets. `s` is the state right after the last move. -/
def potBeforePayout (s : State) : Nat := (collectBets (returnUncalled s)).pot

/-- What each player won in a finished hand. `middleBefore` is the state right after the
last move (before any payout), from which the pot is worked out. -/
def winningsOf (h : Hand) (middleBefore : State) : Player → Nat :=
  match h.ended with
  | some (.folded w) =>
    -- The unmatched part of a bet goes back first; the winner takes the rest.
    let s := returnUncalled middleBefore
    fun p => if p = w then s.pot + s.bet 0 + s.bet 1 else 0
  | some (.showdown r) =>
    let pot := potBeforePayout middleBefore
    match r with
    | .player0 => fun p => if p = 0 then pot else 0
    | .player1 => fun p => if p = 1 then pot else 0
    | .tie => fun p => if p = other h.button then pot - pot / 2 else pot / 2
  | none => fun _ => 0

/-- Events for the board cards dealt between `before` and `after`. -/
def streetEvents (before after : List Card) : Array Json := Id.run do
  let mut out := #[]
  for (name, lo, hi) in [("flop", 0, 3), ("turn", 3, 4), ("river", 4, 5)] do
    if before.length ≤ lo && hi ≤ after.length then
      out := out.push <| Json.mkObj
        [("type", toJson "street"), ("street", toJson name), ("cards", cardsJson ((after.drop lo).take (hi - lo)))]
  return out

def winEvents (won : Player → Nat) : Array Json :=
  (#[0, 1] : Array Player).filterMap fun p =>
    if won p > 0 then some <| Json.mkObj
      [("type", toJson "win"), ("player", toJson p.val), ("amount", toJson (won p))]
    else none

/-- The table as the human may see it. -/
def stateJson (srv : Server) (g : Game) : Json :=
  let h := g.hand
  let s := h.chips
  let ended := h.ended.isSome
  let showdown := match h.ended with | some (.showdown _) => true | _ => false
  let status := if g.over then "gameOver" else if ended then "handOver" else "playing"
  let player (p : Player) : Json :=
    let folded := match h.ended with | some (.folded w) => p ≠ w | _ => false
    Json.mkObj
      [ ("stack", toJson (s.stack p)),
        ("bet", toJson (s.bet p)),
        -- The bot's cards stay hidden until a showdown.
        ("cards", if p = human || showdown then cardsJson (h.hole p) else Json.null),
        ("folded", toJson folded),
        ("allIn", toJson (s.stack p == 0 && !folded)),
        ("lastAction", match srv.labels p with | some l => toJson l | none => Json.null) ]
  let o := legalOptions s
  let legal :=
    if !ended && s.toAct = human then
      Json.mkObj
        [ ("fold", toJson o.fold), ("check", toJson o.check), ("call", toJson o.call),
          ("raise", match o.raise with
            | some (lo, hi) => Json.mkObj [("min", toJson lo), ("max", toJson hi)]
            | none => Json.null) ]
    else Json.null
  let result :=
    if ended then
      let r := match h.ended with
        | some (.showdown .player0) => "player0" | some (.showdown .player1) => "player1"
        | some (.showdown .tie) => "tie" | _ => "fold"
      Json.mkObj
        [ ("showdown", toJson showdown), ("outcome", toJson r),
          ("winnings", toJson [srv.winnings 0, srv.winnings 1]) ]
    else Json.null
  Json.mkObj
    [ ("hand", toJson g.handNo),
      ("seed", toJson (toString g.seed)),
      ("street", toJson (if showdown then "showdown" else streetName h.street)),
      ("button", toJson h.button.val),
      ("toAct", if ended then Json.null else toJson s.toAct.val),
      ("board", cardsJson h.board),
      ("pot", toJson s.pot),
      ("currentBet", toJson (max (s.bet 0) (s.bet 1))),
      ("minRaise", toJson s.minRaise),
      ("status", toJson status),
      ("players", toJson [player 0, player 1]),
      ("legal", legal),
      ("result", result),
      ("events", toJson srv.events) ]

/-! ## Commands -/

/-- A new hand has been dealt (by `newGame` or `nextHand`): record the blinds, and the
board and winner too if the blinds already put someone all-in. -/
def afterDeal (g : Game) (stacks : Player → Nat) : Server :=
  let h := g.hand
  let dealt := dealHand stacks h.button (handSeed g.seed g.handNo)
  let blind (p : Player) (kind : String) := Json.mkObj
    [("type", toJson "blind"), ("player", toJson p.val), ("amount", toJson (dealt.chips.bet p)),
     ("kind", toJson kind)]
  let won := winningsOf h dealt.chips
  { game := some g
    labels := fun p => if p = h.button then some "SB" else some "BB"
    events := #[blind h.button "small", blind (other h.button) "big"]
      ++ streetEvents [] h.board ++ winEvents won
    winnings := won }

/-- The player to act makes move `a`. -/
def doMove (srv : Server) (g : Game) (a : Action) : Except String Server := do
  let h := g.hand
  let me := h.chips.toAct
  let g' ← g.act a
  let h' := g'.hand
  let moved := applyMove h.chips a
  let paid := h.chips.stack me - moved.stack me
  let allIn := moved.stack me == 0
  let currentBet := max (h.chips.bet 0) (h.chips.bet 1)
  let label := match a with
    | .fold => "Fold" | .check => "Check"
    | .call => if allIn then "All-in" else "Call"
    | .raiseTo n => if allIn then "All-in" else if currentBet == 0 then s!"Bet {n}" else s!"Raise to {n}"
  let action := Json.mkObj <|
    [("type", toJson "action"), ("player", toJson me.val), ("action", toJson (actionName a)),
     ("amount", toJson paid), ("allIn", toJson allIn)]
    ++ (match a with | .raiseTo n => [("to", toJson n)] | _ => [])
  -- A new betting round clears the move labels.
  let newRound := h'.board.length != h.board.length
  let labels := if newRound then fun _ => none else setFor srv.labels me (some label)
  let won := winningsOf h' (if a matches .fold then h.chips else moved)
  return { srv with game := some g', labels, winnings := won,
                    events := #[action] ++ streetEvents h.board h'.board ++ winEvents won }

def parseAction (j : Json) : Except String Action := do
  match ← j.getObjValAs? String "action" with
  | "fold" => pure .fold
  | "check" => pure .check
  | "call" => pure .call
  | "raise" => return .raiseTo (← j.getObjValAs? Nat "amount")
  | other => throw s!"unknown action '{other}'"

/-- A seed given as a number or as a string of digits. -/
def parseSeed (j : Json) : Except String Nat :=
  match j.getObjValAs? Nat "seed" with
  | .ok n => pure n
  | .error _ => do
    let s ← j.getObjValAs? String "seed"
    match s.toNat? with
    | some n => pure n
    | none => throw "seed must be a whole number"

/-- Run one command. On success, the new server state; on failure, a reason. -/
def handle (srv : Server) (j : Json) : Except String Server := do
  let cmd ← j.getObjValAs? String "cmd"
  let srv := { srv with events := #[] }
  match cmd with
  | "new_game" =>
    let seed ← parseSeed j
    return afterDeal (newGame seed) (fun _ => startingStack)
  | "state" =>
    if srv.game.isNone then throw "no game yet: send new_game first"
    return srv
  | "act" | "bot" | "next_hand" =>
    let some g := srv.game | throw "no game yet: send new_game first"
    match cmd with
    | "next_hand" => return afterDeal (← g.nextHand) g.hand.chips.stack
    | _ =>
      if g.hand.ended.isSome then throw "the hand is over"
      let mover := if cmd == "act" then human else bot
      if g.hand.chips.toAct ≠ mover then
        throw (if cmd == "act" then "it is not your turn" else "it is not the bot's turn")
      let a ← if cmd == "act" then parseAction j else pure (botMove g.hand.chips)
      doMove srv g a
  | other => throw s!"unknown command '{other}'"

def reply (srv : Server) : Json :=
  match srv.game with
  | some g => stateJson srv g
  | none => Json.null

def main : IO Unit := do
  let stdin ← IO.getStdin
  let stdout ← IO.getStdout
  let srv ← IO.mkRef ({} : Server)
  repeat
    let line ← stdin.getLine
    if line.isEmpty then break   -- end of input
    if line.trimAscii.isEmpty then continue
    let current ← srv.get
    let result : Except String Server := match Json.parse line.trimAscii.toString with
      | .error e => .error s!"bad JSON: {e}"
      | .ok j => handle current j
    let out : Json ← match result with
      | .ok next => do
        srv.set next
        pure (Json.mkObj [("ok", toJson true), ("state", reply next)])
      | .error e => pure (Json.mkObj [("error", toJson e), ("state", reply { current with events := #[] })])
    stdout.putStrLn out.compress
    stdout.flush
