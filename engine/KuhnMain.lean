import Engine.KuhnGame

/-!
# Play Kuhn poker against the proven bot

Run with `lake exe kuhn` from `engine/`. You and the bot take turns being player 1. Each hand
is dealt from a random number and the bot rolls its own random number; the proofs in
`Engine/Proofs/KuhnGame.lean` show that, if those random numbers are fair, the bot can't be
beaten on average.
-/

def cardName : KCard → String
  | .jack => "Jack" | .queen => "Queen" | .king => "King"

def moveName : KMove → String
  | .check => "check" | .bet => "bet" | .call => "call" | .fold => "fold"

/-- Ask the human for one of the allowed moves. -/
partial def askMove (allowed : List KMove) : IO KMove := do
  let stdout ← IO.getStdout
  stdout.putStr s!"  Your move ({", ".intercalate (allowed.map moveName)}): "
  stdout.flush
  let line := (← (← IO.getStdin).getLine).trimAscii.toString.toLower
  if line.isEmpty then
    IO.println ""
    throw (IO.userError "no input")
  match allowed.find? (fun m => (moveName m).startsWith line) with
  | some m => pure m
  | none => IO.println "  That move is not allowed here."; askMove allowed

/-- Play one hand. `humanSeat` is 0 if you are player 1. Returns your winnings in chips. -/
partial def playHand (humanSeat : Nat) : IO Int := do
  let (c1, c2) := kDeal (← IO.rand 0 5)
  let roll ← IO.rand 0 2
  let yourCard := if humanSeat = 0 then c1 else c2
  IO.println s!"\nYou are player {humanSeat + 1}. Your card: {cardName yourCard}."
  let rec loop (moves : List KMove) : IO (List KMove) := do
    match kToAct moves with
    | none => pure moves
    | some who =>
      let m ← if who = humanSeat then askMove (kLegal moves)
        else
          let m := if who = 0 then (botP1Line c1 roll).move moves else botP2Move c2 roll moves
          IO.println s!"  Bot: {moveName m}"
          pure m
      match kStep moves m with
      | .ok moves' => loop moves'
      | .error e => IO.println s!"  ({e})"; loop moves
  let moves ← loop []
  let p1 := kResult c1 c2 moves
  let yours := if humanSeat = 0 then p1 else -p1
  let showdown := !(moves.getLast? == some .fold)
  if showdown then
    IO.println s!"  Showdown: you have {cardName yourCard}, the bot has {cardName (if humanSeat = 0 then c2 else c1)}."
  IO.println s!"  You {if yours ≥ 0 then "win" else "lose"} {yours.natAbs} chip{if yours.natAbs = 1 then "" else "s"}."
  pure yours

def main : IO Unit := do
  IO.println "Kuhn poker: Jack < Queen < King. Each player antes 1; one bet of 1 is allowed."
  IO.println "The bot plays a proven Nash equilibrium. Press Enter on an empty line to stop."
  let total ← IO.mkRef (0 : Int)
  let hands ← IO.mkRef 0
  try
    repeat
      let n ← hands.get
      let won ← playHand (n % 2)
      total.modify (· + won)
      hands.set (n + 1)
      IO.println s!"  Running total: {← total.get} after {n + 1} hand{if n = 0 then "" else "s"}."
  catch _ => pure ()
  IO.println s!"\nFinal: {← total.get} chips over {← hands.get} hands. (In theory you can't win on average.)"
