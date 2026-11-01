import Poker
import Engine.Equity

/-!
# Engine: the bot's river betting set (MVP §5)

When the bot faces no bet on the river, it bets with a fixed set of hands chosen from the
board alone: the strongest 30% for value, plus some of the weakest hands as bluffs, as many
as the Bluff slider asks for. The game review uses this same set as the list of hands the bot
can hold when it bets.

Ported from the TypeScript reference `src/review/riverStrategy.ts`. `Engine/RiverTests.lean`
checks that the two choose the same hands.

Every function here expects a river board (five different cards) and a Bluff setting from
0 to 60, and does not check them. A new game refuses a Bluff above 60 (`Session.start` in
`Engine/Session.lean`), and the board is always dealt from one deck. The TypeScript checks
inside each function instead.
-/

/-- Share of the candidate hands the bot bets for value, in percent. -/
def valuePct : Nat := 30

/-- What the bot does with its hand on the river when it faces no bet. -/
inductive RiverRole where
  /-- Bet: the hand is among the strongest on this board. -/
  | value
  /-- Bet: the hand is one of the weakest, picked as a bluff. -/
  | bluff
  /-- Check: the hand is not in the betting set. -/
  | check
  deriving DecidableEq, Repr

/-- A hand the bot could hold, with its showdown score on this board. -/
structure RankedHand where
  /-- The two hole cards, the one with the lower card ID first (deck order, `fullDeck`). -/
  cards : Card × Card
  /-- The spec's `bestScore` of the two cards with the board. Higher wins; equal scores split
  the pot. -/
  score : List Nat
  deriving Repr, BEq

/-- The hands the bot bets with on the river when it faces no bet. -/
structure RiverBettingSet where
  /-- The strongest hands, strongest first. -/
  value : List RankedHand
  /-- The weakest hands not used for value, strongest first. -/
  bluffs : List RankedHand
  deriving Repr

/-- Every two-card hand the bot could hold on this board: each pair of cards not on the board,
once, lower card ID first. 1,081 hands on a river. -/
def riverCandidates (board : List Card) : List (Card × Card) :=
  pairs (unseenCards [] board)

/-- The candidate hands from strongest to weakest showdown score. Hands with equal scores keep
the order of `riverCandidates`: by the lower card's ID, then the higher card's ID. This order
only chooses the betting set; equal scores still split the pot at showdown.

Speed: `lake exe river-bench` (`RiverBench.lean`) ranks the 1,081 hands of a five-card
board in about 20 ms with the compiled engine (measured Oct 31, 2026 on WSL), so there is
no need for a precomputed score key. -/
def rankRiverHands (board : List Card) : List RankedHand :=
  let hands := (riverCandidates board).map fun (a, b) =>
    ({ cards := (a, b), score := bestScore ([a, b] ++ board) } : RankedHand)
  -- `mergeSort` is stable, so equal scores stay in candidate order.
  hands.mergeSort fun x y => !decide (x.score < y.score)

/-- Number of value hands among `candidates` hands: 30%, rounded down. -/
def valueCount (candidates : Nat) : Nat := valuePct * candidates / 100

/-- Number of bluff hands to go with `values` value hands at Bluff `bluffPct`:
values × b / (100 − b), rounded to the nearest whole hand, halves up.
With that many, bluffs are b% of the betting set, to the nearest whole hand. -/
def bluffCount (values bluffPct : Nat) : Nat :=
  (2 * values * bluffPct + (100 - bluffPct)) / (2 * (100 - bluffPct))

/-- The hands the bot bets with on the river when it faces no bet: the first `valueCount`
hands of `rankRiverHands` for value, the last `bluffCount` hands as bluffs. It depends only
on the board and the Bluff setting, never on the human's cards. -/
def riverBettingSet (bluffPct : Nat) (board : List Card) : RiverBettingSet :=
  let ranked := rankRiverHands board
  let values := valueCount ranked.length
  let bluffs := bluffCount values bluffPct
  { value := ranked.take values, bluffs := ranked.drop (ranked.length - bluffs) }

/-- Is this ranked hand the bot's `hole` (two cards, in either order)? -/
def RankedHand.isHole (h : RankedHand) (hole : List Card) : Bool :=
  hole.contains h.cards.1 && hole.contains h.cards.2

/-- Whether the bot bets `hole` for value, bets it as a bluff, or checks, on the river with
no bet to face. `hole` must be two different cards that are not on the board. -/
def riverRole (bluffPct : Nat) (board hole : List Card) : RiverRole :=
  let set := riverBettingSet bluffPct board
  if set.value.any (·.isHole hole) then .value
  else if set.bluffs.any (·.isHole hole) then .bluff
  else .check

/-- Is `hole` in the river betting set at this Bluff setting? True exactly when `riverRole` is
value or bluff. The slider bot uses `riverRole` itself; this yes/no form is for the review. -/
def riverBets (bluffPct : Nat) (board hole : List Card) : Bool :=
  riverRole bluffPct board hole != .check

/-! ## Examples -/

-- 30% of the 1,081 river candidates, rounded down.
#guard valueCount 1081 == 324
-- Bluff 0% means no bluffs; Bluff 50% means as many bluffs as value hands.
#guard bluffCount 324 0 == 0
#guard bluffCount 324 50 == 324
-- Bluff 33%: 324 × 33 / 67 = 159.58..., which rounds to 160.
#guard bluffCount 324 33 == 160
-- Bluff 60%: 324 × 60 / 40 = 486 exactly.
#guard bluffCount 324 60 == 486
