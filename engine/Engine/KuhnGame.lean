import Engine.Proofs.Kuhn

/-!
# A playable Kuhn poker game

The rules are in `Engine/Proofs/KuhnSpec.lean`. This file is the game itself: dealing, the
moves, which moves are allowed, who wins, and the bot. The bot plays the equilibrium
strategies of `Engine/Proofs/Kuhn.lean`, choosing with a random number so that each choice is
taken exactly as often as the strategy says. `Engine/Proofs/KuhnGame.lean` proves this game
gives the results the theory predicts. `KuhnMain.lean` lets a person play it.
-/

/-- A move in Kuhn poker. -/
inductive KMove where
  | check | bet | call | fold
  deriving DecidableEq, Repr

/-- **The rules: the five ways a hand can end.** Check, check (showdown); bet, call
(showdown); bet, fold; check, bet, call (showdown); check, bet, fold. Nothing else can happen.
(Part of the rules a reader must check, with `KuhnSpec.lean`.) -/
def kuhnEndings : List (List KMove) :=
  [[.check, .check], [.bet, .call], [.bet, .fold], [.check, .bet, .call], [.check, .bet, .fold]]

/-- The player who moves next, from the moves so far (0 is player 1, 1 is player 2), or `none`
when the hand is over. -/
def kToAct : List KMove → Option Nat
  | [] => some 0
  | [.check] => some 1
  | [.bet] => some 1
  | [.check, .bet] => some 0
  | _ => none

/-- The moves allowed after the moves so far. Nothing is allowed once the hand is over. -/
def kLegal : List KMove → List KMove
  | [] => [.check, .bet]
  | [.check] => [.check, .bet]
  | [.bet] => [.call, .fold]
  | [.check, .bet] => [.call, .fold]
  | _ => []

/-- Make a move: allowed moves are added to the hand; any other move is rejected. -/
def kStep (moves : List KMove) (m : KMove) : Except String (List KMove) :=
  if m ∈ kLegal moves then .ok (moves ++ [m]) else .error "illegal move"

/-- What player 1 wins or loses, in chips, when the hand ends with these moves (the table in
`KuhnSpec.lean`). -/
def kResult (c1 c2 : KCard) : List KMove → Int
  | [.check, .check] => showdownFor c1 c2 1
  | [.bet, .call] => showdownFor c1 c2 2
  | [.bet, .fold] => 1
  | [.check, .bet, .call] => showdownFor c1 c2 2
  | [.check, .bet, .fold] => -1
  | _ => 0

/-- The deal for a random number: one of the six deals, `n % 6`. -/
def kDeal (n : Nat) : KCard × KCard :=
  kuhnDeals.getD (n % 6) (.jack, .queen)

/-! ## The bot -/

/-- The three lines of play player 1 can choose with a card. -/
inductive P1Line where
  | bet | checkCall | checkFold
  deriving DecidableEq, Repr

/-- The bot as player 1 chooses a line for its card with a random number `r`: out of the three
values of `r % 3`, it takes each line as many times as its weight in `p1Equilibrium`. -/
def botP1Line (c : KCard) (r : Nat) : P1Line :=
  let p := p1Equilibrium c
  if r % 3 < p.bet then .bet
  else if r % 3 < p.bet + p.checkCall then .checkCall
  else .checkFold

/-- The move for player 1's line, after the moves so far. -/
def P1Line.move (l : P1Line) : List KMove → KMove
  | [] => if l = .bet then .bet else .check
  | _ => if l = .checkCall then .call else .fold

/-- The bot as player 2, with card `c` and random number `r`: after a check it bets for as many
values of `r % 3` as its weight says, and after a bet it calls for as many as its weight says. -/
def botP2Move (c : KCard) (r : Nat) : List KMove → KMove
  | [.check] => if r % 3 < (p2Equilibrium c).bet then .bet else .check
  | _ => if r % 3 < (p2Equilibrium c).call then .call else .fold

/-! ## Playing a hand -/

/-- Play a hand: ask whoever is to act for a move, until the hand is over (at most three
moves). `p1` and `p2` choose a move from the moves so far. An illegal move ends the hand
early (the proofs show neither the bot nor a strategy below ever makes one). -/
def kPlay (p1 p2 : List KMove → KMove) : Nat → List KMove → List KMove
  | 0, moves => moves
  | fuel + 1, moves =>
    match kToAct moves with
    | none => moves
    | some who =>
      let m := if who = 0 then p1 moves else p2 moves
      match kStep moves m with
      | .ok moves' => kPlay p1 p2 fuel moves'
      | .error _ => moves

/-- A whole hand from the start. -/
def kHand (p1 p2 : List KMove → KMove) : List KMove := kPlay p1 p2 3 []

/-! ## A human's choices, for the proofs

A person's way of playing, written as a fixed choice for each card (a "pure strategy"). Any
way of mixing choices at random is a weighted mix of these. -/

/-- A human as player 1: a line of play for each card. -/
abbrev HumanP1 := KCard → P1Line

/-- A human as player 2, for each card: bet after a check or not, and call a bet or not. -/
structure P2Choice where
  betAfterCheck : Bool
  callBet : Bool
  deriving DecidableEq, Repr

abbrev HumanP2 := KCard → P2Choice

/-- The move for player 2's choice, after the moves so far. -/
def P2Choice.move (ch : P2Choice) : List KMove → KMove
  | [.check] => if ch.betAfterCheck then .bet else .check
  | _ => if ch.callBet then .call else .fold

/-- A human player 1's choices as a strategy in the theory's terms (weights out of 1). -/
def HumanP1.weights (h : HumanP1) : P1Strategy := fun c =>
  match h c with
  | .bet => ⟨1, 0, 0⟩
  | .checkCall => ⟨0, 1, 0⟩
  | .checkFold => ⟨0, 0, 1⟩

/-- A human player 2's choices as a strategy in the theory's terms (weights out of 1). -/
def HumanP2.weights (h : HumanP2) : P2Strategy := fun c =>
  ⟨if (h c).betAfterCheck then 1 else 0, if (h c).betAfterCheck then 0 else 1,
   if (h c).callBet then 1 else 0, if (h c).callBet then 0 else 1⟩

/-- The three values of the bot's random number, each equally likely. -/
def botRolls : List Nat := [0, 1, 2]

/-- Bot as player 1 against a human player 2: player 1's winnings added up over all six deals
and all three bot rolls, each of the 18 equally likely. Divide by 18 for the average. -/
def botP1Total (h : HumanP2) : Int :=
  (kuhnDeals.flatMap fun (c1, c2) => botRolls.map fun r =>
    kResult c1 c2 (kHand ((botP1Line c1 r).move) ((h c2).move))).sum

/-- Human player 1 against the bot as player 2: player 1's winnings added up over all six deals
and all three bot rolls. Divide by 18 for the average. -/
def botP2Total (h : HumanP1) : Int :=
  (kuhnDeals.flatMap fun (c1, c2) => botRolls.map fun r =>
    kResult c1 c2 (kHand ((h c1).move) (botP2Move c2 r))).sum
