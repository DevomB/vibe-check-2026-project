import Engine.Deck

/-!
# Spec: how fair the shuffle is (T2, randomness)

The shuffle (`shuffle` in `Engine/Deck.lean`) builds the new deck one card at a time. Each
time, it picks one of the cards that are left, at a place given by a number from a seeded
generator, and puts it next. This file says what that means without the generator: `pickWith`
does the same picking with any list of numbers.

What can be proved, and what cannot:
- **The method is fair.** With `n` cards there are `n!` lists of valid picks, and each order of
  the deck comes from exactly one of them. So if each valid pick list is equally likely, each
  order of the deck is equally likely: a chance of exactly 1 in `n!`.
- **The real shuffle is this method**, fed by the generator's numbers (`seedPicks`).
- **Whether the generator's numbers are random is not proved.** They come from a fixed rule
  (SplitMix64), on purpose, so a game can be replayed from its seed. That is trusted.
- **The generator has 2^64 states**, far fewer than the 52! orders of a deck. So most orders
  can never come out of any seed.

Definitions a reader must trust: `pickWith`, `ValidPicks`, `allValidPicks`, `seedPicks`,
`factorial`, and the engine's `shuffle`, `nextSeed` and `mixSeed`.
-/

/-- `n!`: 1 × 2 × ... × n, the number of orders of `n` different cards. -/
def factorial : Nat → Nat
  | 0 => 1
  | n + 1 => (n + 1) * factorial n

/-- Shuffle `l` with the picks `picks`. Each pick `i` takes the card at place `i` of the cards
that are left (counting from 0, and wrapping round if `i` is too big), and puts it next in the
new deck. With no picks left, the rest of the cards stay in their order. -/
def pickWith {α : Type} : List Nat → List α → List α
  | i :: is, x :: xs =>
    (x :: xs)[i % (xs.length + 1)]'(Nat.mod_lt _ (Nat.succ_pos _)) ::
      pickWith is ((x :: xs).eraseIdx (i % (xs.length + 1)))
  | _, l => l

/-- `picks` is a list of valid picks for `n` cards: one pick per card, and each pick names a
card that is left. The first pick is below `n`, the next below `n - 1`, and so on. -/
def ValidPicks : Nat → List Nat → Prop
  | 0, [] => True
  | n + 1, i :: is => i < n + 1 ∧ ValidPicks n is
  | _, _ => False

instance : (n : Nat) → (picks : List Nat) → Decidable (ValidPicks n picks)
  | 0, [] => isTrue trivial
  | n + 1, i :: is =>
    match inferInstanceAs (Decidable (i < n + 1)), instDecidableValidPicks n is with
    | isTrue h1, isTrue h2 => isTrue ⟨h1, h2⟩
    | isFalse h1, _ => isFalse fun h => h1 h.1
    | _, isFalse h2 => isFalse fun h => h2 h.2
  | 0, _ :: _ => isFalse id
  | _ + 1, [] => isFalse id

/-- Every list of valid picks for `n` cards, each once. -/
def allValidPicks : Nat → List (List Nat)
  | 0 => [[]]
  | n + 1 => (List.range (n + 1)).flatMap fun i => (allValidPicks n).map (i :: ·)

/-- The generator's numbers for `count` picks, starting from generator state `s`: step the
state (`nextSeed`), mix it (`mixSeed`), and repeat. -/
def seedPicks : Nat → Nat → List Nat
  | 0, _ => []
  | count + 1, s => mixSeed (nextSeed s) :: seedPicks count (nextSeed s)

/-! ## Examples -/

-- 3 cards have 6 orders.
example : factorial 3 = 6 := by decide
-- Picking place 2, then 0, then 0 from [a, b, c] gives [c, a, b].
example : pickWith [2, 0, 0] ['a', 'b', 'c'] = ['c', 'a', 'b'] := by decide
-- Valid picks for 3 cards: below 3, then below 2, then below 1.
example : ValidPicks 3 [2, 1, 0] := by decide
example : ¬ ValidPicks 3 [2, 2, 0] := by decide
example : ¬ ValidPicks 3 [0, 0] := by decide
-- The six valid pick lists for 3 cards.
example : allValidPicks 3 =
    [[0, 0, 0], [0, 1, 0], [1, 0, 0], [1, 1, 0], [2, 0, 0], [2, 1, 0]] := by decide
