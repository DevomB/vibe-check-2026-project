import Engine.Review
import Engine.Equity

/-!
# The any-hand grade: a call or fold that answers a bet, on any street

`reviewRiver` grades one spot: the human answers the bot's opening river bet, against the
hands the bot bets there. Every other call or fold that answers a bet is graded here,
against every hand the bot could hold, each equally likely. It uses the same arithmetic and
the same labels (`labelFor`). The counts come from `countsFor`: the preflop table, a sampled
flop at a fixed seed, and exact turn and river counts. A call is valued as if no more chips
went in after it.

No theorem covers this grade. It is tested, not proved.
-/

/-- What the human knew when facing a bet, on any street. There is no field for the bot's
cards, on purpose. -/
structure FacingSpot where
  /-- The board so far: 0, 3, 4 or 5 cards. -/
  board : List Card
  /-- The human's two cards. -/
  hole : List Card
  /-- All chips in the middle, including the bet to answer. -/
  pot : Nat
  /-- Chips the human must add to match the bet, before any limit from the human's stack. -/
  toCall : Nat
  /-- The human's chips not yet in the middle. -/
  stack : Nat
  deriving Repr, DecidableEq

/-- The spot when the human, to act in `h`, faces a bet. -/
def facingSpotOf (h : Hand) : FacingSpot :=
  let s := h.chips
  let me := s.toAct
  { board := h.board, hole := h.hole me, pot := s.pot + s.bet 0 + s.bet 1,
    toCall := s.bet (other me) - s.bet me, stack := s.stack me }

/-- What a call costs: the bet to match, or the human's whole stack if that is less. -/
def FacingSpot.cost (spot : FacingSpot) : Nat := min spot.toCall spot.stack

/-- What a call can win: the pot, less the part of the bet the human cannot match. -/
def FacingSpot.prize (spot : FacingSpot) : Nat := spot.pot - (spot.toCall - spot.cost)

/-- The seed for the sampled flop counts. It is fixed, so the grade depends only on what
the human could see, never on the deal. -/
def anyHandSeed : Nat := 1

/-- Grade a call or fold from win, tie and loss counts, each counted outcome equally likely.
This is `gradeRiver`'s arithmetic, in half-chips, with the counts given. -/
def gradeCounts (c : Counts) (prize cost : Nat) (choice : RiverChoice) : RiverVerdict :=
  let n := max c.total 1
  let call : Int := 2 * c.win * (prize : Int) + c.tie * ((prize : Int) - cost) - 2 * c.loss * (cost : Int)
  let den := 2 * n * bigBlind
  let chosen : Int := match choice with
    | .call => call
    | .fold => 0
  let lost := max call 0 - chosen
  { choice, label := labelFor ⟨lost, den⟩, worthCall := ⟨call, den⟩, worthFold := ⟨0, den⟩,
    lost := ⟨lost, den⟩, equityHad := ⟨2 * c.win + c.tie, 2 * n⟩,
    equityNeeded := ⟨cost, max (prize + cost) 1⟩, counts := c }

/-- Grade the human's call or fold that answers a bet, against any hand the bot could hold.
It depends only on what the human could see. -/
def reviewAnyHand (spot : FacingSpot) (choice : RiverChoice) : RiverVerdict :=
  gradeCounts (countsFor anyHandSeed spot.hole spot.board) spot.prize spot.cost choice

/-! ## Examples -/

-- Given the river grade's own counts, the arithmetic matches `reviewRiver` exactly.
#guard (gradeCounts (scoreCounts exRiverSpot.myScore exRiverSpot.botHands) exRiverSpot.prize
  exRiverSpot.cost .call).worthCall == (reviewRiver exRiverSpot .call).worthCall
#guard (gradeCounts (scoreCounts exWeakSpot.myScore exWeakSpot.botHands) exWeakSpot.prize
  exWeakSpot.cost .fold).lost == (reviewRiver exWeakSpot .fold).lost

/-- Preflop, two aces facing the big blind: 5 more to call into 15. -/
def exAcesSpot : FacingSpot :=
  { board := [], hole := [card 14 .spades, card 14 .hearts], pot := 15, toCall := 5, stack := 495 }

-- Calling with aces is right; folding them throws chips away.
#guard (reviewAnyHand exAcesSpot .call).label == .best
#guard (reviewAnyHand exAcesSpot .fold).label != .best
#guard (reviewAnyHand exAcesSpot .call).equityNeeded == ⟨5, 20⟩

/-- On the river, seven-two with no pair on Ah Kd Qs 9c 4h faces a bet of 100 into 100. (A
river example: exact turn counts are slow in the interpreter that runs `#guard`.) -/
def exSevenHighSpot : FacingSpot :=
  { board := [card 14 .hearts, card 13 .diamonds, card 12 .spades, card 9 .clubs, card 4 .hearts],
    hole := [card 7 .clubs, card 2 .diamonds], pot := 200, toCall := 100, stack := 300 }

-- Seven-high loses to almost every hand, so folding is right.
#guard (reviewAnyHand exSevenHighSpot .fold).label == .best
#guard (reviewAnyHand exSevenHighSpot .call).label != .best
