import Poker
import Engine.Deck

/-!
# Engine: playing one hand

Heads-up no-limit Hold'em, following `SPEC.md` and `MVP.txt` section 4.
The chips live in the spec's own `State`, and a move is accepted only if the spec's
`Legal` allows it, so the theorems about the spec are theorems about this code.

Ported from the TypeScript prototype `src/engine/game.ts`.
-/

/-- Small blind, big blind and starting stack, from `MVP.txt`. -/
def smallBlind : Nat := 5
def bigBlind : Nat := 10
def startingStack : Nat := 500

/-- `Legal` can be checked by running code. -/
instance (s : State) (a : Action) : Decidable (Legal s a) := by
  cases a <;> dsimp only [Legal] <;> infer_instance

/-- The four betting rounds. -/
inductive Street where
  | preflop | flop | turn | river
  deriving DecidableEq, Repr

/-- How a finished hand ended. -/
inductive HandEnd where
  /-- The other player folded, so `winner` took the pot without a showdown. -/
  | folded (winner : Player)
  /-- Both players showed their cards. -/
  | showdown (result : Outcome)
  deriving Repr

/-- Everything about one hand in progress. -/
structure Hand where
  /-- Stacks, pot, bets, last raise and whose turn it is. -/
  chips : State
  street : Street
  /-- The player on the button. They post the small blind, act first before the flop
  and last after it. -/
  button : Player
  /-- Each player's two hidden cards. -/
  hole : Player → List Card
  /-- The shared cards on the table: 0, 3, 4 or 5 of them. -/
  board : List Card
  /-- The cards not yet dealt, top card first. -/
  deck : List Card
  /-- Who has acted since this betting round began, or since the last raise. -/
  acted : Player → Bool
  /-- `none` while the hand is being played. -/
  ended : Option HandEnd

/-! ## Small helpers -/

/-- A per-player table with one player's entry changed. -/
def setFor {β : Type} (f : Player → β) (p : Player) (v : β) : Player → β :=
  fun q => if q = p then v else f q

/-- Does player `p` still have to act in this betting round? Not if they are all-in.
Yes if they have not matched the other bet. Otherwise only if they have not acted yet
and the other player still has chips to answer them with. -/
def Hand.needsAction (h : Hand) (p : Player) : Bool :=
  0 < h.chips.stack p &&
    (h.chips.bet p < h.chips.bet (other p) || (!h.acted p && 0 < h.chips.stack (other p)))

/-- Move chips for a check, call or raise by the player to act. Folding moves no chips. -/
def applyMove (s : State) : Action → State
  | .fold | .check => s
  | .call =>
    -- Pay what is owed, or everything you have if that is less (all-in).
    let me := s.toAct
    let pay := min s.toCall (s.stack me)
    { s with stack := setFor s.stack me (s.stack me - pay),
             bet := setFor s.bet me (s.bet me + pay) }
  | .raiseTo n =>
    let me := s.toAct
    let pay := n - s.bet me
    let raiseSize := n - s.bet (other me)
    { s with stack := setFor s.stack me (s.stack me - pay),
             bet := setFor s.bet me (s.bet me + pay),
             -- A full raise sets the new minimum raise. A short all-in does not.
             lastRaise := if s.lastRaise ≤ raiseSize then raiseSize else s.lastRaise }

/-- If one player bet more than the other could match, give back the part nobody matched. -/
def returnUncalled (s : State) : State :=
  if s.bet 1 < s.bet 0 then
    { s with stack := setFor s.stack 0 (s.stack 0 + (s.bet 0 - s.bet 1)),
             bet := setFor s.bet 0 (s.bet 1) }
  else if s.bet 0 < s.bet 1 then
    { s with stack := setFor s.stack 1 (s.stack 1 + (s.bet 1 - s.bet 0)),
             bet := setFor s.bet 1 (s.bet 0) }
  else s

/-- End of a betting round: the bets go into the pot, and the minimum raise goes back to
the big blind. -/
def collectBets (s : State) : State :=
  { s with pot := s.pot + s.bet 0 + s.bet 1, bet := fun _ => 0, lastRaise := bigBlind }

/-- Burn one card, then deal `n` cards onto the board. -/
def Hand.dealBoard (h : Hand) (n : Nat) : Hand :=
  let rest := h.deck.drop 1
  { h with board := h.board ++ rest.take n, deck := rest.drop n }

/-- Showdown: the better hand takes the pot. On a tie the pot is split; an odd chip goes
to the big blind (the player who is not on the button). -/
def Hand.payShowdown (h : Hand) : Hand :=
  let result := showdown (h.hole 0) (h.hole 1) h.board
  let s := h.chips
  let half := s.pot / 2
  let bigBlindPlayer := other h.button
  let won : Player → Nat := match result with
    | .player0 => fun p => if p = 0 then s.pot else 0
    | .player1 => fun p => if p = 1 then s.pot else 0
    | .tie => fun p => if p = bigBlindPlayer then s.pot - half else half
  { h with chips := { s with stack := fun p => s.stack p + won p, pot := 0 },
           ended := some (.showdown result) }

/-- A fold: the other player takes every chip in the middle. -/
def Hand.payFold (h : Hand) (winner : Player) : Hand :=
  let s := h.chips
  let middle := s.pot + s.bet 0 + s.bet 1
  { h with chips := { s with stack := setFor s.stack winner (s.stack winner + middle),
                             pot := 0, bet := fun _ => 0 },
           ended := some (.folded winner) }

/-- The first player who still needs to act, looking at `first` then the other player. -/
def Hand.nextToAct (h : Hand) (first : Player) : Option Player :=
  if h.needsAction first then some first
  else if h.needsAction (other first) then some (other first)
  else none

/-- A betting round is over. Collect the bets, then deal the next street, or go to showdown
after the river. If nobody can bet (someone is all-in), keep dealing until the river.
`fuel` bounds the loop; there are at most four rounds, so 4 is always enough. -/
def Hand.finishStreet : Nat → Hand → Hand
  | 0, h => h
  | fuel + 1, h =>
    let h := { h with chips := collectBets (returnUncalled h.chips), acted := fun _ => false }
    let next : Option (Street × Nat) := match h.street with
      | .preflop => some (.flop, 3)
      | .flop => some (.turn, 1)
      | .turn => some (.river, 1)
      | .river => none
    match next with
    | none => h.payShowdown
    | some (street, n) =>
      let h := { h.dealBoard n with street }
      -- After the flop, the player who is not on the button acts first.
      match h.nextToAct (other h.button) with
      | some p => { h with chips := { h.chips with toAct := p } }
      | none => Hand.finishStreet fuel h

/-- After a check, call or raise: pass the turn on, or end the betting round. -/
def Hand.afterMove (h : Hand) : Hand :=
  match h.nextToAct (other h.chips.toAct) with
  | some p => { h with chips := { h.chips with toAct := p } }
  | none => h.finishStreet 4

/-! ## The two functions the game uses -/

/-- Deal a new hand: shuffle, deal two cards each, post the blinds.
`stacks` are the chips each player brings to the hand. -/
def startHand (stacks : Player → Nat) (button : Player) (seed : Nat) : Hand :=
  let deck := shuffle seed fullDeck
  let bb := other button
  -- Deal one card at a time, starting with the player who is not on the button.
  let (hole, deck) : (Player → List Card) × List Card := match deck with
    | a :: b :: c :: d :: rest => (fun p => if p = bb then [a, c] else [b, d], rest)
    | _ => (fun _ => [], deck)   -- never happens: a new deck has 52 cards
  -- The button posts the small blind, the other player the big blind (all-in if short).
  let sbPaid := min smallBlind (stacks button)
  let bbPaid := min bigBlind (stacks bb)
  let chips : State :=
    { stack := fun p => if p = button then stacks p - sbPaid else stacks p - bbPaid
      pot := 0
      bet := fun p => if p = button then sbPaid else bbPaid
      lastRaise := bigBlind
      toAct := button }
  let h : Hand :=
    { chips, street := .preflop, button, hole, board := [], deck,
      acted := fun _ => false, ended := none }
  -- Before the flop, the button acts first.
  match h.nextToAct button with
  | some p => { h with chips := { h.chips with toAct := p } }
  | none => h.finishStreet 4

/-- The player whose turn it is makes a move. An illegal move, or any move after the hand
is over, is rejected with a reason, and the hand does not change. -/
def step (h : Hand) (a : Action) : Except String Hand :=
  if h.ended.isSome then .error "the hand is over"
  else if ¬ Legal h.chips a then .error "illegal move"
  else
    let me := h.chips.toAct
    match a with
    | .fold => .ok (h.payFold (other me))
    | _ =>
      let acted := setFor h.acted me true
      -- After a raise, the other player has to act again.
      let acted := match a with
        | .raiseTo _ => setFor acted (other me) false
        | _ => acted
      .ok ({ h with chips := applyMove h.chips a, acted }).afterMove

/-! ## Several hands in a row -/

/-- A game: hands are played until one player has all the chips. -/
structure Game where
  hand : Hand
  /-- Number of the current hand, starting at 1. -/
  handNo : Nat
  /-- The seed the game started from. -/
  seed : Nat

/-- The seed for hand number `n` of a game started from `seed`. -/
def handSeed (seed n : Nat) : Nat := nextSeed (seed + n * 1000003)

/-- A new game: 500 chips each, player 0 on the button. -/
def newGame (seed : Nat) : Game :=
  { hand := startHand (fun _ => startingStack) 0 (handSeed seed 1), handNo := 1, seed }

/-- The game is over when a hand has ended and one player has no chips left. -/
def Game.over (g : Game) : Bool :=
  g.hand.ended.isSome && (g.hand.chips.stack 0 == 0 || g.hand.chips.stack 1 == 0)

/-- Start the next hand. The button moves to the other player. -/
def Game.nextHand (g : Game) : Except String Game :=
  if g.hand.ended.isNone then .error "the hand is not over yet"
  else if g.over then .error "the game is over"
  else
    let n := g.handNo + 1
    .ok { g with hand := startHand g.hand.chips.stack (other g.hand.button) (handSeed g.seed n),
                 handNo := n }

/-- The player whose turn it is makes a move in the current hand. -/
def Game.act (g : Game) (a : Action) : Except String Game :=
  return { g with hand := ← step g.hand a }

/-! ## For reading results -/

/-- A one-line description of a hand, for tests and debugging. -/
def Hand.summary (h : Hand) : String :=
  let s := h.chips
  s!"{repr h.street} board {h.board} stacks {s.stack 0}/{s.stack 1} pot {s.pot} " ++
  s!"bets {s.bet 0}/{s.bet 1} toAct {s.toAct} ended {repr h.ended}"
