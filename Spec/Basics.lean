/-!
# Poker spec: cards, deck, chips, legal moves

Heads-up no-limit Texas Hold'em. See `SPEC.md` for the plain-English version.
-/

/-! ## Cards and the deck -/

/-- The four suits. -/
inductive Suit where
  | clubs | diamonds | hearts | spades
  deriving DecidableEq, Repr

/-- A playing card. `rank` runs from 0 (a two) up to 12 (an ace). -/
structure Card where
  rank : Fin 13
  suit : Suit
  deriving DecidableEq, Repr

/-- A new deck: all 52 cards, each exactly once. -/
def fullDeck : List Card :=
  [Suit.clubs, .diamonds, .hearts, .spades].flatMap fun s =>
    (List.finRange 13).map fun r => ⟨r, s⟩

/-- A deck is fair if it has the same 52 cards as a new deck, in any order. -/
def FairDeck (deck : List Card) : Prop := deck.Perm fullDeck

#guard fullDeck.length == 52

/-- A new deck is fair. -/
example : FairDeck fullDeck := List.Perm.refl _

/-- A deck with a card missing is not fair. -/
example : ¬ FairDeck (fullDeck.drop 1) := by
  intro h
  have := h.length_eq
  simp [fullDeck] at this

/-! ## Players and chips -/

/-- The small blind, in chips. Blinds stay the same for the whole game (`MVP.txt`). -/
def smallBlind : Nat := 5
/-- The big blind, in chips. It is also the smallest bet or raise allowed. -/
def bigBlind : Nat := 10
/-- Chips each player has at the start of a game. -/
def startingStack : Nat := 500

/-- The two players: 0 and 1. -/
abbrev Player := Fin 2

/-- The other player. -/
def other (p : Player) : Player := if p = 0 then 1 else 0

/-- The state of a hand during betting. All amounts are in chips. -/
structure State where
  /-- Chips each player still holds. -/
  stack : Player → Nat
  /-- Chips in the pot from earlier betting rounds. -/
  pot : Nat
  /-- Chips each player has bet in the current round. -/
  bet : Player → Nat
  /-- The size of the last raise in this round (at least the big blind). -/
  lastRaise : Nat
  /-- Whose turn it is. -/
  toAct : Player

/-- All chips on the table. This number must never change during a hand. -/
def State.total (s : State) : Nat :=
  s.stack 0 + s.stack 1 + s.pot + s.bet 0 + s.bet 1

/-! ## Moves -/

/-- The moves a player can try. `raiseTo n` means "make my bet this round n chips". -/
inductive Action where
  | fold
  | check
  | call
  | raiseTo (n : Nat)

/-- How many more chips the player to act must add to match the other player's bet. -/
def State.toCall (s : State) : Nat :=
  s.bet (other s.toAct) - s.bet s.toAct

/-- The smallest amount a raise must add on top of the other player's bet: the last raise,
but never less than the big blind. -/
def State.minRaise (s : State) : Nat := max s.lastRaise bigBlind

/-- The player whose turn it is may act at all. Two things must be true:
- they still have chips (a player who is all-in is never asked to act), and
- they have not bet more than the other player (the player who is ahead never has to act). -/
def State.MayAct (s : State) : Prop :=
  0 < s.stack s.toAct ∧ s.bet s.toAct ≤ s.bet (other s.toAct)

/-- A move is legal when the rules of `SPEC.md` allow it. First, the player to act must be
allowed to act at all (`MayAct`). Then each move has its own rule. -/
def Legal (s : State) (a : Action) : Prop :=
  s.MayAct ∧
  match a with
  -- Check: only when there is nothing to call.
  | .check => s.toCall = 0
  -- Call: only when there is something to call.
  | .call => 0 < s.toCall
  -- Fold: always allowed (even when checking is free, though that is never a good idea).
  | .fold => True
  -- Raise: the other player still has chips (you can't raise someone who is all-in),
  -- beat the other bet, afford it, and raise by at least `minRaise`
  -- (unless going all-in).
  -- With two players, the first rule also means a short all-in never reopens the
  -- betting: whoever went all-in has no chips left, so the other player can only
  -- call or fold.
  | .raiseTo n =>
      0 < s.stack (other s.toAct)
      ∧ s.bet (other s.toAct) < n
      ∧ n - s.bet s.toAct ≤ s.stack s.toAct
      ∧ (s.bet (other s.toAct) + s.minRaise ≤ n
         ∨ n - s.bet s.toAct = s.stack s.toAct)

instance (s : State) : Decidable s.MayAct := by
  unfold State.MayAct; infer_instance

/-- `Legal` can be checked by running code, so the engine can use it directly. -/
instance (s : State) (a : Action) : Decidable (Legal s a) := by
  unfold Legal State.MayAct; cases a <;> infer_instance

/-- You can never raise a player who is all-in. They can't answer the raise, so you may
only call or fold. This is also why a short all-in doesn't reopen the betting. -/
theorem no_raise_against_all_in (s : State) (n : Nat)
    (h : s.stack (other s.toAct) = 0) : ¬ Legal s (.raiseTo n) := by
  simp [Legal, h]

/-- A player with no chips left (all-in) can make no move at all: not even fold or check.
So the game must never give them the turn. -/
theorem all_in_player_cannot_act (s : State) (a : Action)
    (h : s.stack s.toAct = 0) : ¬ Legal s a := by
  simp [Legal, State.MayAct, h]

/-- The player who has bet more than the other player can make no move. It is the other
player's turn to call, raise or fold. -/
theorem player_ahead_cannot_act (s : State) (a : Action)
    (h : s.bet (other s.toAct) < s.bet s.toAct) : ¬ Legal s a := by
  simp only [Legal, State.MayAct]
  omega

/-- Every legal raise is either all-in, or at least one big blind more than the other
player's bet. -/
theorem raise_at_least_big_blind (s : State) (n : Nat) (h : Legal s (.raiseTo n)) :
    s.bet (other s.toAct) + bigBlind ≤ n ∨ n - s.bet s.toAct = s.stack s.toAct := by
  simp only [Legal, State.minRaise] at h
  omega

/-! ## Examples -/

/-- Start of a hand: blinds 5 and 10, stacks of 500. Player 0 (small blind) acts first. -/
def exStart : State :=
  { stack := fun p => if p = 0 then 495 else 490
    pot := 0
    bet := fun p => if p = 0 then 5 else 10
    lastRaise := 10
    toAct := 0 }

example : exStart.total = 1000 := by
  simp [State.total, exStart]

example : Legal exStart .call := by decide

example : Legal exStart (.raiseTo 40) := by decide

/-- Checking when there is a bet to call is rejected. -/
example : ¬ Legal exStart .check := by decide

/-- Raising by less than the last raise (and not all-in) is rejected. -/
example : ¬ Legal exStart (.raiseTo 15) := by decide

/-- Betting more chips than you have is rejected. -/
example : ¬ Legal exStart (.raiseTo 5000) := by decide

/-- A short all-in. Player 0 started the hand with 800 chips and player 1 with 200. Each
put 50 in before the flop. On the flop, player 0 bet 100. Player 1 had only 150 left and
went all-in for 150: a raise of 50, less than a full raise of 100. Now player 0 is to act,
with 650 chips left. -/
def exShortAllIn : State :=
  { stack := fun p => if p = 0 then 650 else 0
    pot := 100
    bet := fun p => if p = 0 then 100 else 150
    lastRaise := 100
    toAct := 0 }

example : exShortAllIn.total = 1000 := by
  simp [State.total, exShortAllIn]

/-- Player 0 may still call the extra 50... -/
example : Legal exShortAllIn .call := by decide

/-- ...or fold... -/
example : Legal exShortAllIn .fold := by decide

/-- ...but may not re-raise, not even all-in: the short all-in did not reopen the betting. -/
example : ¬ Legal exShortAllIn (.raiseTo 250) := by decide

example : ¬ Legal exShortAllIn (.raiseTo 750) := by decide

/-- The same raise is legal when the other player still has chips, so the new rule is
what blocks it. -/
example : Legal { exShortAllIn with stack := fun p => if p = 0 then 650 else 50 }
    (.raiseTo 250) := by decide

/-! ## The player to act must be allowed to act

These are the bad states the `MayAct` rule rejects. Each one has 1,000 chips on the table,
so only the turn is wrong. -/

/-- Player 0 is all-in (no chips left) but it is their turn. -/
def exAllInToAct : State :=
  { stack := fun p => if p = 0 then 0 else 400
    pot := 600
    bet := fun _ => 0
    lastRaise := 10
    toAct := 0 }

example : exAllInToAct.total = 1000 := by decide

/-- Player 0 may not check, fold, call or bet: they have no chips, so it is never their turn. -/
example : ¬ Legal exAllInToAct .check := by decide
example : ¬ Legal exAllInToAct .fold := by decide
example : ¬ Legal exAllInToAct .call := by decide
example : ¬ Legal exAllInToAct (.raiseTo 10) := by decide

/-- Player 0 bet 100 and player 1 has not answered, but it is player 0's turn again. -/
def exAheadToAct : State :=
  { stack := fun p => if p = 0 then 400 else 500
    pot := 0
    bet := fun p => if p = 0 then 100 else 0
    lastRaise := 100
    toAct := 0 }

example : exAheadToAct.total = 1000 := by decide

/-- Player 0 may not check: player 1 still owes 100, so it is player 1's turn. -/
example : ¬ Legal exAheadToAct .check := by decide
example : ¬ Legal exAheadToAct (.raiseTo 300) := by decide

/-- The same state with the turn given to player 1: now calling is legal. -/
example : Legal { exAheadToAct with toAct := 1 } .call := by decide

/-- A state where the last raise was recorded as 0. The minimum raise is still the big
blind, so a raise of 1 chip is rejected. -/
example : ¬ Legal { exStart with lastRaise := 0 } (.raiseTo 11) := by decide
example : Legal { exStart with lastRaise := 0 } (.raiseTo 20) := by decide
