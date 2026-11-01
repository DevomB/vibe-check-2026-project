import Engine.Review
import Engine.HandRankTests

/-!
# Benchmark for the river betting set and the river review, on the compiled engine

Run with `lake exe river-bench` from `engine/`. It times ranking the 1,081 candidate hands
on a board, building the betting set, deciding one hand, and grading one review, all with
the compiled code (not the interpreter the `#guard` tests use). MVP section 5 sets no time
limit for the river set; this shows how long each step takes.

The numbers measured are recorded at `rankRiverHands` in `Engine/River.lean`.
-/

/-- Run `act`, print `name`, its result as text and the milliseconds it took. -/
def timed {α : Type} (name : String) (act : Unit → α) (text : α → String) : IO Unit := do
  let t0 ← IO.monoMsNow
  let r := act ()
  let s := text r
  let t1 ← IO.monoMsNow
  IO.println s!"{name}: {s} in {t1 - t0} ms"

def boards : List (String × String) :=
  [("royal flush board", "Ah Kh Qh Jh 2c"), ("paired board", "9s 9d 4c Qh 2d"),
   ("low rainbow board", "2c 5d 7h 8s Jc"), ("four-flush board", "3d 8d Td Kd 6c")]

def main : IO UInt32 := do
  for (name, text) in boards do
    let board := cards text
    timed s!"rankRiverHands, {name}" (fun _ => rankRiverHands board)
      (fun l => s!"{l.length} hands, best {match l with | h :: _ => repr h.score | [] => "none"}")
    timed s!"riverBettingSet 60, {name}" (fun _ => riverBettingSet 60 board)
      (fun s => s!"{s.value.length} value, {s.bluffs.length} bluffs")
  let spot : RiverSpot :=
    { board := cards "Ah Kh Qh Jh 2c", hole := cards "9c 9d"
      pot := 100, toCall := 50, stack := 400, bluffPct := 60 }
  timed "riverRole" (fun _ => riverRole 60 spot.board spot.hole) (fun r => s!"{repr r}")
  timed "reviewRiver" (fun _ => reviewRiver spot .call) (fun v => v.label.name)
  return 0
