import Engine.Session

/-!
# Engine: panels that explain a finished hand

These panels only read what the game recorded. They change nothing and use no randomness.

- **River range viewer**, next to each graded river decision. How many hands the bot's
  river betting set has on that board (value hands and bluffs), how many of them use one of
  your cards, and how many of the rest your hand beats, ties and loses to. It uses the
  review's own functions: `riverBettingSet`, `RiverSpot.blocks`, `RiverSpot.botHands` and
  `scoreCounts`.
-/

/-! ## River range viewer -/

/-- The six numbers of the river range viewer. -/
structure RangeSummary where
  /-- Value hands in the bot's river betting set on this board. -/
  value : Nat
  /-- Bluff hands in that set. -/
  bluffs : Nat
  /-- Hands in the set that use one of your cards. The bot cannot hold them. -/
  blocked : Nat
  /-- Of the hands left, how many your hand beats. -/
  beat : Nat
  /-- Of the hands left, how many your hand ties. -/
  tie : Nat
  /-- Of the hands left, how many your hand loses to. -/
  lose : Nat
  deriving Repr, BEq, DecidableEq

/-- The range viewer's numbers for a river spot. The hands left are the review's own
`botHands`, counted with the review's own `scoreCounts`, so `beat`, `tie` and `lose` are
the counts the grade uses. -/
def rangeOf (spot : RiverSpot) : RangeSummary :=
  let set := riverBettingSet spot.bluffPct spot.board
  let c := scoreCounts spot.myScore spot.botHands
  { value := set.value.length, bluffs := set.bluffs.length,
    blocked := ((set.value ++ set.bluffs).filter spot.blocks).length,
    beat := c.win, tie := c.tie, lose := c.loss }

/-! ## For the review -/

/-- The range viewer's numbers for each of the human's moves in hand `n`, in order: `none`
for a move that is not graded. -/
def Session.ranges (s : Session) (n : Nat) : Array (Option RangeSummary) :=
  match s.logs[n - 1]? with
  | some log => log.decisions.map fun d => d.graded.map fun (spot, _) => rangeOf spot
  | none => #[]
