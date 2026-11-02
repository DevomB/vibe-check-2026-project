import Engine.Proofs.ShuffleSpec

/-!
# Spec: how evenly the shuffle's generator spreads its numbers (randomness, part 2)

The shuffle gets its numbers from a seeded generator, SplitMix64 (`nextSeed` and `mixSeed` in
`Engine/Deck.lean`). The generator has a state, a whole number below 2^64. Each step adds a
fixed odd number to the state (wrapping round at 2^64), then scrambles the new state
(`mixSeed`) to give the next number.

What can be proved about a fixed rule like this, and what cannot:
- **Proved: it visits every state once.** The step reaches all 2^64 states before it repeats.
- **Proved: the scrambling loses nothing.** Different states always give different numbers.
- **So, proved: the numbers are perfectly even over a full cycle.** Among the first 2^64
  numbers from any seed, every number below 2^64 comes out exactly once. No number is favoured.
- **Not proved: that the numbers look unpredictable.** Whether one number gives a hint about
  the next is a question for statistical tests, not proofs. Every fixed rule has some pattern;
  SplitMix64 is trusted to have none that matters for dealing cards.

Definitions a reader must trust: `genState`, `genOutput`, and the engine's `nextSeed`,
`mixSeed` and `seedPicks`.
-/

/-- The number the generator adds to its state at each step (an odd number). -/
def genStep : Nat := 0x9E3779B97F4A7C15

/-- The generator's state after `k` steps from `seed`: `seed + k × genStep`, wrapped round at
2^64. -/
def genState (seed k : Nat) : Nat := (seed + k * genStep) % 2 ^ 64

/-- The generator's number number `k` from `seed`, counting from 0: step `k + 1` times, then
scramble. These are the numbers the shuffle uses (`seedPicks_eq`). -/
def genOutput (seed k : Nat) : Nat := mixSeed (genState seed (k + 1))

/-! ## Examples -/

-- The step number is odd. (Adding an odd number is what makes the generator visit every state.)
example : genStep % 2 = 1 := by decide
-- From seed 0, one step gives the step number itself.
example : genState 0 1 = genStep := by decide
-- The state wraps round at 2^64: two steps from 0 is 2 × genStep minus 2^64.
example : genState 0 2 = 2 * genStep - 2 ^ 64 := by decide
