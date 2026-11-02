import Engine.Proofs.Session

/-!
# The bot cannot see your cards

The bot's move (`Session.botChoice`) is worked out from: its own two cards, the board, the
chips, its settings, the Risk the player set, and the hand's seed. Your cards and the undealt
deck are not among them.

- `bot_never_sees_your_cards`: two games that differ only in your cards, the undealt deck, or
  anything else the bot is not given, get exactly the same bot move.
- `bot_ignores_seed_off_flop`: before the flop, on the turn and on the river, the bot does not
  use the seed either. So there, its move does not depend on how the deck was shuffled at
  all: not on your cards, not even indirectly.

## What is not covered: the flop

On the flop the bot estimates its chances from 1,000 random deals (`sampledCounts`). Those
random numbers start from the hand's seed (`handSeed`, cut to 32 bits), and the same seed
also shuffled the real deck. The bot never runs the deck's shuffle, never gets the deck, and
deals its samples from all unseen cards in a fixed order, using a different random number
method (mulberry32, not the deck's). So it does not read your cards. But its flop samples and
the real deal both come from one seed, so they are not proved independent. A fix, not made
here: give the flop sampling its own seed that the deal does not use.
-/

/-- **The bot never sees your cards.** Take two game sessions that give the bot the same
things: the same settings and Risk, the same game seed and hand number, the same cards for
the bot, the same board and the same chips. Then the bot makes exactly the same choice,
whatever your cards are, whatever cards are left in the deck. -/
theorem bot_never_sees_your_cards (s s' : Session)
    (hsl : s'.sliders = s.sliders) (hrisk : s'.risk = s.risk)
    (hseed : s'.game.seed = s.game.seed) (hno : s'.game.handNo = s.game.handNo)
    (hhole : s'.game.hand.hole bot = s.game.hand.hole bot)
    (hboard : s'.game.hand.board = s.game.hand.board)
    (hchips : s'.game.hand.chips = s.game.hand.chips) :
    s'.botChoice = s.botChoice := by
  simp only [Session.botChoice, hsl, hrisk, hseed, hno, hhole, hboard, hchips]

/-- On a board of 0, 4 or 5 cards (before the flop, the turn, the river), the bot's counts
do not use the seed. -/
theorem countsFor_seed_free (seed seed' : Nat) (hole board : List Card)
    (h3 : board.length ≠ 3) : countsFor seed hole board = countsFor seed' hole board := by
  unfold countsFor
  split
  · rfl
  · exact absurd (by assumption) h3
  all_goals rfl

/-- **Off the flop, the bot's move does not depend on the shuffle at all.** Before the flop,
on the turn and on the river, two sessions that give the bot the same settings, Risk, cards,
board and chips get the same bot choice, even with a different game seed or hand number. So
there the bot's move cannot depend on how the deck was shuffled, and so not on your cards,
even indirectly. -/
theorem bot_ignores_seed_off_flop (s s' : Session)
    (hsl : s'.sliders = s.sliders) (hrisk : s'.risk = s.risk)
    (hhole : s'.game.hand.hole bot = s.game.hand.hole bot)
    (hboard : s'.game.hand.board = s.game.hand.board)
    (hchips : s'.game.hand.chips = s.game.hand.chips)
    (hflop : s.game.hand.board.length ≠ 3) :
    s'.botChoice = s.botChoice := by
  simp only [Session.botChoice, botDecide, hsl, hrisk, hhole, hboard, hchips]
  rw [countsFor_seed_free (handSeed s'.game.seed s'.game.handNo)
    (handSeed s.game.seed s.game.handNo) _ _ hflop]

/-! ## Checks -/

/-- A real game session: a new game from seed 7 at Risk 50. -/
def peekSession : Session :=
  { game := newGame 7, sliders := Sliders.ofRisk 50, risk := 50 }

/-- The same session with your two cards swapped for two others (the bot's cards and the board
stay the same). -/
def peekSessionSwapped : Session :=
  { peekSession with
    game := { peekSession.game with
      hand := { peekSession.game.hand with
        hole := setFor peekSession.game.hand.hole human [card 2 .clubs, card 3 .clubs] } } }

/-- The conditions can hold: the two sessions agree on everything the bot is given, and
differ in your cards. So the theorem applies, and the bot's choice is the same. -/
example : peekSessionSwapped.botChoice = peekSession.botChoice :=
  bot_never_sees_your_cards _ _ rfl rfl rfl rfl rfl rfl rfl

-- Your cards really are different in the two sessions.
#guard peekSessionSwapped.game.hand.hole human != peekSession.game.hand.hole human

/-- Before the flop the seed does not matter either: a different game seed, same bot cards,
board and chips, same choice. -/
example : ({ peekSession with game := { peekSession.game with seed := 12345 } } : Session).botChoice
    = peekSession.botChoice :=
  bot_ignores_seed_off_flop _ _ rfl rfl rfl rfl rfl (by decide)

/-- The statement rejects a bot that reads your cards. A "peeking" bot that decided from
your cards instead of its own would, in these two sessions, be given different cards, so the
theorem's condition on the bot's cards would fail for it. -/
example : peekSessionSwapped.game.hand.hole human ≠ peekSession.game.hand.hole human := by
  decide

#print axioms bot_never_sees_your_cards
#print axioms bot_ignores_seed_off_flop
