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

/-- A move is legal when the rules of `SPEC.md` allow it. -/
def Legal (s : State) : Action → Prop
  -- Check: only when there is nothing to call.
  | .check => s.toCall = 0
  -- Call: only when there is something to call.
  | .call => 0 < s.toCall
  -- Fold: always allowed (even when checking is free, though that is never a good idea).
  | .fold => True
  -- Raise: beat the other bet, afford it, and raise by at least the last raise
  -- (unless going all-in).
  | .raiseTo n =>
      s.bet (other s.toAct) < n
      ∧ n - s.bet s.toAct ≤ s.stack s.toAct
      ∧ (s.bet (other s.toAct) + s.lastRaise ≤ n
         ∨ n - s.bet s.toAct = s.stack s.toAct)

/-! ## Examples -/

/-- Start of a hand: blinds 5 and 10, stacks of 500 each. Player 0 is the button: they post
the small blind and act first. Player 1 posts the big blind. -/
def exStart : State :=
  { stack := fun p => if p = 0 then 495 else 490
    pot := 0
    bet := fun p => if p = 0 then 5 else 10
    lastRaise := 10
    toAct := 0 }

example : exStart.total = 1000 := by
  simp [State.total, exStart]

example : Legal exStart .call := by
  simp [Legal, State.toCall, other, exStart]

example : Legal exStart (.raiseTo 20) := by
  simp [Legal, other, exStart]

/-- Checking when there is a bet to call is rejected. -/
example : ¬ Legal exStart .check := by
  simp [Legal, State.toCall, other, exStart]

/-- Raising by less than the last raise (and not all-in) is rejected. -/
example : ¬ Legal exStart (.raiseTo 15) := by
  simp [Legal, other, exStart]

/-- Betting more chips than you have is rejected. -/
example : ¬ Legal exStart (.raiseTo 5000) := by
  simp [Legal, other, exStart]
