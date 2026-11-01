import Engine.Session
import Engine.Explain
import Engine.HandName
import Lean.Data.Json

/-!
# Engine: the game program's JSON messages

One JSON request per line in, one JSON reply per line out (MVP §13). `respond` reads one
request, runs it on the session (`Engine/Session.lean`) and writes the reply. It decides no
rule itself.

Requests:
- `{"cmd":"new_game","seed":"42","risk":50}`: the seed is a number or a string of digits;
  Risk is a whole number from 0 to 100, the one slider the player sets (`Sliders.ofRisk`
  turns it into the bot's two internal settings). A `bluff_pct` field is an error: Bluff is
  no longer set on its own.
- `{"cmd":"act","action":"call"}`, with `action` one of fold, check, call, raise;
  a raise also needs `"amount"`, the player's total bet for this round.
- `{"cmd":"next_hand"}`, `{"cmd":"state"}`
- `{"cmd":"review","hand":3}`: the review of hand 3. It changes nothing.

Any request may add `"peek":true` (the "Peek at bot's cards" toggle). Then the reply's state
also shows the bot's two cards. Peeking changes nothing else: not the game, not the seed, and
not when the bot's reasons are sent.

Replies: `{"ok":true,"state":...}`, plus `"review":...` for a review. A rejected request gets
`{"error":"...","state":...}` with the state unchanged. Without `peek`, the bot's cards are
only sent once the hand reaches a showdown. Its reasons are only sent once the hand is over.

The state's `sliders` is `{"risk": 50, "caution": 0, "bluffPct": 33}`: the player's Risk,
then the two internal settings it maps to.
-/

open Lean

/-! ## Game values as JSON -/

/-- Cards as a list of strings such as `"Ah"`. -/
def cardsJson (cs : List Card) : Json := toJson (cs.map Card.toString)

/-- A street's name: `"preflop"`, `"flop"`, `"turn"` or `"river"`. -/
def streetName : Street → String
  | .preflop => "preflop" | .flop => "flop" | .turn => "turn" | .river => "river"

/-- A move's name in events: `"fold"`, `"check"`, `"call"` or `"raise"` (a bet is a raise
in the engine; the `to` field gives the street total). -/
def actionName : Action → String
  | .fold => "fold" | .check => "check" | .call => "call" | .raiseTo _ => "raise"

/-- One event as JSON, with a `type` of `blind`, `action`, `street` or `win`. -/
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

/-- The table as the human may see it. With `peek`, the bot's cards are shown too. `commit` is
the commit the program was built from (`Main.lean`), for the replay record. -/
def stateJson (srv : Session) (peek : Bool := false) (commit : String := "unknown") : Json :=
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
        ("cards", if shown || peek then cardsJson (h.hole p) else Json.null),
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
      -- The player's Risk, and the two internal settings `Sliders.ofRisk` makes of it.
      ("sliders", Json.mkObj [("risk", toJson srv.risk), ("caution", toJson srv.sliders.risk),
        ("bluffPct", toJson srv.sliders.bluffPct)]),
      ("botReasons", match srv.botReasons with | some rs => toJson rs | none => Json.null),
      -- Replay record (MVP §5, §15). The turn is always counted exactly: see the mode note
      -- "Turn: exact" in `Engine/Equity.lean`.
      ("turnMode", toJson "exact"),
      ("engineCommit", toJson commit) ]

/-- The river range viewer's six numbers (`rangeOf`, `Engine/Explain.lean`). -/
def RangeSummary.json (r : RangeSummary) : Json :=
  Json.mkObj
    [ ("value", toJson r.value), ("bluffs", toJson r.bluffs), ("blocked", toJson r.blocked),
      ("beat", toJson r.beat), ("tie", toJson r.tie), ("lose", toJson r.lose) ]

/-- One bot move in the Risk explorer (`exploreHandAt`, `Engine/Explain.lean`). Moves are
named as the table names them ("Call", "Bet 60"); `actions` has one per Risk from 0 to 100,
the player's Risk. `continuesFrom` is the lowest Risk at which the bot calls, raises or bets,
or `null`. -/
def RiskExplorerEntry.json (e : RiskExplorerEntry) : Json :=
  Json.mkObj
    [ ("street", toJson (streetName e.street)),
      ("pot", toJson e.pot),
      ("toCall", toJson e.toCall),
      ("counts", Json.mkObj
        [("win", toJson e.counts.win), ("tie", toJson e.counts.tie), ("loss", toJson e.counts.loss)]),
      ("risk", toJson e.risk),
      ("action", toJson (moveText e.state e.action)),
      ("actions", toJson (e.moves.map (moveText e.state))),
      ("continuesFrom", match e.continuesFrom with | some k => toJson k | none => Json.null),
      ("riskMatters", toJson e.riskMatters),
      ("effect", toJson e.effect.name),
      ("summary", toJson e.effect.summary) ]

/-- The review of hand `n` (MVP §13). Ungraded moves have `null` grades: "not graded yet".
A graded move also has `range`: the river range viewer's numbers. `risk_explorer` has one
entry per bot move, or is `null` while hand `n` is played. -/
def reviewJson (srv : Session) (n : Nat) (lines : Array ReviewLine) : Json :=
  let ranges := srv.ranges n
  let line (i : Nat) (l : ReviewLine) : Json :=
    let grade (f : RiverVerdict → Json) := match l.verdict with | some v => f v | none => Json.null
    Json.mkObj <|
      [ ("street", toJson (streetName l.street)),
        ("your_action", toJson l.action),
        ("label", grade (toJson ·.label.name)),
        ("worth_bb", grade fun v =>
          Json.mkObj [("call", v.worthCall.json 2), ("fold", v.worthFold.json 2)]),
        ("equity_had", grade (·.equityHad.json 3)),
        ("equity_needed", grade (·.equityNeeded.json 3)) ]
      ++ match ranges[i]?.join with
        | some r => [("range", r.json)]
        | none => []
  Json.mkObj
    [("hand", toJson n), ("decisions", Json.arr (lines.mapIdx line)),
     -- Like `botReasons`: `null` while hand `n` is still being played.
     ("bot_reasons", match srv.reasonsFor n with | some rs => toJson rs | none => Json.null),
     -- Also `null` while hand `n` is played: the counts show how strong the bot's hand was.
     ("risk_explorer", match srv.riskExplorer n with
       | some es => Json.arr (es.toArray.map RiskExplorerEntry.json)
       | none => Json.null)]

/-! ## Reading requests -/

/-- A request: a command that may change the game, or a review that never does. -/
inductive Request where
  | game (c : _root_.Command)
  | review (hand : Nat)

/-- The move in an `act` request. `bet` and `raise` both need `amount`, the street total. -/
def parseAction (j : Json) : Except String Action := do
  match ← j.getObjValAs? String "action" with
  | "fold" => pure .fold
  | "check" => pure .check
  | "call" => pure .call
  | "bet" | "raise" => return .raiseTo (← j.getObjValAs? Nat "amount")
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

/-- The optional `"peek"` flag of any request. Missing means `false`. -/
def parsePeek (j : Json) : Except String Bool :=
  match j.getObjVal? "peek" with
  | .error _ => pure false
  | .ok v =>
    match v.getBool? with
    | .ok b => pure b
    | .error _ => throw "peek must be true or false"

/-- Read one request. Unknown commands, such as the old `bot`, are rejected. -/
def parseRequest (j : Json) : Except String Request := do
  match ← j.getObjValAs? String "cmd" with
  | "new_game" =>
    -- A caller still sending the old Bluff slider fails loudly instead of being ignored.
    if let .ok _ := j.getObjVal? "bluff_pct" then throw "bluff_pct was removed; Risk sets both"
    return .game (.newGame (← parseSeed j) (← parseUpTo j "risk" 100 "risk must be 0-100"))
  | "act" => return .game (.act (← parseAction j))
  | "next_hand" => return .game .nextHand
  | "state" => return .game .state
  | "review" => return .review (← j.getObjValAs? Nat "hand")
  | other => throw s!"unknown command '{other}'"

/-! ## One request, one reply -/

/-- Answer one request line. Returns the session to keep and the reply. A rejected request
keeps the old session, so it changes nothing. `peek` only changes how the state is written,
never the session. `commit` goes into every state, for the replay record. -/
def respond (cur : Option Session) (line : String) (commit : String := "unknown") : Option Session × Json :=
  let unchanged (peek : Bool) : Json := match cur with
    | some s => stateJson { s with events := #[] } peek commit
    | none => Json.null
  let fail (e : String) (peek : Bool) := (cur, Json.mkObj [("error", toJson e), ("state", unchanged peek)])
  match Json.parse line with
  | .error e => fail s!"bad JSON: {e}" false
  | .ok j =>
    match parsePeek j with
    | .error e => fail e false
    | .ok peek =>
    match parseRequest j with
    | .error e => fail e peek
    | .ok (.review n) =>
      match cur with
      | none => fail "no game yet: send new_game first" peek
      | some s =>
        match s.review n with
        | .error e => fail e peek
        | .ok lines =>
          (cur, Json.mkObj [("ok", toJson true), ("state", unchanged peek), ("review", reviewJson s n lines)])
    | .ok (.game c) =>
      match Session.handle cur c with
      | .error e => fail e peek
      | .ok s => (some s, Json.mkObj [("ok", toJson true), ("state", stateJson s peek commit)])
