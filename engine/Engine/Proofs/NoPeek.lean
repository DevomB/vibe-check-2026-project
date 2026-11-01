import Engine.Proofs.Session

/-!
# The bot cannot see your cards

The bot's move (`Session.botChoice`) is worked out from: its own two cards, the board, the
chips, its settings and the Risk the player set. The game's seed is passed in too, but the bot
does not use it on any street (`bot_ignores_seed`): before the flop it reads a fixed table, on
the turn and river it counts every outcome exactly, and on the flop its random deals start from
a seed worked out only from its own cards and the board (`flopSampleSeed`). Your cards and the
undealt deck are never among its inputs.

- `bot_ignores_seed`: for any two seeds, the bot makes exactly the same choice. So its move
  cannot depend on how the deck was shuffled, even indirectly.
- `bot_never_sees_your_cards`: two games that give the bot the same settings, Risk, cards, board
  and chips get exactly the same bot move, whatever your cards, the undealt deck, the game's
  seed or the hand number are.
-/

/-- The bot's counts do not use the seed it is given, on any street. -/
theorem countsFor_ignores_seed (seed seed' : Nat) (hole board : List Card) :
    countsFor seed hole board = countsFor seed' hole board := rfl

/-- **The bot ignores the seed.** For any two seeds, the slider bot makes exactly the same
choice (the same move and the same reason), on every street. So its move cannot depend on how
the deck was shuffled: not on the cards left in the deck, and not on your cards. -/
theorem bot_ignores_seed (sl : Sliders) (seed seed' : Nat) (hole board : List Card) (s : State)
    (shown : Option Nat) :
    botDecide sl seed hole board s shown = botDecide sl seed' hole board s shown := by
  simp only [botDecide, countsFor_ignores_seed seed seed' hole board]

/-- **The bot never sees your cards.** Take two game sessions that give the bot the same
things: the same settings and Risk, the same cards for the bot, the same board and the same
chips. Then the bot makes exactly the same choice, whatever your cards are, whatever cards are
left in the deck, and whatever the game's seed and hand number are. -/
theorem bot_never_sees_your_cards (s s' : Session)
    (hsl : s'.sliders = s.sliders) (hrisk : s'.risk = s.risk)
    (hhole : s'.game.hand.hole bot = s.game.hand.hole bot)
    (hboard : s'.game.hand.board = s.game.hand.board)
    (hchips : s'.game.hand.chips = s.game.hand.chips) :
    s'.botChoice = s.botChoice := by
  simp only [Session.botChoice, hsl, hrisk, hhole, hboard, hchips]
  exact bot_ignores_seed _ _ _ _ _ _ _

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
  bot_never_sees_your_cards _ _ rfl rfl rfl rfl rfl

-- Your cards really are different in the two sessions.
#guard peekSessionSwapped.game.hand.hole human != peekSession.game.hand.hole human

/-- A different game seed and hand number, same bot cards, board and chips: same choice. -/
example : ({ peekSession with game := { peekSession.game with seed := 12345, handNo := 9 } } :
    Session).botChoice = peekSession.botChoice :=
  bot_never_sees_your_cards _ _ rfl rfl rfl rfl rfl

/-- On a flop, where the bot deals random samples, two different seeds give the same choice. -/
example : botDecide (Sliders.ofRisk 50) 1 [card 11 .clubs, card 11 .diamonds]
      [card 9 .hearts, card 8 .hearts, card 2 .spades] exStart =
    botDecide (Sliders.ofRisk 50) 2 [card 11 .clubs, card 11 .diamonds]
      [card 9 .hearts, card 8 .hearts, card 2 .spades] exStart :=
  bot_ignores_seed _ _ _ _ _ _ _

-- The statement rejects a bot that samples from the game's seed. The flop sampler started
-- from seeds 42 and 43 gives different counts, so a bot that passed the game's seed to it would
-- make choices that depend on that seed, and `bot_ignores_seed` would fail for it.
#guard sampledCounts [card 11 .clubs, card 11 .diamonds]
    [card 9 .hearts, card 8 .hearts, card 2 .spades] flopSamples 42 !=
  sampledCounts [card 11 .clubs, card 11 .diamonds]
    [card 9 .hearts, card 8 .hearts, card 2 .spades] flopSamples 43

#print axioms bot_ignores_seed
#print axioms bot_never_sees_your_cards
