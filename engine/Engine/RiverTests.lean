import Engine.River
import Engine.RiverGolden
import Engine.HandRankTests

/-!
# River betting set tests: Lean against the TypeScript

`Engine/RiverGolden.lean` holds betting sets chosen by the TypeScript reference
`riverBettingSet`. Here the Lean `riverBettingSet` chooses on the same boards, and the build
fails if any hand gets a different role (value, bluff or check), or if a count differs.
-/

/-- A card's ID: its place in `fullDeck`, from 0 (2c) to 51 (As). -/
def Card.id (c : Card) : Nat :=
  c.rank.val * 4 + match c.suit with
    | .clubs => 0 | .diamonds => 1 | .hearts => 2 | .spades => 3

#guard fullDeck.map Card.id == List.range 52

/-- The role of each candidate hand in the Lean betting set, in the order of
`riverCandidates`: `v` (value), `b` (bluff) or `c` (check). The golden format. -/
def roleLetters (bluffPct : Nat) (board : List Card) : String :=
  let set := riverBettingSet bluffPct board
  -- A table from card-ID pairs to roles, so each hand is looked up once.
  let mark (t : Array Char) (role : Char) (h : RankedHand) :=
    t.set! (h.cards.1.id * 52 + h.cards.2.id) role
  let table := set.value.foldl (mark · 'v') (Array.replicate (52 * 52) 'c')
  let table := set.bluffs.foldl (mark · 'b') table
  String.ofList ((riverCandidates board).map fun (a, b) => table[a.id * 52 + b.id]!)

/-- The golden cases where Lean and the TypeScript disagree: case number, then what differs.
Empty when the two agree. -/
def riverMismatches (cases : List RiverGoldenCase) : List (Nat × String) :=
  cases.zipIdx.filterMap fun (c, i) =>
    let board := cards c.board
    let set := riverBettingSet c.bluffPct board
    if set.value.length != c.valueCount then some (i, s!"value count {set.value.length}")
    else if set.bluffs.length != c.bluffCount then some (i, s!"bluff count {set.bluffs.length}")
    else if roleLetters c.bluffPct board != c.roles then some (i, "roles")
    else none

#guard riverGoldenCases.length ≥ 30
#guard riverMismatches riverGoldenCases == []

-- A wrong golden case is caught: one hand moved from check to bluff.
#guard riverMismatches [{ riverGoldenCases.head! with
  roles := "b" ++ (riverGoldenCases.head!.roles.drop 1).toString }] != []
#guard riverMismatches [{ riverGoldenCases.head! with valueCount := 323 }] != []

/-! ## Unit tests, as in `src/review/riverStrategy.test.ts` -/

/-- No pair and no flush is possible. King-Ten makes the best hand, a king-high straight. -/
def straightBoard : List Card := cards "2c 7d Js Qh 9s"

-- 47 cards left, 47 × 46 / 2 pairs.
#guard (riverCandidates straightBoard).length == 1081

-- The best hand bets for value, at any Bluff setting, with its cards in either order.
#guard riverRole 33 straightBoard (cards "Kh Td") == .value
#guard riverRole 0 straightBoard (cards "Td Kh") == .value
-- The weakest hand bluffs, unless Bluff is 0%.
#guard riverRole 33 straightBoard (cards "4d 3c") == .bluff
#guard riverRole 0 straightBoard (cards "4d 3c") == .check
-- A hand in the middle checks.
#guard riverRole 33 straightBoard (cards "2d 3c") == .check

-- `riverBets` is true for value and bluff hands, false for checks.
#guard riverBets 33 straightBoard (cards "Kh Td")
#guard riverBets 33 straightBoard (cards "4d 3c")
#guard !riverBets 0 straightBoard (cards "4d 3c")
