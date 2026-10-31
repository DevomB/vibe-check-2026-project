import Poker
import Engine.Deck

/-!
# Engine: how often the bot's hand wins

The bot counts the opponent's possible outcomes that its hand wins, ties and loses (MVP §5).
It uses whole-number counts, never a decimal win chance.

STUB (step 0): `countsFor` returns one win and one loss for every spot, so the game loop can
be wired up now. The real counts (preflop table, flop samples, exact turn and river) replace it.
-/

/-- How many of the opponent's possible outcomes the bot's hand wins, ties and loses. -/
structure Counts where
  win : Nat
  tie : Nat
  loss : Nat
  deriving Repr, BEq, DecidableEq

/-- All outcomes counted. -/
def Counts.total (c : Counts) : Nat := c.win + c.tie + c.loss

/-- The counts for the bot's two hole cards and the board (0, 3, 4 or 5 cards). The same
`seed` always gives the same counts. Risk is not an input, so the sliders cannot change them.

STUB: always one win and one loss (a 50% win chance). -/
def countsFor (_seed : Nat) (_hole _board : List Card) : Counts := ⟨1, 0, 1⟩

#guard countsFor 7 [] [] == ⟨1, 0, 1⟩
