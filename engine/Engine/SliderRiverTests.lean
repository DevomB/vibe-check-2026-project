import Engine.SliderTests

/-!
# Slider bot tests: the river betting set

River spots with no bet to face, where the river betting set decides (`riverBets` in
`Engine/River.lean`). The build fails if the Lean move differs from the TypeScript move.

Import this file from `Engine.lean` once the real `riverBets` has replaced the stub.
-/

#guard goldenRiverOpeningCases.length ≥ 40
#guard moveMismatches goldenRiverOpeningCases == []
#guard reasonMismatches goldenRiverOpeningCases == []
