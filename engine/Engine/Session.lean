import Engine.Bot
import Engine.Slider
import Engine.Review

/-!
# Engine: one game session, as the game program runs it

Everything the game program does between reading a command and writing its reply, as pure
functions, so it can be tested with `#guard` and proven about. `Engine/Protocol.lean` turns
JSON into `Command`s and sessions into JSON; `Main.lean` only reads and writes lines.

After every accepted command, the bot plays (`Session.runBot`) until it is the human's turn
or the hand is over (MVP §7). The browser never decides a bot move.

Player 0 is the human, player 1 is the bot.
-/

/-- The human is player 0, the bot is player 1. -/
def human : Player := 0
def bot : Player := 1

/-- Something that happened since the last reply, for the screen to show one at a time. -/
inductive Event where
  /-- A blind was posted. -/
  | blind (p : Player) (amount : Nat) (small : Bool)
  /-- A move. `paid` is the chips it put in; `allIn` says the player has none left. -/
  | move (p : Player) (a : Action) (paid : Nat) (allIn : Bool)
  /-- Board cards were dealt for a street. -/
  | street (name : Street) (cards : List Card)
  /-- A player won chips at the end of the hand. -/
  | win (p : Player) (amount : Nat)

/-- One move the human made, kept for the review. -/
structure Decision where
  street : Street
  /-- "fold", "check", "call", "bet" or "raise". -/
  action : String
  /-- Only for a call or fold that answers the bot's opening river bet: what to grade. -/
  graded : Option (RiverSpot × RiverChoice) := none

/-- What is kept about one hand for its review: the human's moves and the bot's reasons. -/
structure HandLog where
  decisions : Array Decision := #[]
  /-- One plain sentence per bot move, in order. Shown only once the hand is over. -/
  reasons : Array String := #[]
  /-- For each bot move, in order: what `botDecide` was given apart from the sliders (the
  hand's seed, the bot's cards, the board, the chips) and the move made. The review's Risk
  explorer (`Engine/Explain.lean`) decides again from these; nothing is worked out here. -/
  botMoves : Array (Nat × List Card × List Card × State × Action) := #[]

/-- What the game program remembers between commands. -/
structure Session where
  game : Game
  sliders : Sliders
  /-- Each player's latest move this betting round, for display ("Call", "Bet 60"). -/
  labels : Player → Option String := fun _ => none
  /-- What happened since the last reply. -/
  events : Array Event := #[]
  /-- Chips each player won in the hand that just ended (the pot or their share of it). -/
  winnings : Player → Nat := fun _ => 0
  /-- Set while the human must answer the bot's opening river bet: the spot to grade. -/
  riverSpot : Option RiverSpot := none
  /-- One log per hand dealt so far. Hand `n` is at index `n - 1`. -/
  logs : Array HandLog := #[]

/-- The requests that may change the game. (A review never does: see `Session.review`.) -/
inductive Command where
  | newGame (seed risk bluffPct : Nat)
  | act (a : Action)
  | nextHand
  | state

/-! ## Results and labels -/

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
def streetEvents (before after : List Card) : Array Event :=
  #[(Street.flop, 0, 3), (.turn, 3, 4), (.river, 4, 5)].filterMap fun (name, lo, hi) =>
    if before.length ≤ lo && hi ≤ after.length then
      some (.street name ((after.drop lo).take (hi - lo)))
    else none

/-- Events for the chips each player won. -/
def winEvents (won : Player → Nat) : Array Event :=
  (#[0, 1] : Array Player).filterMap fun p => if won p > 0 then some (.win p (won p)) else none

/-- A move as the table shows it: "Call", "Bet 60", "Raise to 120", "All-in". -/
def moveLabel (s : State) (a : Action) (allIn : Bool) : String :=
  match a with
  | .fold => "Fold"
  | .check => "Check"
  | .call => if allIn then "All-in" else "Call"
  | .raiseTo n =>
    if allIn then "All-in" else if max (s.bet 0) (s.bet 1) == 0 then s!"Bet {n}" else s!"Raise to {n}"

/-- A move as one word for the review: a raise with no bet to answer is a "bet". -/
def moveWord (s : State) : Action → String
  | .fold => "fold"
  | .check => "check"
  | .call => "call"
  | .raiseTo _ => if max (s.bet 0) (s.bet 1) == 0 then "bet" else "raise"

/-! ## Playing -/

/-- Change the log of the current hand. -/
def Session.logHand (s : Session) (f : HandLog → HandLog) : Session :=
  { s with logs := s.logs.modify (s.logs.size - 1) f }

/-- The player to act makes move `a`: the hand moves on, and the event, the move label and
any winnings are recorded. -/
def Session.move (s : Session) (a : Action) : Except String Session := do
  let h := s.game.hand
  let me := h.chips.toAct
  let g' ← s.game.act a
  let h' := g'.hand
  let moved := applyMove h.chips a
  let paid := h.chips.stack me - moved.stack me
  let allIn := moved.stack me == 0
  -- A new betting round clears the move labels.
  let labels := if h'.board.length != h.board.length then fun _ => none
    else setFor s.labels me (some (moveLabel h.chips a allIn))
  let won := winningsOf h' (if a matches .fold then h.chips else moved)
  return { s with game := g', labels, winnings := won,
                  events := s.events.push (.move me a paid allIn)
                    ++ streetEvents h.board h'.board ++ winEvents won }

/-- Is it the bot's turn in a hand still being played? -/
def Session.botToAct (s : Session) : Bool :=
  s.game.hand.ended.isNone && s.game.hand.chips.toAct == bot

/-- The bot's move now, from its sliders, its own cards, the board and the chips. Its only
randomness is the seed of this hand. -/
def Session.botChoice (s : Session) : BotChoice :=
  let h := s.game.hand
  botDecide s.sliders (handSeed s.game.seed s.game.handNo) (h.hole bot) h.board h.chips

/-- Enough moves for any hand: each of four betting rounds needs fewer than 50, since every
raise puts at least 10 more chips in and there are only 1,000 chips. -/
def botFuel : Nat := 200

/-- The bot plays until it is the human's turn or the hand is over. `fuel` bounds the number
of bot moves, so this always finishes.

When the bot opens the river with a bet (no bet to face, it bets) and the human must
answer, the spot is kept for the review. -/
def Session.runBot : Nat → Session → Session
  | 0, s => s
  | fuel + 1, s =>
    if !s.botToAct then s else
    let h := s.game.hand
    let c := s.botChoice
    match s.move c.action with
    -- Never happens in the app: there the session's game is always reachable, and then the
    -- engine accepts the bot's move (`Session.botChoice_accepted`, Engine/Proofs/Session.lean).
    | .error _ => s
    | .ok next =>
      let next := next.logHand fun l => { l with reasons := l.reasons.push c.reason }
      let next := next.logHand fun l => { l with botMoves := l.botMoves.push (handSeed s.game.seed s.game.handNo, h.hole bot, h.board, h.chips, c.action) }
      let h' := next.game.hand
      let opensRiver := h.board.length == 5 && h.chips.toCall == 0 && c.action matches .raiseTo _
      let next := if opensRiver && h'.ended.isNone && h'.chips.toAct == human then
          { next with riverSpot := some (riverSpotOf h' s.sliders.bluffPct) }
        else next
      Session.runBot fuel next

/-- A new hand `g.hand` has been dealt from `stacks`: record the blinds (and the board and
winner, if the blinds already put someone all-in), start its log, and let the bot play if
it acts first. -/
def Session.dealt (s : Session) (g : Game) (stacks : Player → Nat) : Session :=
  let h := g.hand
  let posted := dealHand stacks h.button (handSeed g.seed g.handNo)
  let won := winningsOf h posted.chips
  let s := { s with
    game := g
    labels := fun p => if p = h.button then some "SB" else some "BB"
    events := #[.blind h.button (posted.chips.bet h.button) true,
                .blind (other h.button) (posted.chips.bet (other h.button)) false]
      ++ streetEvents [] h.board ++ winEvents won
    winnings := won
    riverSpot := none
    logs := s.logs.push {} }
  Session.runBot botFuel s

/-- A new game with the given sliders. Risk must be 0 to 100 and Bluff 0 to 60. -/
def Session.start (seed risk bluffPct : Nat) : Except String Session := do
  if risk > 100 then throw "risk must be 0-100"
  if bluffPct > 60 then throw "bluff_pct must be 0-60"
  let g := newGame seed
  return Session.dealt { game := g, sliders := ⟨risk, bluffPct⟩ } g (fun _ => startingStack)

/-- The human makes move `a`, then the bot plays. A call or fold that answers the bot's
opening river bet is kept for grading; a raise is not graded. -/
def Session.humanAct (s : Session) (a : Action) : Except String Session := do
  let h := s.game.hand
  if h.ended.isSome then throw "the hand is over"
  if h.chips.toAct ≠ human then throw "it is not your turn"
  let next ← s.move a
  let graded := match s.riverSpot, a with
    | some spot, .call => some (spot, RiverChoice.call)
    | some spot, .fold => some (spot, .fold)
    | _, _ => none
  let d : Decision := { street := h.street, action := moveWord h.chips a, graded }
  let next := { next with riverSpot := none }.logHand fun l => { l with decisions := l.decisions.push d }
  return Session.runBot botFuel next

/-- Run one command. Each reply lists only what happened during this command. A rejected
command gives a reason, and the caller keeps the old session. -/
def Session.handle : Option Session → Command → Except String Session
  | _, .newGame seed risk bluffPct => Session.start seed risk bluffPct
  | none, _ => throw "no game yet: send new_game first"
  | some s, .state => pure { s with events := #[] }
  | some s, .act a => { s with events := #[] }.humanAct a
  | some s, .nextHand => do
    let g ← s.game.nextHand
    return { s with events := #[] }.dealt g s.game.hand.chips.stack

/-- The bot's reasons for the current hand, only once it is over (MVP §2: while the hand
is played, the bot's messages stay generic). -/
def Session.botReasons (s : Session) : Option (Array String) :=
  if s.game.hand.ended.isSome then s.logs.back?.map (·.reasons) else none

/-- The bot's reasons for hand `n`, once that hand is over. -/
def Session.reasonsFor (s : Session) (n : Nat) : Option (Array String) :=
  if n = 0 then none
  else if n = s.game.handNo then s.botReasons else s.logs[n - 1]?.map (·.reasons)

/-! ## Review -/

/-- One line of a hand's review: a move the human made, and its grade if it was graded. -/
structure ReviewLine where
  street : Street
  action : String
  verdict : Option RiverVerdict

/-- The review of hand `n`: every move the human made in it, in order, with a grade for each
graded one. Reading a review changes nothing and uses no randomness. -/
def Session.review (s : Session) (n : Nat) : Except String (Array ReviewLine) := do
  if n = 0 then throw "no review for that hand"
  let some log := s.logs[n - 1]? | throw "no review for that hand"
  return log.decisions.map fun d =>
    { street := d.street, action := d.action,
      verdict := d.graded.map fun (spot, choice) => reviewRiver spot choice }
