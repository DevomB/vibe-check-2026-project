import Engine.Session
import Engine.HandName
import Lean.Data.Json

/-!
# Engine: the game program's JSON messages

One JSON request per line in, one JSON reply per line out (MVP §13). `respond` reads one
request, runs it on the session (`Engine/Session.lean`) and writes the reply. It decides no
rule itself.

Requests:
- `{"cmd":"new_game","seed":"42","risk":50,"bluff_pct":33}`: the seed is a number or a string
  of digits; Risk is 0 to 100 and Bluff 0 to 60, both whole numbers.
- `{"cmd":"act","action":"call"}`, with `action` one of fold, check, call, raise;
  a raise also needs `"amount"`, the player's total bet for this round.
- `{"cmd":"next_hand"}`, `{"cmd":"state"}`
- `{"cmd":"review","hand":3}`: the review of hand 3. It changes nothing.

Replies: `{"ok":true,"state":...}`, plus `"review":...` for a review. A rejected request gets
`{"error":"...","state":...}` with the state unchanged. The bot's cards are only sent once
the hand reaches a showdown, and its reasons only once the hand is over.
-/

open Lean

/-! ## Game values as JSON -/

def cardsJson (cs : List Card) : Json := toJson (cs.map Card.toString)

def streetName : Street → String
  | .preflop => "preflop" | .flop => "flop" | .turn => "turn" | .river => "river"

def actionName : Action → String
  | .fold => "fold" | .check => "check" | .call => "call" | .raiseTo _ => "raise"

def Event.json : Event → Json
  | .blind p amount small => Json.mkObj
    [("type", toJson "blind"), ("player", toJson p.val), ("amount", toJson amount),
     ("kind", toJson (if small then "small" else "big"))]
  | .move p a paid allIn => Json.mkObj <|
    [("type", toJson "action"), ("player", toJson p.val), ("action", toJson (actionName a)),
     ("amount", toJson paid), ("allIn", toJson allIn)]
    ++ (match a with | .raiseTo n => [("to", toJson n)] | _ => [])
  | .street name cards => Json.mkObj
    [("type", toJson "street"), ("street", toJson (streetName name)), ("cards", cardsJson cards)]
  | .win p amount => Json.mkObj
    [("type", toJson "win"), ("player", toJson p.val), ("amount", toJson amount)]

/-- A fraction as a decimal with `places` digits after the point, rounded half away from
zero. Only for display: every decision uses the exact fraction. -/
def Frac.json (f : Frac) (places : Nat) : Json :=
  let den := max f.den 1
  let size := (f.num.natAbs * 10 ^ places * 2 + den) / (2 * den)
  Json.num ⟨if f.num < 0 then -(size : Int) else size, places⟩

-- -4.1 big blinds, sent as -4.1.
#guard (Frac.json ⟨-41, 10⟩ 2).compress == "-4.1"
#guard (Frac.json ⟨1, 3⟩ 3).compress == "0.333"
#guard (Frac.json ⟨2, 3⟩ 3).compress == "0.667"

/-- The table as the human may see it. -/
def stateJson (srv : Session) : Json :=
  let g := srv.game
  let h := g.hand
  let s := h.chips
  let ended := h.ended.isSome
  let showdown := match h.ended with | some (.showdown _) => true | _ => false
  let status := if g.over then "gameOver" else if ended then "handOver" else "playing"
  let player (p : Player) : Json :=
    let folded : Bool := match h.ended with | some (.folded w) => p ≠ w | _ => false
    -- The bot's cards stay hidden until a showdown.
    let shown := p = human || showdown
    let best := if shown then bestFive (h.hole p ++ h.board) else []
    Json.mkObj
      [ ("stack", toJson (s.stack p)),
        ("bet", toJson (s.bet p)),
        ("cards", if shown then cardsJson (h.hole p) else Json.null),
        ("folded", toJson folded),
        ("allIn", toJson (s.stack p == 0 && !folded)),
        ("lastAction", match srv.labels p with | some l => toJson l | none => Json.null),
        ("handName", match handName best with | some n => toJson n | none => Json.null),
        ("bestCards", if best.isEmpty then Json.null else cardsJson best) ]
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
      ("players", Json.arr #[player 0, player 1]),
      ("legal", legal),
      ("result", result),
      ("events", Json.arr (srv.events.map Event.json)),
      ("sliders", Json.mkObj [("risk", toJson srv.sliders.risk), ("bluffPct", toJson srv.sliders.bluffPct)]),
      ("botReasons", match srv.botReasons with | some rs => toJson rs | none => Json.null) ]

/-- The review of hand `n` (MVP §13). Ungraded moves have `null` grades: "not graded yet". -/
def reviewJson (srv : Session) (n : Nat) (lines : Array ReviewLine) : Json :=
  let line (l : ReviewLine) : Json :=
    let grade (f : RiverVerdict → Json) := match l.verdict with | some v => f v | none => Json.null
    Json.mkObj
      [ ("street", toJson (streetName l.street)),
        ("your_action", toJson l.action),
        ("label", grade (toJson ·.label.name)),
        ("worth_bb", grade fun v =>
          Json.mkObj [("call", v.worthCall.json 2), ("fold", v.worthFold.json 2)]),
        ("equity_had", grade (·.equityHad.json 3)),
        ("equity_needed", grade (·.equityNeeded.json 3)) ]
  Json.mkObj
    [("hand", toJson n), ("decisions", Json.arr (lines.map line)),
     -- Like `botReasons`: `null` while hand `n` is still being played.
     ("bot_reasons", match srv.reasonsFor n with | some rs => toJson rs | none => Json.null)]

/-! ## Reading requests -/

/-- A request: a command that may change the game, or a review that never does. -/
inductive Request where
  | game (c : _root_.Command)
  | review (hand : Nat)

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

/-- A whole number in `0..hi`, or the error `msg` if it is missing or out of range. -/
def parseUpTo (j : Json) (key : String) (hi : Nat) (msg : String) : Except String Nat :=
  match j.getObjValAs? Nat key with
  | .ok n => if n ≤ hi then pure n else throw msg
  | .error _ => throw msg

def parseRequest (j : Json) : Except String Request := do
  match ← j.getObjValAs? String "cmd" with
  | "new_game" =>
    return .game (.newGame (← parseSeed j) (← parseUpTo j "risk" 100 "risk must be 0-100")
      (← parseUpTo j "bluff_pct" 60 "bluff_pct must be 0-60"))
  | "act" => return .game (.act (← parseAction j))
  | "next_hand" => return .game .nextHand
  | "state" => return .game .state
  | "review" => return .review (← j.getObjValAs? Nat "hand")
  | other => throw s!"unknown command '{other}'"

/-! ## One request, one reply -/

/-- Answer one request line. Returns the session to keep and the reply. A rejected request
keeps the old session, so it changes nothing. -/
def respond (cur : Option Session) (line : String) : Option Session × Json :=
  let unchanged : Json := match cur with
    | some s => stateJson { s with events := #[] }
    | none => Json.null
  let fail (e : String) := (cur, Json.mkObj [("error", toJson e), ("state", unchanged)])
  match Json.parse line with
  | .error e => fail s!"bad JSON: {e}"
  | .ok j =>
    match parseRequest j with
    | .error e => fail e
    | .ok (.review n) =>
      match cur with
      | none => fail "no game yet: send new_game first"
      | some s =>
        match s.review n with
        | .error e => fail e
        | .ok lines => (cur, Json.mkObj [("ok", toJson true), ("state", unchanged), ("review", reviewJson s n lines)])
    | .ok (.game c) =>
      match Session.handle cur c with
      | .error e => fail e
      | .ok s => (some s, Json.mkObj [("ok", toJson true), ("state", stateJson s)])
