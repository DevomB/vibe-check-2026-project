/-!
# Spec: Kuhn poker

Kuhn poker is the smallest real poker game, small enough to solve exactly. These are its
rules and how a strategy is written down. A reader must check this file says the right thing;
`Engine/Proofs/Kuhn.lean` proves things about it.

## The rules

- There are three cards: jack, queen and king. The king is highest.
- Each player puts 1 chip in the pot (the ante) and gets one card. The third card is not used.
  All six ways to deal two of the three cards are equally likely.
- Player 1 checks or bets 1 chip.
  - If player 1 bets, player 2 calls (puts 1 chip in) or folds.
  - If player 1 checks, player 2 checks or bets 1 chip. If player 2 bets, player 1 calls or folds.
- A fold loses the chips already in the pot. If both players check, or a bet is called, the
  higher card wins the pot.

What player 1 wins or loses, in chips, at the end:
- bet, call: the higher card wins 2 (its ante and its bet come back, plus the other's 2);
- bet, fold: player 1 wins 1 (player 2's ante);
- check, check: the higher card wins 1;
- check, bet, call: the higher card wins 2;
- check, bet, fold: player 1 loses 1 (its ante).

## How a strategy is written

A strategy says, for each card, how often to take each line of play. The numbers are weights
out of a total `d` (so `d = 3` and a weight of 1 means "one time in three"). Any mix of
choices, with any probabilities, can be written this way.

- Player 1, for each card: how often to **bet**, to **check then call** a bet, and to **check
  then fold** to a bet. The three weights add up to `d`.
- Player 2, for each card, two separate choices: after a check, how often to **bet** or
  **check**; after a bet, how often to **call** or **fold**. Each pair adds up to `d`.
-/

/-- The three cards. -/
inductive KCard where
  | jack | queen | king
  deriving DecidableEq, Repr

/-- How strong a card is: the king is highest. -/
def KCard.rank : KCard → Nat
  | .jack => 0 | .queen => 1 | .king => 2

/-- The six equally likely deals: player 1's card, then player 2's card. -/
def kuhnDeals : List (KCard × KCard) :=
  [(.jack, .queen), (.jack, .king), (.queen, .jack), (.queen, .king), (.king, .jack),
   (.king, .queen)]

/-- Player 1's plan for one card, as weights: bet; check then call; check then fold. -/
structure P1Plan where
  bet : Nat
  checkCall : Nat
  checkFold : Nat

/-- Player 2's plan for one card, as weights: after a check, bet or check; after a bet, call
or fold. -/
structure P2Plan where
  bet : Nat
  check : Nat
  call : Nat
  fold : Nat

/-- Player 1's strategy: a plan for each card. -/
abbrev P1Strategy := KCard → P1Plan

/-- Player 2's strategy: a plan for each card. -/
abbrev P2Strategy := KCard → P2Plan

/-- A player 1 strategy whose weights, for each card, add up to `d`. -/
def P1Strategy.Valid (d : Nat) (s : P1Strategy) : Prop :=
  ∀ c, (s c).bet + (s c).checkCall + (s c).checkFold = d

/-- A player 2 strategy whose weights, for each card and each choice, add up to `d`. -/
def P2Strategy.Valid (d : Nat) (s : P2Strategy) : Prop :=
  ∀ c, (s c).bet + (s c).check = d ∧ (s c).call + (s c).fold = d

/-- What player 1 wins at a showdown worth `x` chips: `x` with the higher card, else `-x`. -/
def showdownFor (c1 c2 : KCard) (x : Int) : Int :=
  if c2.rank < c1.rank then x else -x

/-- Player 1's winnings on one deal, added up over every line of play, each weighted by how
often player 1's plan `p` and player 2's plan `q` take it. -/
def dealValue (p : P1Plan) (q : P2Plan) (c1 c2 : KCard) : Int :=
  -- Player 1 bets; player 2 calls (showdown for 2) or folds (player 1 wins 1).
  p.bet * (q.call * showdownFor c1 c2 2 + q.fold * 1)
  -- Player 1 checks; player 2 checks too (showdown for 1).
  + (p.checkCall + p.checkFold) * q.check * showdownFor c1 c2 1
  -- Player 1 checks; player 2 bets; player 1 calls (showdown for 2) or folds (loses 1).
  + q.bet * (p.checkCall * showdownFor c1 c2 2 + p.checkFold * (-1))

/-- Player 1's winnings, added up over the six deals. If player 1's weights add up to `d₁` and
player 2's to `d₂`, this is `6 × d₁ × d₂` times player 1's average winnings per hand, in
chips. (Keeping everything a whole number keeps the arithmetic exact.) -/
def kuhnPayoff (s1 : P1Strategy) (s2 : P2Strategy) : Int :=
  (kuhnDeals.map fun (c1, c2) => dealValue (s1 c1) (s2 c2) c1 c2).sum

/-! ## Examples -/

/-- Player 1 always bets; player 2 always calls. Each player wins 2 with the higher card and
loses 2 with the lower card, so on average nobody wins. -/
example : kuhnPayoff (fun _ => ⟨1, 0, 0⟩) (fun _ => ⟨0, 1, 1, 0⟩) = 0 := by decide

/-- Player 1 always bets; player 2 always folds. Player 1 wins 1 on every deal: 6 in total. -/
example : kuhnPayoff (fun _ => ⟨1, 0, 0⟩) (fun _ => ⟨0, 1, 0, 1⟩) = 6 := by decide
