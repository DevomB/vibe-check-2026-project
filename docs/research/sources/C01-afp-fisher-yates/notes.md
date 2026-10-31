# C01: Fisher–Yates shuffle (Isabelle AFP entry, Manuel Eberl)

## Summary (also in summary.md)
TL;DR: A machine-checked Isabelle/HOL proof that Fisher–Yates (forward and backward) gives every ordering of a list the same probability. BSD license, maintained up to Isabelle2026.
- The spec shape to copy: "the output distribution equals the uniform distribution over all orderings of the input" (`fisher_yates xs = shuffle xs`).
- Key invariant: after step i, the first i cards are fixed and the rest are a uniform shuffle.
- It assumes perfectly uniform index draws. Turning random bytes into a uniform index (modulo bias) is outside it, and will be outside ours too. The README must say so.
- Cheaper route for us: make our shuffle a pure function of explicit draws `d_k < 52 - k` and prove draws-to-deck is a bijection. That gives uniformity by counting, about our real code, with no probability library. About 8–15 h total; the permutation part alone is 1–3 h.
- No poker or card-game content. It is prior art for the shuffle only.

Verdict: use. It is the reference result for the shuffle claim and gives the invariant for our Lean proof.

## Citation
- Author: Manuel Eberl.
- Title: "Fisher–Yates shuffle". Archive of Formal Proofs (AFP), Isabelle/HOL.
- Date on the entry page: 30 September 2016. Releases listed from Isabelle2016-1 up to Isabelle2026 (26 October 2026).
- Source type: machine-checked formal proof library entry (AFP is refereed by AFP editors; not a conference paper).
- License: BSD.
- URLs fetched 2026-10-31:
  - https://www.isa-afp.org/entries/Fisher_Yates.html (entry page)
  - https://www.isa-afp.org/browser_info/current/AFP/Fisher_Yates/Fisher_Yates.html (theory text)
  - https://www.isa-afp.org/topics/computer-science/algorithms/randomized/ (topic list; confirms this is the only shuffle entry in "Randomized")
- Citation count: not looked up.

## Claim status
| Claim | Status |
|---|---|
| Fisher–Yates (forward and backward versions) returns the uniform distribution over all orderings of the input list | Machine-checked, Isabelle/HOL (checked in every AFP release up to Isabelle2026) |
| Only uniform index choices are used as the random primitive | Read from the theory text (definitions) |

## Setting and definitions
Plain words: a shuffle takes a list and returns a random reordering. "Uniform" means every reordering is equally likely. Fisher–Yates walks along the list; at each position it swaps the current card with a card picked at random from the part not yet fixed.

Precise (from the theory text, Isabelle notation):
- `swap xs i j = xs[i := xs ! j, j := xs ! i]` (exchange the entries at positions i and j).
- Reference spec: `shuffle xs = pmf_of_set (permutations_of_multiset (mset xs))`. In words: the uniform distribution over every list that has the same elements (with the same counts) as `xs`. This handles repeated elements correctly, since it counts distinct lists, not index permutations.
- Forward version: `fisher_yates_aux i xs`: if `i + 1 ≥ length xs` return `xs`; otherwise draw `j` uniformly from `{i..<length xs}` and continue with `fisher_yates_aux (i + 1) (swap xs i j)`. `fisher_yates = fisher_yates_aux 0`.
- Backward version: `fisher_yates_alt_aux i xs`: if `i = 0` return `xs`; otherwise draw `j` uniformly from `{..i}` and continue with `fisher_yates_alt_aux (i - 1) (swap xs i j)`. Starts at `length xs - 1`.
- Random primitive: `pmf_of_set` over a finite range of indices (uniform choice of an index). Probability is modelled as a probability mass function (PMF) monad.

## Main results (exact names from the theory)
- `fisher_yates_correct`: `fisher_yates xs = shuffle xs`.
- `fisher_yates_alt_aux_correct`: `fisher_yates_alt xs = shuffle xs`.
- `fisher_yates_aux_correct` (the induction invariant): `fisher_yates_aux i xs = map_pmf (λys. take i xs @ ys) (shuffle (drop i xs))`. In words: after fixing the first i positions, the result is "the first i cards unchanged, followed by a uniform shuffle of the rest".
- `fisher_yates_alt_aux_altdef`: for `i < length xs`, the backward version equals the forward version applied to the reversed list, then reversed.
- Supporting lemma `shuffle_fisher_yates_step` (for `xs ≠ []`): a uniform shuffle equals "pick a uniform index i, swap position 0 with i, keep the new head, uniformly shuffle the tail".
- Supporting lemma `pmf_of_set_permutations_of_multiset_nonempty`: a uniform random ordering of a non-empty multiset equals "pick the first element with probability proportional to its count, then uniformly order the rest".

## Proof idea (in steps)
1. Show the spec `shuffle` itself decomposes: pick the first element, then shuffle the rest.
2. Show one Fisher–Yates step matches that decomposition (swap with a uniform index = pick a uniform first element).
3. Induct on the position i using the invariant `fisher_yates_aux_correct`.
4. Get the backward version from the forward one by list reversal.

## Assumptions and limitations
- The random draws are assumed exactly uniform and independent (built into `pmf_of_set` and the monad). How real bits become a uniform index (rejection sampling, modulo bias) is not covered.
- It is a proof about a functional model in Isabelle, not about compiled code. Isabelle can export code, but the entry page does not claim that.
- Uses Isabelle's probability library (measure theory based PMFs). Porting the exact proof to Lean would need Mathlib's PMF.

## What is formally verified
- Machine-checked in Isabelle/HOL; the entry is maintained across releases up to Isabelle2026. Nothing in it is about Lean.

## Code artifacts and licenses
- Theory file `Fisher_Yates.thy` in AFP, BSD license. We only link to it; nothing is copied.

## Relevance to our project
- It is the clearest prior art that "Fisher–Yates gives a uniform shuffle" has been machine-checked. It also gives us the right spec shape: "output distribution = uniform over orderings of the input".
- It shows the key induction invariant (first i positions fixed, the rest uniformly shuffled). The same invariant works in Lean.
- But it uses probability theory. For a hackathon, a cheaper honest route exists (below): prove the map from draw sequences to decks is a bijection. That gives uniformity by counting, and it is about our actual shuffle code.

## Cheapest honest route in Lean (my design, opinion; not from the source)
Make the shuffle a pure function of an explicit list of draws. The IO wrapper only produces the draws.
- `shuffleWith (draws : List Nat) (deck : List Card) : List Card`. Draw-and-remove style: at step k, take the card at index `draws[k]` from the remaining cards (valid when `draws[k] < 52 - k`), append it to the output. Or the swap style as in the AFP entry.
- Valid draw sequences: `ValidDraws n ds := ds.length = n ∧ ∀ k < n, ds[k] < n - k`. There are exactly n! of them (52! for one deck).
- Decoder: `drawsOf (deck out : List Card) : List Nat`: for each card of `out` in order, record its index in the remaining cards, then remove it.
- Theorems:
  1. Permutation (easy): `ValidDraws 52 ds → (shuffleWith ds deck).Perm deck`.
  2. Left inverse: `ValidDraws 52 ds → drawsOf deck (shuffleWith ds deck) = ds` (needs `deck.Nodup`).
  3. Right inverse: `out.Perm deck → deck.Nodup → shuffleWith (drawsOf deck out) deck = out` and `ValidDraws 52 (drawsOf deck out)`.
  2 + 3 say: every ordering of the deck comes from exactly one valid draw sequence. If each draw is uniform and independent, every ordering has probability 1/52!. That last step is counting, not a proof obligation, unless we want the PMF version.
- Optional PMF version: push the uniform distribution on draw sequences through the bijection; a bijection maps a uniform distribution to a uniform one. Mathlib has `PMF.map`, but no lemma for mapping along a bijection, and on current master the `PMF.uniformOfFinset` / `PMF.uniformOfFintype` names are deprecated aliases (since 2026-10-04) for measure-based versions (see C02 notes for the URLs). So the PMF version means more work and depends on the Mathlib rev.
- What stays outside the proof: the source of random numbers (`IO.rand`, a seed, or OS random bytes) and the conversion of bytes into a number below `52 - k`. With `% (52 - k)` on random bytes there is a small modulo bias; rejection sampling avoids it. We should state this trust boundary in the README.

## Candidate theorems for us
| Plain English | Lean 4 shape (sketch) | Hours (strong Lean user) |
|---|---|---|
| The shuffle returns the same 52 cards, just reordered | `theorem shuffle_perm (ds) (h : ValidDraws 52 ds) : (shuffleWith ds fullDeck).Perm fullDeck` | 1–3 |
| The shuffled deck has no repeated card | `theorem shuffle_nodup (h : ValidDraws 52 ds) : (shuffleWith ds fullDeck).Nodup` (from the above plus `fullDeck.Nodup` by `decide`) | 0.5–1 |
| Different draw sequences give different decks | `theorem shuffle_injective : ValidDraws n a → ValidDraws n b → shuffleWith a d = shuffleWith b d → a = b` (with `d.Nodup`) | 3–6 |
| Every ordering is reachable by exactly one draw sequence | `theorem shuffle_onto : out.Perm d → d.Nodup → ∃! ds, ValidDraws d.length ds ∧ shuffleWith ds d = out` | 4–8 |
| (Stretch) With uniform draws, every ordering has probability 1/52! | `theorem shuffle_uniform : (drawDist 52).map (shuffleWith · fullDeck) = PMF.uniformOfFinset (orderings fullDeck) _` (names unsure) | 8–15 |
