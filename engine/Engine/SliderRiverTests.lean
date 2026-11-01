import Engine.SliderTests

/-!
# Slider bot tests: the river betting set

River spots with no bet to face, where the river betting set decides (`riverRole` in
`Engine/River.lean`). The build fails if the Lean move or reason differs from the
TypeScript one.
-/

#guard goldenRiverOpeningCases.length ≥ 40
#guard moveMismatches goldenRiverOpeningCases == []
#guard reasonMismatches goldenRiverOpeningCases == []
