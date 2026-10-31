import Poker
import Engine.Deck
import Engine.StartingHands

/-!
# Engine: how often the bot's hand wins

The bot counts the opponent's possible outcomes that its hand wins, ties and loses (MVP §5).
It uses whole-number counts, never a decimal win chance.

- Preflop: the fixed table in `Engine/PreflopData.lean`, looked up by starting-hand name.
- Flop: 1,000 random deals from the seed.
- Turn: exact. Every river card, and with it every opponent hand (45,540 outcomes).
- River: exact. Every opponent hand from the 45 unseen cards (990 hands).

Every hand is scored with the spec's `bestScore`, and a result is counted by the same rule as
the spec's `showdown` (`Counts.add_showdown`), so the counts agree with the spec's ranking.

Ported from the TypeScript reference `src/ai/slider/counts.ts`.
-/

/-- How many of the opponent's possible outcomes the bot's hand wins, ties and loses. -/
structure Counts where
  win : Nat
  tie : Nat
  loss : Nat
  deriving Repr, BEq, DecidableEq

/-- All outcomes counted. -/
def Counts.total (c : Counts) : Nat := c.win + c.tie + c.loss

/-- No outcomes counted yet. -/
def Counts.zero : Counts := ⟨0, 0, 0⟩

/-- Count one more outcome. -/
def Counts.add (c : Counts) : Outcome → Counts
  | .player0 => { c with win := c.win + 1 }
  | .tie => { c with tie := c.tie + 1 }
  | .player1 => { c with loss := c.loss + 1 }

/-- Count one more outcome, given the bot's best score `mine` and the opponent's `theirs`.
The bigger score wins; equal scores tie. This is the rule `showdown` uses. -/
def Counts.addScores (c : Counts) (mine theirs : List Nat) : Counts :=
  if mine < theirs then { c with loss := c.loss + 1 }
  else if theirs < mine then { c with win := c.win + 1 }
  else { c with tie := c.tie + 1 }

/-- Counting by scores is counting the spec's `showdown` result, with the bot as player 0.
So the counts below rank hands exactly as the spec does. -/
theorem Counts.add_showdown (c : Counts) (hole opp board : List Card) :
    c.addScores (bestScore (hole ++ board)) (bestScore (opp ++ board)) =
      c.add (showdown hole opp board) := by
  simp only [Counts.addScores, showdown]
  by_cases h1 : bestScore (hole ++ board) < bestScore (opp ++ board) <;>
    by_cases h2 : bestScore (opp ++ board) < bestScore (hole ++ board) <;>
    simp [h1, h2, Counts.add]

/-! ## The cards the bot cannot see -/

/-- The cards in neither the bot's hand nor the board, in deck order (2c, 2d, ..., As). -/
def unseenCards (hole board : List Card) : List Card :=
  fullDeck.filter fun c => !(hole ++ board).contains c

/-- Every pair of different entries of a list, each pair once: the first entry with each
later entry, then the second entry with each later entry, and so on. -/
def pairs {α : Type} : List α → List (α × α)
  | [] => []
  | x :: xs => xs.map (x, ·) ++ pairs xs

#guard pairs [1, 2, 3] == [(1, 2), (1, 3), (2, 3)]

/-! ## River: exact -/

/-- Every hand the opponent can hold on the river: each pair of unseen cards, once. -/
def riverOpponentHands (hole board : List Card) : List (List Card) :=
  (pairs (unseenCards hole board)).map fun (a, b) => [a, b]

/-- River counts: the bot's hand against every hand the opponent can hold (990 hands). -/
def riverCounts (hole board : List Card) : Counts :=
  let mine := bestScore (hole ++ board)
  (riverOpponentHands hole board).foldl
    (fun c opp => c.addScores mine (bestScore (opp ++ board))) Counts.zero

/-! ## Turn: exact

Mode: exact, fixed. Benchmarked on the compiled engine (`lake exe equity-bench`, Oct 31, 2026,
Windows 11, 8 cores): 0.67 to 0.93 s per decision with the 46 river cards counted in parallel,
3.0 to 3.4 s on one core. That fits the bot's think time, so the turn stays exact. The mode is
a constant, never chosen by machine speed (MVP §5). -/

/-- Every outcome on the turn: a river card, and with it a hand the opponent can hold from the
cards still unseen. Each (river card, opponent hand) pair once: 46 × 990 = 45,540 in all. -/
def turnOutcomes (hole board : List Card) : List (Card × List Card) :=
  let unseen := unseenCards hole board
  unseen.flatMap fun r => (pairs (unseen.erase r)).map fun (a, b) => (r, [a, b])

/-- Add two sets of counts. -/
def Counts.plus (a b : Counts) : Counts := ⟨a.win + b.win, a.tie + b.tie, a.loss + b.loss⟩

/-- Counts for one river card `r`: the bot's hand against every hand the opponent can hold
from the other unseen cards. The bot's own score is worked out once. -/
def riverCardCounts (hole board unseen : List Card) (r : Card) : Counts :=
  let full := board ++ [r]
  let mine := bestScore (hole ++ full)
  (pairs (unseen.erase r)).foldl
    (fun c (a, b) => c.addScores mine (bestScore ([a, b] ++ full))) Counts.zero

/-- Turn counts: the counts for every river card, added up. Each river card is counted in its
own task, so the 46 of them run in parallel; `Task.spawn f` then `.get` is just `f ()`, so
this is plain addition as far as proofs are concerned. -/
def turnCounts (hole board : List Card) : Counts :=
  let unseen := unseenCards hole board
  let tasks := unseen.map fun r => Task.spawn fun _ => riverCardCounts hole board unseen r
  tasks.foldl (fun c t => c.plus t.get) Counts.zero

/-! ## Flop: random deals from a seed

The random numbers come from mulberry32, the generator the TypeScript reference uses
(`seededRng` in `src/engine/cards.ts`). Using the same generator, bit for bit, means the
same seed gives the same deals and the same counts in Lean and in TypeScript, and the Lean
code reproduces the preflop table in `data/preflop.json`. -/

/-- One step of mulberry32: the next generator state and a random 32-bit number. -/
def mulberryNext (a : UInt32) : UInt32 × UInt32 :=
  let a := a + 0x6d2b79f5
  let t := (a ^^^ (a >>> 15)) * (a ||| 1)
  let t := t ^^^ (t + (t ^^^ (t >>> 7)) * (t ||| 61))
  (a, t ^^^ (t >>> 14))

/-- A random position from `k` up to `size - 1`. Same as `k + floor(rng() * (size - k))` in
the TypeScript reference, in whole numbers. -/
def randomFrom (u : UInt32) (k size : Nat) : Nat :=
  k + u.toNat * (size - k) / 2 ^ 32

/-- One random deal: shuffle just the first `draws` places of `deck`. Place `k` swaps with a
random place from `k` to the end. Returns the dealt deck and the next generator state. -/
def dealSome (deck : Array Card) (draws : Nat) (st : UInt32) : Array Card × UInt32 :=
  (List.range draws).foldl (fun (deck, st) k =>
    let (st, u) := mulberryNext st
    (deck.swapIfInBounds k (randomFrom u k deck.size), st)) (deck, st)

/-- Counts from `samples` random deals of the opponent's two cards and the rest of the board.
Each deal starts from the unseen cards in deck order. The same seed gives the same counts. -/
def sampledCounts (hole board : List Card) (samples seed : Nat) : Counts :=
  let unseen := (unseenCards hole board).toArray
  let draws := 2 + (5 - board.length)
  let (c, _) := (List.range samples).foldl (fun (c, st) _ =>
    let (deck, st) := dealSome unseen draws st
    let full := board ++ (deck.extract 2 draws).toList
    (c.addScores (bestScore (hole ++ full)) (bestScore ((deck.extract 0 2).toList ++ full)), st))
    (Counts.zero, seed.toUInt32)
  c

/-- Random deals counted on the flop (MVP §5). -/
def flopSamples : Nat := 1000

/-! ## All streets -/

/-- Preflop counts: the table entry for the bot's kind of starting hand. -/
def preflopCounts : List Card → Counts
  | [a, b] => match preflopCountsOf a b with
    | some (w, t, l) => ⟨w, t, l⟩
    | none => ⟨0, 0, 1⟩
  | _ => ⟨0, 0, 1⟩

/-- The counts for the bot's two hole cards and the board (0, 3, 4 or 5 cards): the preflop
table, 1,000 random deals from `seed` on the flop, exact on the turn and river. The same
inputs always give the same counts. Risk and Bluff are not inputs, so the sliders cannot
change the counts.

The game never gives other board sizes; for them the counts are one loss, so the bot never
bets on a hand it cannot count. -/
def countsFor (seed : Nat) (hole board : List Card) : Counts :=
  match board.length with
  | 0 => preflopCounts hole
  | 3 => sampledCounts hole board flopSamples seed
  | 4 => turnCounts hole board
  | 5 => riverCounts hole board
  | _ => ⟨0, 0, 1⟩
