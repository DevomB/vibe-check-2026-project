import Engine.Equity

/-!
# Benchmark and checks for the equity counts, on the compiled engine

Run with `lake exe equity-bench` from `engine/`. It times `countsFor` on each street and checks
the counts against numbers computed by the TypeScript reference (`src/ai/slider/counts.ts`).
It also rebuilds an entry of the preflop table from scratch with the Lean sampler, to show
that `data/preflop.json` is what the same generator gives.

The turn timing and the choice it led to are recorded at `turnCounts` in `Engine/Equity.lean`.
-/

/-- A card from two characters, rank then suit, like `"Ah"`. -/
def parseCard (s : String) : Card :=
  match s.toList with
  | [r, su] =>
    let suit := match su with
      | 'c' => Suit.clubs | 'd' => .diamonds | 'h' => .hearts | _ => .spades
    ⟨⟨"23456789TJQKA".toList.idxOf r % 13, Nat.mod_lt _ (by decide)⟩, suit⟩
  | _ => ⟨0, .clubs⟩

/-- Cards separated by spaces, like `"Ah Kd"`. -/
def cards (s : String) : List Card := (s.splitOn " ").filter (· ≠ "") |>.map parseCard

/-- Time one count and compare it with the expected result. Returns whether it matched. -/
def check (name : String) (expected : Counts) (f : Unit → Counts) : IO Bool := do
  let t0 ← IO.monoMsNow
  let c := f ()
  -- Force the result before stopping the clock.
  let ok := c == expected
  let t1 ← IO.monoMsNow
  IO.println s!"{if ok then "ok  " else "FAIL"} {name}: {repr c} in {t1 - t0} ms"
  unless ok do IO.println s!"     expected {repr expected}"
  return ok

def main : IO UInt32 := do
  let tests : List (String × Counts × (Unit → Counts)) := [
    ("river AsKd | Qh Jc Tc 5s 2d", ⟨981, 9, 0⟩,
      fun _ => countsFor 0 (cards "As Kd") (cards "Qh Jc Tc 5s 2d")),
    ("river 7h2c | Ah Kh 9s 4d 3c", ⟨28, 9, 953⟩,
      fun _ => countsFor 0 (cards "7h 2c") (cards "Ah Kh 9s 4d 3c")),
    ("turn AhKh | Qh 7h 2c 9s", ⟨26755, 315, 18470⟩,
      fun _ => countsFor 0 (cards "Ah Kh") (cards "Qh 7h 2c 9s")),
    ("turn 6c6d | As Ks 7d 2h", ⟨25456, 44, 20040⟩,
      fun _ => countsFor 0 (cards "6c 6d") (cards "As Ks 7d 2h")),
    ("flop JcJd | 9h 8h 2s, seed 42", ⟨799, 2, 199⟩,
      fun _ => countsFor 42 (cards "Jc Jd") (cards "9h 8h 2s")),
    ("flop 5d4d | Ah Kc 3s, seed 7", ⟨292, 55, 653⟩,
      fun _ => countsFor 7 (cards "5d 4d") (cards "Ah Kc 3s")),
    -- Preflop table entries rebuilt from scratch: entry i uses seed 20261031 + i,
    -- 50,000 deals, cards as in `exampleCards` (clubs, then diamonds or clubs).
    ("preflop table AA rebuilt (entry 0)", ⟨42520, 254, 7226⟩,
      fun _ => sampledCounts (cards "Ac Ad") [] 50000 20261031)
  ]
  let mut allOk := true
  for (name, expected, f) in tests do
    allOk := (← check name expected f) && allOk
  IO.println (if allOk then "all equity checks passed" else "SOME EQUITY CHECKS FAILED")
  return if allOk then 0 else 1
