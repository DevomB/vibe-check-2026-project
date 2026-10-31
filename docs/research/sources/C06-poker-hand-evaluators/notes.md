# C06: Poker hand evaluators: HenryRLee/PokerHandEvaluator (perfect hash) and Cactus Kev's evaluator

## Summary (also in summary.md)
TL;DR: Fast poker evaluators map every hand to one of 7,462 strength classes using lookup tables. Their correctness evidence is testing, not proof: PokerHandEvaluator compares itself with Cactus Kev's evaluator on every 5-, 6- and 7-card hand. I found no formally verified poker hand evaluator in any proof assistant. That is novelty for us.
- 7,462 = 6,175 non-flush rank patterns + 1,287 flush rank sets. Both evaluators depend only on (the ranks, flush or not). So an exhaustive check can run over 7,462 patterns instead of 2,598,960 hands, after one general "only ranks and flush matter" lemma.
- The honest Lean plan: a simple, readable reference evaluator (category + tie-break list) is the spec. If we want a fast one, prove it equal to the reference on the 7,462 patterns plus the general lemma. Kernel `decide` on 7,462 cases may be feasible; on 2.6M hands it is not (opinion).
- 7-card hands: define the 7-card value as the best of the 21 five-card subsets. Then 7-card correctness follows from the 5-card proof by construction; no 133,784,560-hand check is needed.
- Cactus Kev's page could not be opened (expired certificate). Its details are UNVERIFIED here.

Verdict: use. It gives the counts, the test strategy to copy, and confirms that a verified evaluator is new.

## Citations and URLs (fetched 2026-10-31)
1. Henry Lee, "PokerHandEvaluator" (C/C++, Python `phevaluator`, many ports). Code repository, license Apache-2.0.
   - https://github.com/HenryRLee/PokerHandEvaluator (README)
   - https://github.com/HenryRLee/PokerHandEvaluator/blob/develop/Documentation/Algorithm.md (algorithm)
   - https://github.com/HenryRLee/PokerHandEvaluator/tree/develop/cpp/test (test list)
   - https://github.com/HenryRLee/PokerHandEvaluator/blob/develop/cpp/test/evaluation.cc (exhaustive tests)
2. Kevin Suffecool ("Cactus Kev"), "Poker Hand Evaluator", http://suffe.cool/poker/evaluator.html — UNVERIFIED: fetch failed (certificate expired; archive.org blocked for this tool). Not counted as a source. Anything about its internals below is marked unsure.
3. Two Plus Two evaluator: not opened (forum thread). UNVERIFIED.
- Source type: code repositories and technical documentation (non-academic, allowed as artifacts).
- Searches for any formal verification of a poker hand evaluator (Coq, Isabelle, Lean) found none. The search hit only unverified libraries in Rust, Python, Haskell, Go and others.

## Claim status
| Claim | Status |
|---|---|
| Five-card hands fall into 7,462 distinct strength values (Cactus Kev's scheme) | Stated in the README; matches my own counting (below, proved on paper by simple arithmetic, checked with a calculator script) |
| phevaluator equals Kev's evaluator on all 2,598,960 five-card, 20,358,520 six-card and 133,784,560 seven-card hands | Shown empirically: exhaustive gtest cases `TestFiveCards`, `TestSixCards`, `TestSevenCards` with `EXPECT_EQ(ph_eval, kev_eval)` |
| Perfect hash gives each valid pattern a unique index | Informal argument in Algorithm.md (lexicographic rank of the pattern) |
| Speed: all 133,784,560 seven-card hands in about 2.23 s (about 60 M hands/s); random 7-card "1778 ns (56 M/s)" as printed (the ns figure and the rate do not fit a single hand, so the ns is probably per batch; unsure); 12 × 2600 MHz CPU, 2023-09-02 | Shown empirically (benchmark) |
| Memory: 5-card 60k, 6-card 84k, 7-card 144k (pmap) | Shown empirically |

## Setting and definitions
Plain words:
- A hand evaluator takes 5 to 7 cards and returns a number. A better hand gets a better number. Equal hands (same strength, different suits) get the same number.
- A "hand class" is a set of hands with exactly the same strength. With five cards there are 7,462 classes.

Counts (my own arithmetic, checked with Python `math.comb` on 2026-10-31):
- Five-card hands: C(52,5) = 2,598,960. Six-card: C(52,6) = 20,358,520. Seven-card: C(52,7) = 133,784,560.
- Classes per category: straight flush 10; four of a kind 13·12 = 156; full house 13·12 = 156; flush C(13,5) − 10 = 1,277; straight 10; three of a kind 13·C(12,2) = 858; two pair C(13,2)·11 = 858; one pair 13·C(12,3) = 2,860; high card 1,277. Total 7,462.
- Another split: non-flush rank patterns (multisets of 5 ranks, each rank at most 4 times) = C(17,5) − 13 = 6,175; flush patterns (5 distinct ranks) = C(13,5) = 1,287; 6,175 + 1,287 = 7,462.

PokerHandEvaluator algorithm (from Algorithm.md):
1. Baseline: a 7-card hand is a 52-bit word with 7 ones; its lexicographic index needs C(52,7) entries. Rejected as too big and slow.
2. Flush split: count cards per suit. If a suit has 5 or more cards, the hand is a flush or straight flush (the other two cards cannot make quads or a full house), and two flushes cannot occur in 7 cards. Look up the 13-bit rank set of that suit in a table of 2^13 = 8,192 entries.
3. Non-flush: write the ranks as a 13-digit base-5 number (count of each rank, 0–4) with digit sum 7. Its perfect hash is its rank in lexicographic order, computed with a small DP table `dp[l][n][k]` (stated size 5 × 14 × 8). The final table has 49,205 entries; the hash takes at most 13 steps.
4. A block-based variant (4 × 16-bit blocks) was tried and was not faster.
- Correctness argument in the doc: informal only (lexicographic ranking is one-to-one; the flush shortcut argument).

Cactus Kev (unsure, not opened): known from many secondary descriptions to encode each card as a 32-bit integer with a rank prime, and to use the product of primes to look up non-flush hands. I could not verify this.

## Assumptions and limitations
- The evaluators are tested, not proved. The reference in the tests (Kev) is itself tested, not proved.
- Lookup tables are data. A general proof about a table is a proof by checking every entry.

## What is formally verified
- Nothing. No machine-checked evaluator found.

## Code artifacts and licenses
- PokerHandEvaluator: Apache-2.0. Cactus Kev's code: license unknown (page not opened).

## Feasibility in Lean (opinion, my estimates)
- Kernel `decide` over all 2,598,960 five-card hands: very likely too slow or too much memory. Not recommended.
- `native_decide` over 2,598,960 hands: likely seconds to minutes in compiled code. But it adds the `Lean.ofReduceBool` axiom. CLAUDE.md says Comparator and `lake check` fail on non-allowed axioms. Ask the organizers before relying on it.
- Symmetry route (recommended): prove in general that each evaluator's value depends only on (sorted ranks, is-flush). Then check the 7,462 patterns. With small, structurally recursive code, kernel `decide` on 7,462 cases may run in minutes (unsure; test early). If too slow, split into chunks by category.
- 7-card: define `eval7 h = max over the 21 five-card subsets of eval5`. Then nothing extra to check. If a fast 7-card evaluator is used instead, its exhaustive check over 133,784,560 hands needs `native_decide` and probably minutes to an hour (opinion).
- Speed need: exact heads-up preflop equity needs C(48,5) = 1,712,304 runouts, each with two 7-card evaluations. With best-of-21 that is about 72 million 5-card evaluations. Compiled Lean can likely do this in seconds (opinion); fine for game review, maybe slow for live play.

## Relevance to our project
- Gives the exact class counts for unit tests (`#guard` the per-category class counts).
- Gives the differential-testing plan: compare our Lean evaluator against `phevaluator` (Python, Apache-2.0) on random or all hands, outside the proof.
- Gap: no prior verified evaluator. Strong demo claim.

## Candidate theorems for us
| Plain English | Lean 4 shape (sketch) | Hours |
|---|---|---|
| The reference ranks hands the way the rule book does: category first, then tie-break cards | Spec by definition: `def refValue (h : Hand5) : Category × List Rank` with lexicographic order; plus `#guard`s and `¬` examples (e.g. a pair never beats two pair) | 3–5 |
| Swapping suits without changing flushness does not change the value | `theorem eval5_suit_invariant (h h') (hr : ranks h = ranks h') (hf : isFlush h = isFlush h') : eval5 h = eval5 h'` | 3–6 |
| The fast evaluator agrees with the reference on all hands | `theorem fast_eq_ref : ∀ h : Hand5, fastValue h = refValue h` via the lemma above plus `decide` over the 7,462 patterns | 4–10 (risk: `decide` speed) |
| Exactly 7,462 distinct values over all five-card hands | `theorem classes_count : (allPatterns.map refValue).dedup.length = 7462` (on patterns) | 1–3 |
| The 7-card value is the best five-card hand inside it | `theorem eval7_spec (h : Hand7) : ∃ s ⊆ h, s.length = 5 ∧ eval7 h = eval5 s ∧ ∀ t ⊆ h, t.length = 5 → eval5 t ≤ eval7 h` | 3–6 |
