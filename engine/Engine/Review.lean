import Engine.Hand
import Engine.River

/-!
# Engine: the game review of river calls and folds (MVP §6)

After a hand, the review grades one kind of decision: the human calls or folds after the bot
opens the river with a bet. Raises are not graded.

What the bot can hold: every hand in its river betting set (`riverBettingSet`, the same set
the bot bets with), minus the hands that use one of the human's cards, each equally likely.
This ignores the earlier betting, so it only approximates what the bot really holds.

The review never sees the bot's real cards: `RiverSpot` has no field for them.

Every amount is an exact fraction. The bridge turns them into decimals, for display only.
Calling is compared with folding in plain chips, not with the bot's Risk weighting.

Ported from the TypeScript reference `src/review/review.ts`. The theorems about it are in
`Engine/Proofs/Review.lean`: T5 (`review_worth`, `review_lost`, `review_best_iff`,
`review_label_monotone`, `review_call_best_iff_equity`) and T8 (`no_hindsight`,
`bot_hand_in_review`).
-/

/-- An exact fraction `num / den`, with `den` above 0. It becomes a decimal only for display. -/
structure Frac where
  num : Int
  den : Nat
  deriving Repr, BEq, DecidableEq

/-- What the human knew when the bot opened the river with a bet. There is no field for
the bot's cards, on purpose. -/
structure RiverSpot where
  /-- The five board cards. -/
  board : List Card
  /-- The human's two cards. -/
  hole : List Card
  /-- All chips in the middle, including the bot's bet. -/
  pot : Nat
  /-- Chips the human must add to match the bot's bet, before any limit from the human's
  stack. -/
  toCall : Nat
  /-- The human's chips not yet in the middle. -/
  stack : Nat
  /-- The bot's Bluff setting, 0 to 60. -/
  bluffPct : Nat
  deriving Repr, DecidableEq

/-- The two answers to a river bet that the review grades. -/
inductive RiverChoice where
  | call | fold
  deriving DecidableEq, Repr

/-- The choice the human did not make. -/
def RiverChoice.other : RiverChoice → RiverChoice
  | .call => .fold
  | .fold => .call

/-- Review labels, best first (MVP §6). -/
inductive ReviewLabel where
  | best | good | inaccuracy | mistake | blunder
  deriving DecidableEq, Repr

/-- The label as the screen shows it. -/
def ReviewLabel.name : ReviewLabel → String
  | .best => "Best" | .good => "Good" | .inaccuracy => "Inaccuracy"
  | .mistake => "Mistake" | .blunder => "Blunder"

/-- Where the label sits in the list, best first: Best is 0, Blunder is 4. -/
def ReviewLabel.rank : ReviewLabel → Nat
  | .best => 0 | .good => 1 | .inaccuracy => 2 | .mistake => 3 | .blunder => 4

/-- The grade of one river call or fold. -/
structure RiverVerdict where
  choice : RiverChoice
  label : ReviewLabel
  /-- The average result of calling, from this decision on, in big blinds. -/
  worthCall : Frac
  /-- Folding is worth 0 from this decision on: earlier chips are already gone. -/
  worthFold : Frac
  /-- Big blinds the choice lost against the better of call and fold. 0 means Best. -/
  lost : Frac
  /-- Share of the bot's possible hands the human beats, ties counting half. -/
  equityHad : Frac
  /-- The share needed for a call to break even: cost / (pot after the call). -/
  equityNeeded : Frac
  /-- How many of the bot's possible hands the human beats, ties and loses to. -/
  counts : Counts
  deriving Repr

/-! ## The spot -/

/-- The spot when the human, to act in `h`, faces the bot's river bet. The player to act is
the human. `toCall` is the whole gap between the bets, even if the human has fewer chips:
`cost` and `prize` below take the part the human cannot match back out. -/
def riverSpotOf (h : Hand) (bluffPct : Nat) : RiverSpot :=
  let s := h.chips
  let me := s.toAct
  { board := h.board, hole := h.hole me, pot := s.pot + s.bet 0 + s.bet 1,
    toCall := s.bet (other me) - s.bet me, stack := s.stack me, bluffPct }

/-- Chips the human pays to call: the bet, or all their chips if they have fewer. -/
def RiverSpot.cost (spot : RiverSpot) : Nat := min spot.toCall spot.stack

/-- Chips the human wins by calling and winning: the pot, less the part of the bot's bet
the human cannot match (it goes back to the bot). -/
def RiverSpot.prize (spot : RiverSpot) : Nat := spot.pot - (spot.toCall - spot.cost)

/-- The human's showdown score: the spec's `bestScore` of their two cards and the board. -/
def RiverSpot.myScore (spot : RiverSpot) : List Nat := bestScore (spot.hole ++ spot.board)

/-- Does this hand use one of the human's cards? Then the bot cannot hold it. -/
def RiverSpot.blocks (spot : RiverSpot) (h : RankedHand) : Bool :=
  spot.hole.contains h.cards.1 || spot.hole.contains h.cards.2

/-- The hands the bot can hold when it opens the river with a bet: its river betting set
(value hands, then bluffs) at its Bluff setting, minus the hands that use one of the human's
cards. -/
def RiverSpot.botHands (spot : RiverSpot) : List RankedHand :=
  let set := riverBettingSet spot.bluffPct spot.board
  (set.value ++ set.bluffs).filter fun h => !spot.blocks h

/-! ## The grade -/

/-- How many of `hands` a hand with score `mine` beats, ties and loses to. -/
def scoreCounts (mine : List Nat) (hands : List RankedHand) : Counts :=
  hands.foldl (fun c h => c.addScores mine h.score) Counts.zero

/-- The label for losing `lost` big blinds against the better of call and fold (MVP §6):
Best = 0, Good under 0.5, Inaccuracy under 2, Mistake under 5, else Blunder. It uses the
exact amount, before any rounding. -/
def labelFor (lost : Frac) : ReviewLabel :=
  let below (a b : Nat) := lost.num * b < a * lost.den   -- lost < a / b
  if lost.num ≤ 0 then .best
  else if below 1 2 then .good
  else if below 2 1 then .inaccuracy
  else if below 5 1 then .mistake
  else .blunder

/-- Grade a call or fold when the bot holds one of `hands`, each equally likely. The human's
showdown score is `mine`. Calling pays `cost` chips to win `prize` chips.

Against one bot hand, in half-chips (so that a split pot is a whole number), calling gains
`2 * prize` on a win, `prize - cost` on a split (half of `prize + cost` comes back, after
paying `cost`) and loses `2 * cost` on a loss. Folding is worth 0. -/
def gradeRiver (hands : List RankedHand) (mine : List Nat) (prize cost : Nat)
    (choice : RiverChoice) : RiverVerdict :=
  let c := scoreCounts mine hands
  let n := max hands.length 1
  let call : Int := 2 * c.win * (prize : Int) + c.tie * ((prize : Int) - cost) - 2 * c.loss * (cost : Int)
  let den := 2 * n * bigBlind
  let chosen : Int := match choice with
    | .call => call
    | .fold => 0
  let lost := max call 0 - chosen
  { choice, label := labelFor ⟨lost, den⟩, worthCall := ⟨call, den⟩, worthFold := ⟨0, den⟩,
    lost := ⟨lost, den⟩, equityHad := ⟨2 * c.win + c.tie, 2 * n⟩,
    equityNeeded := ⟨cost, max (prize + cost) 1⟩, counts := c }

/-- Grade the human's call or fold against the bot's opening river bet (MVP §6). The result
depends only on what the human could see and on the bot's rules, never on the cards the bot
really holds. -/
def reviewRiver (spot : RiverSpot) (choice : RiverChoice) : RiverVerdict :=
  gradeRiver spot.botHands spot.myScore spot.prize spot.cost choice

/-! ## Examples -/

#guard labelFor ⟨0, 1⟩ == .best
#guard labelFor ⟨-3, 1⟩ == .best
#guard labelFor ⟨1, 1000⟩ == .good
#guard labelFor ⟨499, 1000⟩ == .good
#guard labelFor ⟨1, 2⟩ == .inaccuracy
#guard labelFor ⟨1999, 1000⟩ == .inaccuracy
#guard labelFor ⟨2, 1⟩ == .mistake
#guard labelFor ⟨4999, 1000⟩ == .mistake
#guard labelFor ⟨5, 1⟩ == .blunder

/-- A river spot: the human holds a king-high straight (K-T on 2c 7d Js Qh 9s), and faces a
bet of 50 into a pot that was 100 before it. -/
def exRiverSpot : RiverSpot :=
  { board := [card 2 .clubs, card 7 .diamonds, card 11 .spades, card 12 .hearts, card 9 .spades],
    hole := [card 13 .clubs, card 10 .diamonds], pot := 150, toCall := 50, stack := 400,
    bluffPct := 33 }

-- Nothing beats the king-high straight here, so calling is right and folding throws chips away.
#guard (reviewRiver exRiverSpot .call).label == .best
#guard (reviewRiver exRiverSpot .fold).label != .best
#guard (reviewRiver exRiverSpot .call).counts.loss == 0
-- Calling 50 to make a pot of 200 needs a quarter of the time.
#guard (reviewRiver exRiverSpot .call).equityNeeded == ⟨50, 200⟩

/-- The same board, but the human holds 3-2 (a pair of twos) and the bot bets 100 into 100. -/
def exWeakSpot : RiverSpot :=
  { exRiverSpot with hole := [card 3 .hearts, card 2 .diamonds], pot := 200, toCall := 100 }

-- A pair of twos loses to the value hands and beats only some bluffs, so folding is right.
#guard (reviewRiver exWeakSpot .fold).label == .best
#guard (reviewRiver exWeakSpot .call).label != .best

/-- The human has only 30 chips left and faces the bot's bet of 100 into 100. Calling costs
30 and can win only 130: the 70 the human cannot match goes back to the bot. -/
def exShortSpot : RiverSpot := { exRiverSpot with pot := 200, toCall := 100, stack := 30 }

#guard exShortSpot.cost == 30
#guard exShortSpot.prize == 130
#guard (reviewRiver exShortSpot .call).equityNeeded == ⟨30, 160⟩
