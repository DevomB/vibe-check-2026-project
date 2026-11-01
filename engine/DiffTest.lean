import Engine

/-!
# Differential test driver

A small command-line program for `tests/diff/run.ts`, which compares the Lean engine with
the `poker-calculations` library (MVP section 7). It reads one request per line on stdin and
prints one answer per line on stdout. Cards are written as in the JSON messages (`Ah`, `Td`);
groups of cards are separated by `|`.

- `rank H0 | H1 | BOARD`: the spec's `showdown` for two hole hands and a five-card board.
  Answer: the winner (`0`, `1` or `tie`), then the kind of each player's best hand
  (0 = high card ... 8 = straight flush).
- `vs HERO | VILLAIN | BOARD`: every way to finish a board of 3, 4 or 5 cards, each once, and
  the spec's `showdown` for each. Answer: hero's wins, ties and losses.
- `counts SEED | HOLE | BOARD`: the bot's `countsFor`. Answer: wins, ties and losses.

A request it cannot read gets the answer `error`, followed by the request.
-/

/-- A card from two characters, rank then suit: `"Ah"`, `"Td"`. -/
def cardOfString? (s : String) : Option Card :=
  match s.toList with
  | [r, su] => do
    let rank ← (List.finRange 13).find? fun i => "23456789TJQKA".toList[i.val]! == r
    let suit ← match su with
      | 'c' => some Suit.clubs | 'd' => some .diamonds | 'h' => some .hearts | 's' => some .spades
      | _ => none
    pure ⟨rank, suit⟩
  | _ => none

/-- Cards separated by spaces. `none` if any word is not a card. -/
def cardsOfString? (s : String) : Option (List Card) :=
  ((s.splitOn " ").filter (· ≠ "")).mapM cardOfString?

/-- The kind of a best hand: the first number of its score. -/
def handKind (cards : List Card) : Nat := (bestScore cards).headD 0

/-- Hero's wins, ties and losses against one known hand, over every way to finish the board. -/
def versusCounts (hero villain board : List Card) : Nat × Nat × Nat :=
  let rest := fullDeck.filter fun c => !(hero ++ villain ++ board).contains c
  (choose (5 - board.length) rest).foldl (fun (w, t, l) more =>
    match showdown hero villain (board ++ more) with
    | .player0 => (w + 1, t, l)
    | .tie => (w, t + 1, l)
    | .player1 => (w, t, l + 1)) (0, 0, 0)

/-- The answer to one request line. -/
def answer (line : String) : String :=
  let groups := (line.splitOn "|").map fun g => String.ofList (g.toList.dropWhile (· == ' '))
  let err := s!"error {line}"
  match groups with
  | [first, b, c] =>
    match first.splitOn " " |>.filter (· ≠ "") with
    | ["rank", a0, a1] =>
      match cardsOfString? s!"{a0} {a1}", cardsOfString? b, cardsOfString? c with
      | some h0, some h1, some board =>
        let winner := match showdown h0 h1 board with
          | .player0 => "0" | .player1 => "1" | .tie => "tie"
        s!"{winner} {handKind (h0 ++ board)} {handKind (h1 ++ board)}"
      | _, _, _ => err
    | ["vs", a0, a1] =>
      match cardsOfString? s!"{a0} {a1}", cardsOfString? b, cardsOfString? c with
      | some hero, some villain, some board =>
        let (w, t, l) := versusCounts hero villain board
        s!"{w} {t} {l}"
      | _, _, _ => err
    | ["counts", seed] =>
      match seed.toNat?, cardsOfString? b, cardsOfString? c with
      | some seed, some hole, some board =>
        let k := countsFor seed hole board
        s!"{k.win} {k.tie} {k.loss}"
      | _, _, _ => err
    | _ => err
  | _ => err

/-- Answer every line on stdin until it ends. -/
partial def loop (stdin : IO.FS.Stream) (stdout : IO.FS.Stream) : IO Unit := do
  let line ← stdin.getLine
  if line.isEmpty then return
  let line := String.ofList (line.toList.filter fun ch => ch != '\n' && ch != '\r')
  unless line.isEmpty do stdout.putStrLn (answer line)
  loop stdin stdout

def main : IO Unit := do
  loop (← IO.getStdin) (← IO.getStdout)
  (← IO.getStdout).flush

#guard cardOfString? "Ah" == some (card 14 .hearts)
#guard cardOfString? "Td" == some (card 10 .diamonds)
#guard cardOfString? "ah" == none
#guard answer "rank Ah Kd | Qs Qc | 2c 3d 4h 5s 6c" == "tie 4 4"
#guard answer "rank Ah Ad | Qs Qc | 2c 7d 9h Js 3c" == "0 1 1"
#guard answer "vs Ah Ad | Kc Kd | 2c 7d 9h Js 3c" == "1 0 0"
#guard answer "bogus" == "error bogus"
