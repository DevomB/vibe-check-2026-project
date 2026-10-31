import Poker

/-!
# Engine: shuffling and printing cards

A seeded shuffle, so any game can be replayed from its seed.
-/

/-- The next state of a seeded random generator (SplitMix64). It is predictable on purpose:
the same seed always gives the same game. -/
def nextSeed (s : Nat) : Nat :=
  (s + 0x9E3779B97F4A7C15) % 2 ^ 64

/-- Turn a generator state into a random-looking number, so that nearby seeds give
unrelated decks (the SplitMix64 mixing step). -/
def mixSeed (s : Nat) : Nat :=
  let z := ((s ^^^ (s >>> 30)) * 0xBF58476D1CE4E5B9) % 2 ^ 64
  let z := ((z ^^^ (z >>> 27)) * 0x94D049BB133111EB) % 2 ^ 64
  z ^^^ (z >>> 31)

/-- Shuffle by picking cards one at a time. Each pick takes one card out of the cards that
are left, at a position chosen by the generator, and puts it next in the new deck.
`fuel` is how many picks to make; `shuffle` gives it the length of the list. -/
def shuffleAux {α : Type} : Nat → Nat → List α → List α
  | 0, _, l => l
  | _, _, [] => []
  | fuel + 1, s, x :: xs =>
    let s' := nextSeed s
    let i := mixSeed s' % (xs.length + 1)
    (x :: xs)[i]'(Nat.mod_lt _ (Nat.succ_pos _)) :: shuffleAux fuel s' ((x :: xs).eraseIdx i)

/-- Shuffle a list from a seed. -/
-- ponytail: list removal is O(n²), fine for 52 cards; use array Fisher–Yates for larger decks.
def shuffle {α : Type} (seed : Nat) (l : List α) : List α :=
  shuffleAux l.length seed l

/-- A card as two characters, rank then suit: `"Ah"` is the ace of hearts, `"Tc"` the ten
of clubs. This is the format the JSON messages use. -/
def Card.toString (c : Card) : String :=
  let rank := "23456789TJQKA".toList[c.rank.val]!
  let suit := match c.suit with
    | .clubs => 'c' | .diamonds => 'd' | .hearts => 'h' | .spades => 's'
  String.ofList [rank, suit]

instance : ToString Card := ⟨Card.toString⟩

#guard (card 14 .hearts).toString == "Ah"
#guard (card 10 .clubs).toString == "Tc"
#guard (card 2 .spades).toString == "2s"

-- A new deck runs rank first, then suit.
#guard (fullDeck.take 5).map Card.toString == ["2c", "2d", "2h", "2s", "3c"]
#guard (fullDeck.getLast?).map Card.toString == some "As"

#guard (shuffle 42 fullDeck).length == 52
#guard decide (shuffle 42 fullDeck).Nodup
#guard shuffle 42 fullDeck != fullDeck
#guard shuffle 42 fullDeck == shuffle 42 fullDeck   -- same seed, same deck
#guard shuffle 42 fullDeck != shuffle 43 fullDeck
