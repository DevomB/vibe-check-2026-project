import Engine.Hand
import Engine.Equity

/-!
# Placeholder for Aarav's river review (`Engine/Review.lean`)

The game loop (`Engine/Session.lean`) records river spots with `riverSpotOf` and grades
them with `reviewRiver`. Aarav's `Engine/Review.lean` will replace this file. Until then,
this placeholder assumes the bot could hold **any** hand that the human's cards do not
block. MVP §6 says to use only the hands in the bot's river betting set.

The bot also does not open the river with a bet yet (`riverBetsStub` in
`Engine/Slider.lean` is false), so nothing is graded until both files land.

When `Engine/Review.lean` lands: delete this file and import that one in `Session.lean`.
-/

/-- An exact fraction `num / den`, with `den` above 0. It becomes a decimal only for display. -/
structure Frac where
  num : Int
  den : Nat
  deriving Repr, BEq

/-- What the human knew when the bot opened the river with a bet. There is no field for
the bot's cards, on purpose. -/
structure RiverSpot where
  board : List Card
  /-- The human's two cards. -/
  hole : List Card
  /-- All chips in the middle, including the bot's bet. -/
  pot : Nat
  /-- Chips the human must add to call, before any limit from the human's stack. -/
  toCall : Nat
  /-- The human's chips not yet in the middle. -/
  stack : Nat
  /-- The bot's Bluff setting, 0 to 60. -/
  bluffPct : Nat
  deriving Repr

/-- The two answers to a river bet that the review grades. -/
inductive RiverChoice where
  | call | fold
  deriving DecidableEq, Repr

/-- Review labels, best first (MVP §6). -/
inductive ReviewLabel where
  | best | good | inaccuracy | mistake | blunder
  deriving DecidableEq, Repr

/-- The label as the screen shows it. -/
def ReviewLabel.name : ReviewLabel → String
  | .best => "Best" | .good => "Good" | .inaccuracy => "Inaccuracy"
  | .mistake => "Mistake" | .blunder => "Blunder"

/-- The grade of one river call or fold. -/
structure RiverVerdict where
  choice : RiverChoice
  label : ReviewLabel
  /-- The average result of calling, from this decision on, in big blinds. -/
  worthCall : Frac
  /-- Folding is worth 0 from this decision on: earlier chips are already gone. -/
  worthFold : Frac
  /-- Share of the bot's possible hands the human beats, ties counting half. -/
  equityHad : Frac
  /-- The share needed for a call to break even: cost / (pot after the call). -/
  equityNeeded : Frac
  deriving Repr

/-- The spot when the human, to act in `h`, faces the bot's river bet. -/
def riverSpotOf (h : Hand) (bluffPct : Nat) : RiverSpot :=
  let s := h.chips
  { board := h.board, hole := h.hole s.toAct, pot := s.pot + s.bet 0 + s.bet 1,
    toCall := s.toCall, stack := s.stack s.toAct, bluffPct }

/-- The label for losing `lost` big blinds against the better of call and fold (MVP §6):
Best = 0, Good under 0.5, Inaccuracy under 2, Mistake under 5, else Blunder. -/
def labelFor (lost : Frac) : ReviewLabel :=
  let below (a b : Nat) := lost.num * b < a * lost.den   -- lost < a / b
  if lost.num ≤ 0 then .best
  else if below 1 2 then .good
  else if below 2 1 then .inaccuracy
  else if below 5 1 then .mistake
  else .blunder

/-- PLACEHOLDER: grade a river call or fold, with every unblocked bot hand equally likely. -/
def reviewRiver (spot : RiverSpot) (choice : RiverChoice) : RiverVerdict :=
  let c := riverCounts spot.hole spot.board
  let n := max c.total 1
  -- Calling costs at most the human's stack; any bet they cannot match goes back to the bot.
  let cost := min spot.toCall spot.stack
  let final := spot.pot - (spot.toCall - cost) + cost
  -- Calling, against folding: win `final - cost`, tie `final / 2 - cost`, lose `cost`.
  -- Over 2n halves: (2 wins + ties) * final - 2n * cost, then in big blinds.
  let callNum : Int := ((2 * c.win + c.tie) * final : Nat) - ((2 * n * cost : Nat) : Int)
  let den := 2 * n * bigBlind
  let lost : Int := match choice with
    | .call => if callNum < 0 then -callNum else 0
    | .fold => if 0 < callNum then callNum else 0
  { choice, label := labelFor ⟨lost, den⟩, worthCall := ⟨callNum, den⟩, worthFold := ⟨0, 1⟩,
    equityHad := ⟨2 * c.win + c.tie, 2 * n⟩, equityNeeded := ⟨cost, max final 1⟩ }

#guard labelFor ⟨0, 1⟩ == .best
#guard labelFor ⟨1, 1000⟩ == .good
#guard labelFor ⟨1, 2⟩ == .inaccuracy
#guard labelFor ⟨2, 1⟩ == .mistake
#guard labelFor ⟨4999, 1000⟩ == .mistake
#guard labelFor ⟨5, 1⟩ == .blunder

/-- A river spot: the human holds a king-high straight (K-T on 2c 7d Js Qh 9s), and faces a
bet of 50 into a pot that was 100 before it. -/
def exRiverSpot : RiverSpot :=
  { board := [card 2 .clubs, card 7 .diamonds, card 11 .spades, card 12 .hearts, card 9 .spades],
    hole := [card 13 .clubs, card 10 .diamonds], pot := 150, toCall := 50, stack := 400,
    bluffPct := 33 }

-- With the best straight, calling is right and folding throws chips away.
#guard (reviewRiver exRiverSpot .call).label == .best
#guard (reviewRiver exRiverSpot .fold).label != .best
-- Calling 50 to make a pot of 200 needs a quarter of the time.
#guard (reviewRiver exRiverSpot .call).equityNeeded == ⟨50, 200⟩
