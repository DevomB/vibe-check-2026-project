import Engine.Hand

/-!
# Engine tests: scripted hands

Each test plays a short hand and checks where the chips went. Every test also checks
that the chips add up to 1,000 at the end.
-/

/-- Play a list of moves, stopping at the first rejected one. -/
def play (h : Hand) : List Action → Except String Hand
  | [] => .ok h
  | a :: rest => do play (← step h a) rest

/-- A fresh hand: 500 chips each, player 0 on the button, seed 7. -/
def fresh : Hand := startHand (fun _ => 500) 0 7

/-- Did the moves play out, with the chips still adding up to 1,000? -/
def conserves (h : Hand) (moves : List Action) : Bool :=
  match play h moves with
  | .ok h' => h'.chips.total == 1000
  | .error _ => false

def stacksAfter (h : Hand) (moves : List Action) : Option (Nat × Nat) :=
  match play h moves with
  | .ok h' => some (h'.chips.stack 0, h'.chips.stack 1)
  | .error _ => none

def endedAfter (h : Hand) (moves : List Action) : Bool :=
  match play h moves with
  | .ok h' => h'.ended.isSome
  | .error _ => false

def rejected (h : Hand) (moves : List Action) : Bool :=
  match play h moves with
  | .ok _ => false
  | .error _ => true

-- A new hand: blinds posted, the button (player 0, small blind) acts first.
#guard fresh.chips.stack 0 == 495 && fresh.chips.stack 1 == 490
#guard fresh.chips.bet 0 == 5 && fresh.chips.bet 1 == 10
#guard fresh.chips.toAct == 0
#guard fresh.chips.total == 1000
#guard (fresh.hole 0).length == 2 && (fresh.hole 1).length == 2
#guard fresh.deck.length == 48

-- The small blind folds: the big blind wins 5.
#guard stacksAfter fresh [.fold] == some (495, 505)
#guard endedAfter fresh [.fold]

-- The small blind calls; the big blind still gets to act (the "option").
#guard match play fresh [.call] with
  | .ok h => h.chips.toAct == 1 && h.street == .preflop && h.ended.isNone
  | .error _ => false

-- Call, check: on to the flop. Three cards dealt, the big blind acts first.
#guard match play fresh [.call, .check] with
  | .ok h => h.street == .flop && h.board.length == 3 && h.chips.pot == 20
      && h.chips.toAct == 1 && h.deck.length == 44
  | .error _ => false

-- Checked all the way down: a showdown, with all 1,000 chips back in the stacks.
def checkDown : List Action := [.call, .check, .check, .check, .check, .check, .check, .check]
#guard endedAfter fresh checkDown
#guard conserves fresh checkDown
#guard match play fresh checkDown with
  | .ok h => h.board.length == 5 && h.chips.pot == 0
  | .error _ => false

-- Preflop all-in and call: the board is dealt out to the river with nobody acting.
#guard match play fresh [.raiseTo 500, .call] with
  | .ok h => h.ended.isSome && h.board.length == 5 && h.chips.total == 1000
      && (h.chips.stack 0 == 0 || h.chips.stack 1 == 0 || h.chips.stack 0 == 500)
  | .error _ => false

-- A raise and a fold: the raiser wins the big blind and gets the raise back.
#guard stacksAfter fresh [.raiseTo 30, .fold] == some (510, 490)

-- A raise, a re-raise, a call, then bet and fold on the flop.
#guard stacksAfter fresh [.raiseTo 30, .raiseTo 90, .call, .raiseTo 100, .fold] == some (410, 590)
#guard conserves fresh [.raiseTo 30, .raiseTo 90, .call, .raiseTo 100, .fold]

-- Illegal moves are rejected.
#guard rejected fresh [.check]               -- checking when there is a bet to call
#guard rejected fresh [.raiseTo 15]          -- raising by less than the big blind
#guard rejected fresh [.raiseTo 501]         -- more chips than you have
#guard rejected fresh [.call, .call]         -- calling when there is nothing to call
#guard rejected fresh [.fold, .call]         -- any move after the hand is over

-- The runtime must enforce the hardened spec, not just its normal turn-selection path.
#guard rejected { fresh with chips := { fresh.chips with
    stack := fun _ => 0
    bet := fun _ => 500 } } [.fold]
#guard rejected { fresh with chips := { fresh.chips with
    bet := fun p => if p = 0 then 30 else 10 } } [.raiseTo 20]

-- Posting a short blind may finish a hand immediately; no extra action is needed.
#guard let h := startHand (fun p => if p = 0 then 5 else 995) 0 7
  h.ended.isSome && h.board.length == 5 && h.chips.total == 1000

-- A rejected move leaves the hand exactly as it was.
#guard match step fresh .check with
  | .error _ => true
  | .ok _ => false

/-! ## Short all-in: the 200-chip player can't be raised once all-in -/

/-- Player 0 has 800 chips, player 1 has 200. -/
def uneven : Hand := startHand (fun p => if p = 0 then 800 else 200) 0 11

-- Player 0 raises to 150; player 1 goes all-in to 200, a raise of only 50.
-- Player 0 can call but not raise again.
#guard match play uneven [.raiseTo 150, .raiseTo 200] with
  | .ok h => h.chips.toAct == 0 && decide (Legal h.chips .call)
      && !decide (Legal h.chips (.raiseTo 300)) && !decide (Legal h.chips (.raiseTo 800))
  | .error _ => false
#guard rejected uneven [.raiseTo 150, .raiseTo 200, .raiseTo 800]
#guard conserves uneven [.raiseTo 150, .raiseTo 200, .call]

-- Player 1 calls all-in for less than the bet: the part player 1 can't match goes back.
#guard match play uneven [.raiseTo 600, .call] with
  | .ok h => h.ended.isSome && h.chips.total == 1000
      && (h.chips.stack 0 == 600 || h.chips.stack 0 == 1000 || h.chips.stack 0 == 800)
  | .error _ => false

/-! ## A whole game -/

/-- Play a game where the button always goes all-in and the other player always calls. -/
def allInGame : Nat → Game → Except String Game
  | 0, g => .ok g
  | n + 1, g =>
    if g.over then .ok g else do
    let g ← if g.hand.ended.isSome then g.nextHand else pure g
    let s := g.hand.chips
    let g ← if s.toAct == g.hand.button then
        g.act (.raiseTo (s.bet s.toAct + s.stack s.toAct))
      else g.act .call
    allInGame n g

#guard match allInGame 200 (newGame 42) with
  | .ok g => g.over && g.hand.chips.total == 1000
  | .error _ => false

/-- The button folds every hand: the blinds go back and forth, and the game goes on. -/
def foldGame : Nat → Game → Except String Game
  | 0, g => .ok g
  | n + 1, g => do
    let g ← if g.hand.ended.isSome then g.nextHand else pure g
    foldGame n (← g.act .fold)

#guard match foldGame 10 (newGame 1) with
  | .ok g => g.handNo == 10 && !g.over && g.hand.chips.total == 1000
      && g.hand.chips.stack 0 == 500 && g.hand.chips.stack 1 == 500
  | .error _ => false

/-! ## Random games

Play many games with random legal moves. After every move the chips must add up to 1,000,
no legal move may be rejected, and every game must finish. -/

/-- Pick one legal move at random: all-in 1 time in 40, fold 1 in 10, a raise (minimum, or
two big blinds more) about 1 in 4, otherwise check or call. Folds and all-ins are rare so
that games last many hands. -/
def randomMove (s : State) (r : Nat) : Action :=
  let me := s.toAct
  let allIn := s.bet me + s.stack me
  let minRaise := s.bet (other me) + s.lastRaise
  let legal (moves : List Action) := moves.filter fun a => decide (Legal s a)
  let tries : List (List Action) :=
    if r % 40 == 0 then [[.raiseTo allIn]]
    else if r % 10 == 1 then [[.fold]]
    else if r % 4 == 2 then
      [[.raiseTo (min minRaise allIn), .raiseTo (min (minRaise + 2 * bigBlind) allIn)]]
    else []
  -- If the chosen kind of move is not legal here, check or call instead.
  let fallback : List (List Action) := [[.check, .call], [.fold]]
  let pool := ((tries ++ fallback).map legal).find? (!·.isEmpty) |>.getD []
  pool[(r / 40) % pool.length]?.getD .fold

/-- Play up to `n` moves; `none` means a rule was broken. -/
def randomGame : Nat → Nat → Game → Option Game
  | 0, _, g => some g
  | n + 1, r, g =>
    if g.over then some g else
    let g := if g.hand.ended.isSome then (g.nextHand.toOption.getD g) else g
    match g.act (randomMove g.hand.chips (mixSeed r)) with
    | .error _ => none
    | .ok g' => if g'.hand.chips.total != 1000 then none else randomGame n (nextSeed r) g'

-- Every one of 300 random games keeps the chips at 1,000 and finishes within 20,000 moves.
#guard (List.range 300).all fun seed =>
  match randomGame 20000 seed (newGame seed) with
  | some g => g.over && g.hand.chips.total == 1000
  | none => false

#eval fresh.summary
#eval (play fresh checkDown).map Hand.summary
#eval (allInGame 200 (newGame 42)).map fun g => s!"game over after {g.handNo} hands: {g.hand.summary}"
