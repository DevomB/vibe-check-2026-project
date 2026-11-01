import Engine.Review
import Engine.ReviewGolden
import Engine.HandRankTests

/-!
# River review tests: Lean against the TypeScript

`Engine/ReviewGolden.lean` holds reviews computed by the TypeScript reference
`reviewRiverDecision`. Here the Lean `reviewRiver` grades the same spots, and the build fails
if a label, a worth, an equity or a count differs.
-/

/-- The spot a golden case describes. -/
def ReviewGoldenCase.spot (c : ReviewGoldenCase) : RiverSpot :=
  { board := cards c.board, hole := cards c.hole, pot := c.pot, toCall := c.toCall,
    stack := c.stack, bluffPct := c.bluffPct }

/-- The golden cases where Lean and the TypeScript disagree: case number, then what differs.
Empty when the two agree. -/
def reviewMismatches (cases : List ReviewGoldenCase) : List (Nat × String) :=
  cases.zipIdx.filterMap fun (c, i) =>
    let call := reviewRiver c.spot .call
    let fold := reviewRiver c.spot .fold
    if call.counts != c.counts then some (i, "counts")
    else if call.label.name != c.callLabel then some (i, s!"call label {call.label.name}")
    else if fold.label.name != c.foldLabel then some (i, s!"fold label {fold.label.name}")
    else if call.worthCall != c.worthCall then some (i, "worth of calling")
    else if call.equityHad != c.equityHad then some (i, "equity had")
    else if call.equityNeeded != c.equityNeeded then some (i, "equity needed")
    else none

#guard reviewGoldenCases.length ≥ 25
#guard reviewMismatches reviewGoldenCases == []

-- A wrong golden case is caught.
#guard reviewMismatches (reviewGoldenCases.take 1 |>.map fun c => { c with callLabel := "Good" }) != []
#guard reviewMismatches (reviewGoldenCases.take 1 |>.map fun c => { c with counts := ⟨0, 0, 1⟩ }) != []

