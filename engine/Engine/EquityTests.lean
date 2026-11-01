import Engine.Equity

/-!
# Tests: the equity counts give the same numbers as the TypeScript reference

Each expected value below was computed by `src/ai/slider/counts.ts` on the same cards
(`riverCounts`, `sampledCounts`) or read from `data/preflop.json`. The turn is not checked
here. Its counts are checked against TypeScript by `lake exe equity-bench` (run by hand, not
part of the build) and against poker-calculations by the differential tests in `tests/diff`.
-/

/-! ## How many outcomes are counted -/

-- With two hole cards and five board cards, 45 cards are unseen and the opponent has
-- 45 · 44 / 2 = 990 possible hands.
#guard (unseenCards [card 14 .spades, card 13 .diamonds]
  [card 12 .hearts, card 11 .clubs, card 10 .clubs, card 5 .spades, card 2 .diamonds]).length == 45
#guard (riverOpponentHands [card 14 .spades, card 13 .diamonds]
  [card 12 .hearts, card 11 .clubs, card 10 .clubs, card 5 .spades, card 2 .diamonds]).length == 990

-- On the turn: 46 river cards, each with 990 opponent hands.
#guard (turnOutcomes [card 14 .hearts, card 13 .hearts]
  [card 12 .hearts, card 7 .hearts, card 2 .clubs, card 9 .spades]).length == 45540

/-! ## River: exact -/

-- Ace-king makes the top straight on Q J T 5 2: it loses to nothing, and ties the 9 hands
-- with another ace-king (3 aces left × 3 kings left).
#guard countsFor 0 [card 14 .spades, card 13 .diamonds]
  [card 12 .hearts, card 11 .clubs, card 10 .clubs, card 5 .spades, card 2 .diamonds] == ⟨981, 9, 0⟩

-- Seven-deuce on A K 9 4 3 with no pair: it beats only weaker no-pair hands.
#guard countsFor 0 [card 7 .hearts, card 2 .clubs]
  [card 14 .hearts, card 13 .hearts, card 9 .spades, card 4 .diamonds, card 3 .clubs] == ⟨28, 9, 953⟩

-- Four nines: nothing on this board beats it.
#guard countsFor 0 [card 9 .clubs, card 9 .diamonds]
  [card 9 .hearts, card 9 .spades, card 14 .clubs, card 13 .diamonds, card 2 .hearts] == ⟨990, 0, 0⟩

/-! ## Flop: 1,000 random deals

The sampler, given a seed, matches the TypeScript reference bit for bit (seed 42 here). The bot
starts it from `flopSampleSeed`, worked out from its cards and the board only. -/

#guard sampledCounts [card 11 .clubs, card 11 .diamonds]
  [card 9 .hearts, card 8 .hearts, card 2 .spades] flopSamples 42 == ⟨799, 2, 199⟩

-- The same seed gives the same deals; another seed gives other deals.
#guard sampledCounts [card 11 .clubs, card 11 .diamonds] [card 9 .hearts, card 8 .hearts, card 2 .spades] flopSamples 43 !=
  sampledCounts [card 11 .clubs, card 11 .diamonds] [card 9 .hearts, card 8 .hearts, card 2 .spades] flopSamples 42

-- The bot's flop counts are the sampler started from its own cards and the board.
#guard countsFor 42 [card 11 .clubs, card 11 .diamonds] [card 9 .hearts, card 8 .hearts, card 2 .spades] ==
  sampledCounts [card 11 .clubs, card 11 .diamonds] [card 9 .hearts, card 8 .hearts, card 2 .spades] flopSamples
    (flopSampleSeed [card 11 .clubs, card 11 .diamonds] [card 9 .hearts, card 8 .hearts, card 2 .spades])

-- The game's seed no longer matters: any seed gives the same flop counts.
#guard countsFor 43 [card 11 .clubs, card 11 .diamonds] [card 9 .hearts, card 8 .hearts, card 2 .spades] ==
  countsFor 42 [card 11 .clubs, card 11 .diamonds] [card 9 .hearts, card 8 .hearts, card 2 .spades]

-- Card order does not matter either.
#guard flopSampleSeed [card 11 .clubs, card 11 .diamonds] [card 9 .hearts, card 8 .hearts, card 2 .spades] ==
  flopSampleSeed [card 11 .diamonds, card 11 .clubs] [card 2 .spades, card 9 .hearts, card 8 .hearts]

-- A different board gives a different sampling seed.
#guard flopSampleSeed [card 11 .clubs, card 11 .diamonds] [card 9 .hearts, card 8 .hearts, card 2 .spades] !=
  flopSampleSeed [card 11 .clubs, card 11 .diamonds] [card 9 .hearts, card 8 .hearts, card 3 .spades]

-- The new counts are still a sensible estimate: 1,000 deals, and the pair of jacks wins most.
#guard (countsFor 0 [card 11 .clubs, card 11 .diamonds] [card 9 .hearts, card 8 .hearts, card 2 .spades]).total == 1000
#guard (countsFor 0 [card 11 .clubs, card 11 .diamonds] [card 9 .hearts, card 8 .hearts, card 2 .spades]).win > 700

/-! ## Preflop: the table in `data/preflop.json` -/

-- Pocket aces, in any two suits.
#guard countsFor 0 [card 14 .hearts, card 14 .spades] [] == ⟨42520, 254, 7226⟩
-- Seven-deuce offsuit, either card first.
#guard countsFor 0 [card 7 .hearts, card 2 .clubs] [] == ⟨15772, 2910, 31318⟩
#guard countsFor 0 [card 7 .hearts, card 2 .clubs] [] == countsFor 0 [card 2 .clubs, card 7 .hearts] []
#guard (countsFor 0 [card 7 .hearts, card 2 .clubs] []).total == 50000

/-! ## Inputs the game never gives -/

-- A board of 1, 2 or 6 cards counts as one loss, so the bot never bets on it.
#guard countsFor 0 [card 7 .hearts, card 2 .clubs] [card 3 .clubs] == ⟨0, 0, 1⟩
