import Engine.Proofs.KuhnSpec

/-!
# Kuhn poker: the bot's strategy is a Nash equilibrium

The rules are in `KuhnSpec.lean`. Here are the bot's strategies for both seats, and proofs
that together they are a **Nash equilibrium**: neither player can do better on average by
changing only their own strategy.

The game's value is −1/18: in equilibrium, player 1 loses 1/18 of a chip per hand on average.
The theorems say, for **every** strategy the other player might use, with any probabilities:

- `kuhn_bot_as_player1`: with the bot as player 1, player 2 cannot make player 1 average less
  than −1/18.
- `kuhn_bot_as_player2`: with the bot as player 2, player 1 cannot average more than −1/18.
- `kuhn_value`: when both play the bot's strategies, player 1 averages exactly −1/18.
- `kuhn_nash`: so neither player gains by changing only their own strategy.
- `kuhn_bot_unbeatable`: playing one hand in each seat against the bot, no strategy wins
  chips on average.

## The bot's strategies

These are the textbook equilibrium strategies (with player 1 bluffing a jack one time in
three; the theory allows any bluffing rate from 0 to 1/3). Weights are out of 3.

Player 1:
- jack: bet one time in three (a bluff); otherwise check and fold to a bet;
- queen: always check; call a bet two times in three;
- king: always bet.

Player 2:
- jack: after a check, bet one time in three (a bluff); always fold to a bet;
- queen: after a check, always check; call a bet one time in three;
- king: always bet after a check; always call a bet.

## How the proof works

`kuhnPayoff` adds up player 1's winnings over the six deals and every line of play. When one
player's strategy is fixed, it is a sum of the other player's weights times fixed numbers, so
"no strategy does better than −1/18" is a statement about sums of numbers, which `omega`
checks for every choice of weights at once.
-/

/-- The bot's strategy as player 1 (weights out of 3). -/
def p1Equilibrium : P1Strategy
  | .jack => ⟨1, 0, 2⟩
  | .queen => ⟨0, 2, 1⟩
  | .king => ⟨3, 0, 0⟩

/-- The bot's strategy as player 2 (weights out of 3). -/
def p2Equilibrium : P2Strategy
  | .jack => ⟨1, 2, 0, 3⟩
  | .queen => ⟨0, 3, 1, 2⟩
  | .king => ⟨3, 0, 3, 0⟩

/-- Both of the bot's strategies are real strategies: their weights add up to 3. -/
theorem p1Equilibrium_valid : p1Equilibrium.Valid 3 := by
  intro c; cases c <;> rfl

theorem p2Equilibrium_valid : p2Equilibrium.Valid 3 := by
  intro c; cases c <;> exact ⟨rfl, rfl⟩

/-! ## The guarantees -/

/-- **The bot as player 1 cannot be exploited.** For every strategy of player 2 (weights out
of any `d`), player 1 averages at least −1/18 of a chip per hand. In the units of
`kuhnPayoff` (6 × 3 × `d` times the average), that is at least `−d`. -/
theorem kuhn_bot_as_player1 (d : Nat) (s2 : P2Strategy) (h : s2.Valid d) :
    -(d : Int) ≤ kuhnPayoff p1Equilibrium s2 := by
  obtain ⟨j1, j2⟩ := h .jack
  obtain ⟨q1, q2⟩ := h .queen
  obtain ⟨k1, k2⟩ := h .king
  simp only [kuhnPayoff, kuhnDeals, dealValue, p1Equilibrium, showdownFor, KCard.rank,
    List.map_cons, List.map_nil, List.sum_cons, List.sum_nil]
  simp
  omega

/-- **The bot as player 2 cannot be exploited.** For every strategy of player 1 (weights out
of any `d`), player 1 averages at most −1/18 of a chip per hand: at most `−d` in the units of
`kuhnPayoff`. -/
theorem kuhn_bot_as_player2 (d : Nat) (s1 : P1Strategy) (h : s1.Valid d) :
    kuhnPayoff s1 p2Equilibrium ≤ -(d : Int) := by
  have j := h .jack
  have q := h .queen
  have k := h .king
  simp only [kuhnPayoff, kuhnDeals, dealValue, p2Equilibrium, showdownFor, KCard.rank,
    List.map_cons, List.map_nil, List.sum_cons, List.sum_nil]
  simp
  omega

/-- **The value of Kuhn poker is −1/18.** When both play the bot's strategies, player 1
averages exactly −1/18 of a chip per hand (−3 in the units of `kuhnPayoff`, 6 × 3 × 3 times
the average). -/
theorem kuhn_value : kuhnPayoff p1Equilibrium p2Equilibrium = -3 := by decide

/-- **The bot's strategies are a Nash equilibrium.** Comparing averages per hand (each payoff
divided by its units): no strategy of player 1 averages more against the bot's player 2 than
the bot's player 1 does, and no strategy of player 2 holds player 1 to less than the bot's
player 2 does. -/
theorem kuhn_nash :
    (∀ (d : Nat) (s1 : P1Strategy), s1.Valid d →
      kuhnPayoff s1 p2Equilibrium * 3 ≤ kuhnPayoff p1Equilibrium p2Equilibrium * d) ∧
    (∀ (d : Nat) (s2 : P2Strategy), s2.Valid d →
      kuhnPayoff p1Equilibrium p2Equilibrium * d ≤ kuhnPayoff p1Equilibrium s2 * 3) := by
  rw [kuhn_value]
  refine ⟨fun d s1 h => ?_, fun d s2 h => ?_⟩
  · have := kuhn_bot_as_player2 d s1 h; omega
  · have := kuhn_bot_as_player1 d s2 h; omega

/-- **Nobody beats the bot.** Play one hand as player 1 with any strategy `s1`, and one hand
as player 2 with any strategy `s2` (weights out of the same `d`), against the bot's
strategies. Your total winnings, on average, are at most 0. -/
theorem kuhn_bot_unbeatable (d : Nat) (s1 : P1Strategy) (s2 : P2Strategy)
    (h1 : s1.Valid d) (h2 : s2.Valid d) :
    kuhnPayoff s1 p2Equilibrium - kuhnPayoff p1Equilibrium s2 ≤ 0 := by
  have a := kuhn_bot_as_player2 d s1 h1
  have b := kuhn_bot_as_player1 d s2 h2
  omega

/-! ## Checks -/

/-- The conditions can hold: the bot's own strategies are valid, so `kuhn_nash` and
`kuhn_bot_unbeatable` apply to them (and the result is exactly 0: −3 + 3). -/
example : kuhnPayoff p1Equilibrium p2Equilibrium - kuhnPayoff p1Equilibrium p2Equilibrium ≤ 0 :=
  kuhn_bot_unbeatable 3 _ _ p1Equilibrium_valid p2Equilibrium_valid

/-- A real opponent: player 2 who always calls a bet and never bluffs, as weights out of 1. -/
def callingStation : P2Strategy := fun c =>
  if c = .king then ⟨1, 0, 1, 0⟩ else ⟨0, 1, 1, 0⟩

example : callingStation.Valid 1 := by
  intro c; cases c <;> exact ⟨rfl, rfl⟩

/-- The guarantee applies to it: the bot as player 1 averages at least −1/18 against it. -/
example : -(1 : Int) ≤ kuhnPayoff p1Equilibrium callingStation :=
  kuhn_bot_as_player1 1 callingStation (by intro c; cases c <;> exact ⟨rfl, rfl⟩)

-- In fact the bot does better against it than the game value: +2 in units of 6 × 3 × 1
-- (player 1 wins 1/9 of a chip per hand), against −1 (−1/18) in equilibrium.
#guard kuhnPayoff p1Equilibrium callingStation == 2

/-- The statements reject a strategy that can be exploited. "Always bet" as player 1 loses
1/9 of a chip per hand against the bot's player 2 (−2 in units of 6 × 1 × 3), worse than the
game value of −1/18 (−1 in those units). -/
example : kuhnPayoff (fun _ => ⟨1, 0, 0⟩) p2Equilibrium = -2 := by decide

/-- So the comparison in `kuhn_nash` rules "always bet" out as a better reply: it does
strictly worse than the bot's own player 1 strategy. -/

example : kuhnPayoff (fun _ => ⟨1, 0, 0⟩) p2Equilibrium * 3 <
    kuhnPayoff p1Equilibrium p2Equilibrium * 1 := by
  decide

#print axioms kuhn_bot_as_player1
#print axioms kuhn_bot_as_player2
#print axioms kuhn_value
#print axioms kuhn_nash
#print axioms kuhn_bot_unbeatable
