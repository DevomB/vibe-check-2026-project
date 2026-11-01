import Engine.Proofs.BluffCatcherSpec

/-!
# Spec: the bot's side of the river, and the river equilibrium (game theory, part 2)

Part 1 (`BluffCatcherSpec.lean`) looked at your side: you hold a bluff catcher and face the
bot's bet. Here is the bot's side. The bot has bet; you answer with a call or a fold.

**A bluff** loses every showdown. If the bot checks it, the bot wins nothing. If it bets:
- you fold: the bot wins the pot;
- you call: the bot loses its bet.

**A value hand** wins every showdown. If the bot checks it, the bot wins the pot. If it bets:
- you fold: the bot wins the pot, the same as checking;
- you call: the bot wins the pot and your call, so it gains the bet over checking.

Your answers are a list, one for each hand you might hold, each equally likely. Calling with
some of them and folding with others is how a "call half the time" strategy is written down.

**Equilibrium** means neither player can gain by changing only their own play in the three ways listed:
- you cannot gain by calling more or folding more (calling and folding are worth the same);
- the bot cannot gain by checking a bluff instead of betting it;
- the bot cannot gain by checking a value hand instead of betting it.

Definitions a reader must trust: `bluffGain`, `bluffTotal`, `valueGain`, `valueTotal`,
`callCount`, `RiverEquilibrium`, and part 1's `CatchesBluffs` and `choiceTotal`.
-/

/-- What the bot gains by betting a bluff of `bet` into `pot` instead of checking it, when you
answer `answer`. A fold gives the bot the pot; a call costs it the bet. -/
def bluffGain (pot bet : Nat) : RiverChoice → Int
  | .fold => pot
  | .call => -(bet : Int)

/-- What the bot gains, over all your possible answers, by betting a bluff instead of checking.
Divide by the number of answers for the average. -/
def bluffTotal (answers : List RiverChoice) (pot bet : Nat) : Int :=
  (answers.map (bluffGain pot bet)).sum

/-- What the bot gains by betting a value hand of `bet` instead of checking it, when you answer
`answer`. A fold gives it the pot, which checking also wins; a call adds your call. -/
def valueGain (bet : Nat) : RiverChoice → Int
  | .fold => 0
  | .call => bet

/-- What the bot gains, over all your possible answers, by betting a value hand instead of
checking. -/
def valueTotal (answers : List RiverChoice) (bet : Nat) : Int :=
  (answers.map (valueGain bet)).sum

/-- How many of your answers are calls. -/
def callCount (answers : List RiverChoice) : Nat :=
  answers.count .call

/-- **The river is in equilibrium.** The bot bets `pot` into `pot` (a pot-sized bet) with the
hands `value` and `bluffs`. You hold one of several hands, all bluff catchers against this
range with score `mine`, and `answers` lists your answer with each of them.
1. You cannot gain by always calling or always folding: they are worth the same.
2. The bot cannot gain by checking a bluff: betting it gains nothing over checking.
3. The bot cannot gain by checking a value hand: betting it gains at least as much. -/
def RiverEquilibrium (mine : List Nat) (value bluffs : List RankedHand)
    (answers : List RiverChoice) (pot : Nat) : Prop :=
  choiceTotal (value ++ bluffs) mine (2 * pot) pot .call =
      choiceTotal (value ++ bluffs) mine (2 * pot) pot .fold ∧
    bluffTotal answers pot pot = 0 ∧
    0 ≤ valueTotal answers pot

/-! ## Examples -/

-- Betting a bluff of 100 into 100: you call once and fold once, so the bot wins 100 and loses
-- 100. It breaks even.
example : bluffTotal [.call, .fold] 100 100 = 0 := by decide
-- If you always call, the bluff loses 200 over two answers; if you always fold, it wins 200.
example : bluffTotal [.call, .call] 100 100 = -200 := by decide
example : bluffTotal [.fold, .fold] 100 100 = 200 := by decide
-- A value bet of 100 gains 100 from the one call, and nothing from the fold.
example : valueTotal [.call, .fold] 100 = 100 := by decide
example : callCount [.call, .fold, .call] = 2 := by decide
