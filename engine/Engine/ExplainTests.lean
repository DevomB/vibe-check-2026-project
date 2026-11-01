import Engine.Explain
import Engine.SessionTests

/-!
# Tests: the river range viewer

`#guard` runs in Lean's interpreter while building, where the bot's turn decisions are slow,
so the games here end before the turn. Whole hands through the compiled program are in
`src/app/api/game/insights.test.ts`.
-/

open Lean SessionTests

namespace ExplainTests

/-! ## River range viewer -/

/-- The range viewer's hands left (value plus bluffs, less the blocked ones) are the hands
the review counts, and its beat, tie and lose numbers are the review's counts. -/
def rangeMatchesReview (spot : RiverSpot) : Bool :=
  let r := rangeOf spot
  let c := (reviewRiver spot .call).counts
  r.blocked ≤ r.value + r.bluffs && r.value + r.bluffs - r.blocked == c.total
    && r.beat == c.win && r.tie == c.tie && r.lose == c.loss

#guard rangeMatchesReview exRiverSpot
#guard rangeMatchesReview exWeakSpot
#guard rangeMatchesReview exShortSpot
#guard rangeMatchesReview { exWeakSpot with bluffPct := 0 }
#guard rangeMatchesReview { exWeakSpot with bluffPct := 60 }

-- The king-high straight on 2c 7d Js Qh 9s, Bluff 33%: of the 1,081 hands the bot could
-- hold, it bets 324 for value (30%) and 160 as bluffs. The human's king and ten are in 26 of
-- them. Nothing left beats the straight; 9 tie it (other king-tens).
#guard rangeOf exRiverSpot == ⟨324, 160, 26, 449, 9, 0⟩
-- A pair of twos on the same board loses to every value hand it does not block, and beats
-- only bluffs.
#guard rangeOf exWeakSpot == ⟨324, 160, 36, 144, 0, 304⟩
-- At Bluff 0% there are no bluffs to beat. At Bluff 60% there are 486 (60% of the set).
#guard rangeOf { exWeakSpot with bluffPct := 0 } == ⟨324, 0, 20, 0, 0, 304⟩
#guard rangeOf { exWeakSpot with bluffPct := 60 } == ⟨324, 486, 72, 388, 38, 312⟩

/-! ## The review JSON -/

/-- The JSON of move `i` in the review of hand `n`, or `null`. -/
def reviewLine (s : Session) (n i : Nat) : Json :=
  match s.review n with
  | .ok lines => match (field (reviewJson s n lines) "decisions") with
    | .arr ds => ds[i]?.getD Json.null
    | _ => Json.null
  | .error _ => Json.null

/-- Does this JSON object have key `k` at all? -/
def hasKey (j : Json) (k : String) : Bool := (j.getObjVal? k).toOption.isSome

-- A graded call (the river spot set by hand, as in `SessionTests`) carries the range viewer's
-- numbers, the same ones `rangeOf` gives.
#guard match sessionAfter [start42] with
  | some s =>
    match ({ s with riverSpot := some exRiverSpot }.humanAct .call) with
    | .ok s' =>
      let d := reviewLine s' 1 0
      field d "label" != Json.null
        && field d "range" == Json.mkObj [("value", 324), ("bluffs", 160), ("blocked", 26),
          ("beat", 449), ("tie", 9), ("lose", 0)]
    | .error _ => false
  | none => false

-- An ungraded move has no `range` key at all.
#guard match sessionAfter (foldThenNext.take 2) with
  | some s => reviewLine s 1 0 != Json.null && !hasKey (reviewLine s 1 0) "range"
  | none => false

end ExplainTests
