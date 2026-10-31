import Engine.Slider
import Engine.SliderGolden
import Engine.HandRankTests

/-!
# Slider bot tests: the Lean bot against the TypeScript bot

`Engine/SliderGolden.lean` holds spots where the TypeScript reference `decideWithCounts`
has decided. Here the Lean `decideWithCounts` decides the same spots from the same betting
`State`, so the test covers both how the bot reads the state (`viewOf`) and how it decides.
The build fails if any move or reason differs.
-/

/-- The betting state of a golden case. -/
def GoldenCase.state (c : GoldenCase) : State :=
  { stack := fun p => if p = 0 then c.stack0 else c.stack1
    pot := c.pot
    bet := fun p => if p = 0 then c.bet0 else c.bet1
    lastRaise := c.lastRaise
    toAct := if c.toAct = 0 then 0 else 1 }

/-- The Lean bot's choice in a golden case. -/
def GoldenCase.leanChoice (c : GoldenCase) : BotChoice :=
  decideWithCounts ⟨c.risk, c.bluffPct⟩ ⟨c.win, c.tie, c.loss⟩ (cards c.hole) (cards c.board)
    c.state

/-- The cases where the Lean move differs from the TypeScript move: case number, TypeScript
move, Lean move. Empty when the two bots agree. -/
def moveMismatches (cases : List GoldenCase) : List (Nat × String × String) :=
  cases.zipIdx.filterMap fun (c, i) =>
    let lean := c.leanChoice.action.text
    if lean == c.expected then none else some (i, c.expected, lean)

/-- The cases where the Lean reason differs from the TypeScript reason, word for word. -/
def reasonMismatches (cases : List GoldenCase) : List (Nat × String × String) :=
  cases.zipIdx.filterMap fun (c, i) =>
    let lean := c.leanChoice.reason
    if lean == c.reason then none else some (i, c.reason, lean)

#guard goldenCases.length ≥ 200
#guard moveMismatches goldenCases == []
#guard reasonMismatches goldenCases == []

-- A wrong expected move is caught: the first case raises to 250, so expecting a call fails.
#guard moveMismatches [{ goldenCases.head! with expected := "call" }] != []
