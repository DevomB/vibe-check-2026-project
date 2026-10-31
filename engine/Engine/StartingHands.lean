import Poker
import Engine.Deck
import Engine.PreflopData

/-!
# Starting hands and the preflop table

Before the flop the bot does not deal random boards. It looks up its two cards in a fixed
table (`Engine/PreflopData.lean`, MVP section 5). All hands of one kind (for example every
ace-king of one suit) have the same win chance, so the table has one entry per kind: 169
in all. Ported from `src/ai/slider/startingHands.ts` and `preflopTable.ts`.
-/

/-- The rank letters, from two (rank 0) up to ace (rank 12). -/
def rankLetters : List Char := "23456789TJQKA".toList

/-- The two letters for a pair of ranks, written in the order given. -/
def rankPair (hi lo : Nat) : String := String.ofList [rankLetters[hi]!, rankLetters[lo]!]

/-- The kind of starting hand two cards make, higher rank first: a pair (`"77"`), suited
(`"AKs"`) or offsuit (`"T9o"`). -/
def startingHandName (a b : Card) : String :=
  let hi := max a.rank.val b.rank.val
  let lo := min a.rank.val b.rank.val
  if hi = lo then rankPair hi lo
  else rankPair hi lo ++ (if a.suit = b.suit then "s" else "o")

/-- All 169 names, in table order: higher first card first, then higher second card,
suited before offsuit. So `"AA"`, `"AKs"`, `"AKo"`, `"AQs"`, ..., `"32s"`, `"32o"`, `"22"`. -/
def startingHandNames : List String :=
  (List.range 13).reverse.flatMap fun hi =>
    rankPair hi hi :: (List.range hi).reverse.flatMap fun lo =>
      [rankPair hi lo ++ "s", rankPair hi lo ++ "o"]

/-- The table entry for a starting-hand name: wins, ties and losses. `none` for a name that
is not one of the 169. -/
def preflopLookup (name : String) : Option (Nat × Nat × Nat) :=
  preflopTable.lookup name

/-- The table entry for two hole cards. -/
def preflopCountsOf (a b : Card) : Option (Nat × Nat × Nat) :=
  preflopLookup (startingHandName a b)

/-! ## Tests -/

#guard startingHandName (card 13 .diamonds) (card 14 .spades) == "AKo"
#guard startingHandName (card 14 .hearts) (card 13 .hearts) == "AKs"
#guard startingHandName (card 9 .clubs) (card 10 .spades) == "T9o"
#guard startingHandName (card 7 .clubs) (card 7 .spades) == "77"
#guard startingHandName (card 2 .clubs) (card 7 .diamonds) == "72o"

#guard startingHandNames.length == 169
#guard startingHandNames.take 4 == ["AA", "AKs", "AKo", "AQs"]
#guard startingHandNames.drop 166 == ["32s", "32o", "22"]
#guard decide startingHandNames.Nodup

-- The generated table has every starting hand once, in order, and each entry adds up to
-- the number of deals.
#guard preflopTable.map (·.1) == startingHandNames
#guard preflopTable.all fun (_, w, t, l) => w + t + l == preflopSamplesPerHand

-- Every pair of different cards (1,326 of them) has a table entry.
#guard fullDeck.all fun a => fullDeck.all fun b => a == b || (preflopCountsOf a b).isSome

-- Spots from data/preflop.json, as `preflopCounts` in src/ai/slider/preflopTable.ts gives them.
#guard preflopCountsOf (card 14 .clubs) (card 14 .diamonds) == some (42520, 254, 7226)
#guard preflopCountsOf (card 14 .hearts) (card 13 .hearts) == some (33042, 800, 16158)
#guard preflopCountsOf (card 7 .spades) (card 2 .hearts) == some (15772, 2910, 31318)
#guard preflopLookup "nonsense" == none
