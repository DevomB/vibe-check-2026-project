# Synthesis

> **Historical.** Written on Oct 31, before the build. The shipped product differs: other
> slider rules (no aggression slider, no quadratic Risk formula), no Kuhn or Leduc mode, a
> Node bridge instead of Python, and sampled (Monte Carlo) preflop and flop counts. A
> `KuhnPoker/` folder was never in the repo. What was built and proved is in
> [SPEC.md](../../SPEC.md) and the [README](../../README.md).

Written by the research lead after reading all 40 summaries, and the notes where needed.
Source ids (A01, E09, ...) point to [INDEX.md](INDEX.md). Hour estimates assume the
teammate who is strong in Lean. They are rough, and most come from the source agents.

**The plan survives.** The research found no fatal problem with the product. It did force
five design rules on the build. Each one keeps the proofs about the code that runs:

1. **Exact numbers only.** Use exact fractions (`Rat`, in core Lean) or integer chips
   everywhere: in the bot, the equity and the review. Never use `Float`, `exp` or Monte Carlo.
   Proofs about floating point are close to impossible, and `exp`/`log` are not exact (B01, D07, E02).
2. **Randomness comes in as explicit numbers.** The shuffle and the bot's bluffs are pure
   functions of draws, as the Kuhn AI already does with its `roll`. The random source
   itself stays outside the proof, and the README says so (C01, C02).
3. **No `native_decide`.** Since v4.29, each use adds its own axiom, and `lake check`
   rejects it (D02). Prove general lemmas, and run `decide` only on small cases.
4. **The review only ever sees the player's view.** Grade from what the human could
   see, averaged over the bot's possible hands. Never use the bot's real cards (E03, E04, E05).
5. **The bot decides from a "reason" record.** Compute the numbers that matter (equity,
   pot odds, slider terms) into a small record first, then choose the action from that
   record only. This costs nothing now and makes live review provable later (E07).

---

## 1. Verification targets, ranked

Each target gives the theorem as a judge would hear it, the code it is about, the method,
the hours, the risk and the sources.

### Worth it

| # | Theorem, in plain words | Code | Method | Hours | Risk | Sources |
|---|---|---|---|---|---|---|
| W1 | **No chips are ever created or destroyed.** After every action, the stacks plus the pot add up to 1,000. | engine `step` / `applyAction` | Proof by cases on the action. Run plausible first, with a generator of legal action sequences. | 3-6 | Low | C07, D04 |
| W2 | **The engine accepts only legal moves, and every hand ends.** Illegal input is rejected, and a hand ends within a fixed number of actions. | `legalActions`, `step` | Proof, with a decreasing measure for termination. Covers the min-raise rule (TDA 45-A), the short all-in rule (49-A) and the heads-up blinds (36-C). | 4-8 | Medium: no-limit raise rules have edge cases | C07 |
| W3 | **Every deal uses 52 different cards.** The shuffle only reorders the deck, so no card can appear twice. | `shuffle draws deck`, `deal` | Proof: the output is a permutation of the input. | 2-4 | Low | C01 |
| W4 | **The showdown winner follows the rulebook's hand ranking.** A readable evaluator (category, then tie-break ranks) is the spec. The 7-card value is the best of the 21 five-card hands, by construction. The evaluator ignores suits except for flushes. | `evalHand` | The reference *is* the readable code. Prove simple facts: it is a total order, it ignores suits except for flushes, and its 7-card value is the best of the 21 five-card hands. Add `#guard` tests on known hands. | 3-6 | Low. Speed is the risk (see W5) | C06, D07 |
| W5 | **The equity shown counts every possible remaining board exactly once.** Board lists have no repeats, use no dead cards, and have the right count. Both players' equities add up to 1. | `runouts`, `equity` | Proof over exact `Rat`. Benchmark preflop all-ins early: 1,712,304 boards and about 3.4 million evaluations. | 6-11 | Medium (speed) | D07 |
| W6 | **"Best" means exactly zero EV lost, and accuracy is 100 exactly when no EV was lost.** Labels go from Best to Blunder as the loss grows, and every loss gets exactly one label. | review `label`, `accuracy` | Proof over `Rat`, with half-open bb ranges. The spec rejects Lichess's formula, which gives 100 for a small loss: a good bad-output example. | 3-8 | Low | E01, E02, E05 |
| W7 | **Your grade never depends on cards you could not see.** Two games that look the same to you at a decision get the same verdict. | review entry point takes a `PlayerView` | Proof. It is near-trivial once the review takes only the player's view, but it is the statement judges care about. | 1-3 | Low | E03, E05, E06 |
| W8 | **Result = skill + luck + seat edge, on every single hand.** The luck terms average to zero over the cards that could have come. | review `decompose` | The identity telescopes: it is exact algebra on one recorded hand. Mean zero is a finite weighted sum over the cards still in the deck. No probability library is needed. | 3-6 | Low | E09, E10, E03 |
| W9 | **Risk slider: a more cautious bot is pickier.** If the more cautious bot takes a gamble over the sure option, the bolder bot takes it too. | bot utility `u r x = x - r*x^2/(2M)` and the call/fold or shove/fold choice | Proof over `Rat`: the gain is a straight line in `r`, and `E[X^2] >= 0`. Prove the strict version first. No Mathlib needed. | 3-5 | Low | B01, B02 |
| W10 | **Aggression slider: more aggression never means smaller bets or fewer raises** in the same spot, with the other sliders fixed. | bot `betSize`, `raiseThreshold` | Proof of monotonicity. Design the formulas to be monotone, including the cap at the stack. | 2-4 | Low, if designed in | (design) |
| W11 | **Bluff slider: on its final-round bets, the bot bluffs exactly slider × the balanced share.** The balanced share is `s/(1+2s)` for a bet of `s` times the pot. | bot river betting with explicit draw `d < N` | Two parts. The algebra takes 1-2 h. The real bot, counting (hand, draw) pairs, takes 4-10 h. First fix the spec: share, not count (see Open Questions). | 5-12 | Medium: the range may run out of bluff hands at slider 2 | A03, A02 |
| Done | **Kuhn AI is unbeatable.** No fixed plan wins more than the game value of -1/18 per hand (in units of 1/162), in either seat. The bound is reached, and an AI that never bluffs is beatable. | `KuhnPoker/` (already in repo) | `decide` over all 64 pure plans per seat. The research confirms the method is sound: a worst-case opponent can always be a pure strategy (A01, A06). | done | None | A01, A06, C04 |

### Maybe (stretch)

| # | Theorem, in plain words | Code | Method | Hours | Risk | Sources |
|---|---|---|---|---|---|---|
| M1 | **Side pots pay the right people.** Pot totals equal the chips committed. A folded player wins nothing. Nobody wins more from an opponent than they matched. Each pot is split on its own, and the odd chip goes left of the button. | `buildPots`, `award` | Proof, after plausible tests. Real sites have paid the wrong player (GGPoker 2022, UltimateBet 2008): a good slide. | 8-16 | Medium: TDA gives no algorithm, so we write the spec | C07 |
| M2 | **The shuffle is fair.** Every order of the deck comes from exactly one sequence of draws, so with fair draws every order is equally likely. | `shuffle draws` | Prove a decoder and two inverse lemmas. Fairness then follows by counting, with no probability library. | 8-15 | Medium | C01, C02 |
| M3 | **Live review tells the truth.** The reason shown is exactly what produced the bot's move: replaying the reason gives the same move. Any spot with the same reason gets the same move. | bot `reason`, `decideFrom` | Replay: 0.5-1 h. Sufficiency: 3-6 h. Minimality (no listed fact can be dropped): 6-12 h. | 4-7 (without minimality) | Low, if design rule 5 is followed | E07, E08 |
| M4 | **The opponent-model bluff is profitable by the bot's own estimate, and stays within budget.** It bluffs only when its estimated fold rate beats pot odds, and never risks more than it has banked. | opponent model + bluff rule | The rule implies the inequality. The budget never goes below 0 (A05, Lemma 6.3). The full "never worse than the game value" guarantee holds only in Kuhn, where the value is known. | 2-5 | Low | A05, A02 |
| M5 | **Fast evaluator = readable evaluator.** | `fastEval` | One general lemma ("only the ranks and the flush matter"), then `decide` on 7,462 patterns. Kernel speed is untested. | 7-16 | High (kernel speed) | C06 |
| M6 | **Leduc strategy is unexploitable.** | Leduc mode | An untrusted solver (CFR, outside Lean) proposes the strategy. A best-response tree walk, proved correct, shows exploitability 0. Pure-strategy enumeration does not scale to Leduc. | 10-20 | High | A02, A04, A06, C04 |
| M7 | **General Pratt theorem.** Any utility that is a concave increasing transform of another is pickier about every gamble. | utility library | Mathlib `ConcaveOn.le_map_sum` works over `Rat`, but it needs Mathlib. W9 already covers our actual slider. | 3-6 | Low, but costs a Mathlib dependency | B01, B02 |
| M8 | **Tournament payouts conserve money** (3-6 players with a payout table). ICM finish chances add up to 1, and prize values add up to the prize pool. | ICM | Proof over `Rat`. | 4-9 | Low | B04, B05 |

### Skip

- **Proving CFR converges.** It is far too costly, and even the published CFR+ proof had a
  hole that later work fixed (C08). Check CFR's output instead (M6).
- **A probability-library shuffle proof** (Mathlib PMF, SampCert). It is heavy, some `PMF.uniformOf*`
  names were deprecated on 2026-10-04, and M2 gives the same claim by counting (C02).
- **Exhaustive checks over 2.6 million or 133 million hands.** These need `native_decide`, which fails `lake check` (D02).
- **Exact verdicts before the river against the bot's full future play.** Too costly. Show them
  as labeled estimates. The W8 identity still holds exactly for any value function (E10).
- **Mean-variance as the risk slider.** It is provably wrong: it refuses a free gamble of
  0 or +100 chips (B01). Keep it only as a one-hour "the spec rejects this" counterexample.
- **Gilbert's ICM risk-aversion theorem** (6-10 h), unless the 3-6 player mode gets a multi-place payout (B05).
- **vcgen, Velvet, Veil, iris-lean.** They target imperative or concurrent code. Our engine is pure functions (D03).

---

## 2. Novelty: what we found no prior formalization of

The agents searched GitHub, the Isabelle AFP, DBLP, arXiv and Lean libraries. They found
**no** machine-checked poker engine, hand evaluator, CFR, exploitability computation,
poker luck/skill split, or Pratt-style risk theorem in any proof assistant. Say "we found
none", not "first ever".

What would impress judges, most impressive first:

1. **A provably unexploitable poker AI that you can play** (Kuhn, already in the repo). Real
   poker AIs claim low exploitability from experiments (A07). Ours is a theorem. Nearest prior
   work: a 2026 Lean preprint on the Pokémon card game's deck metagame (C04). It is not an engine,
   and it relies on `native_decide`.
2. **A game review whose grades are proved fair.** Grades ignore hidden cards (W7), and
   result = skill + luck exactly (W8). This is the formal answer to outcome bias, the
   well-studied habit of judging a decision by its result (E06).
3. **A risk slider with a theorem behind it** (W9). The Isabelle AFP has von Neumann-Morgenstern
   utility, but no risk aversion (B03).
4. **Explanations that are faithful by proof, not just convincing** (M3). The literature
   says faithfulness is hard to reach for neural models (E08). For a small rule-based bot it is provable.
5. **A side-pot engine with conservation proofs**, set against real wrong-winner bugs (M1, C07).

Prior art to cite: Isabelle Fisher-Yates (C01), Nipkow's verified alpha-beta search (C08), Coq
sequential games (C03), Lean game theory libraries (A08, C05), SampCert (C02).

---

## 3. Recommended MVP cut (first 12 hours) and stretch ladder

Budget: 4 people × 34 hours. Plan about half of each person's time for proofs.

**Hour 0-1, everyone:** agree on the state record, the `PlayerView` type, the `Reason` record
(design rule 5) and the JSON protocol. Write the theorem statements as `sorry`s in a
`Challenge.lean` (D02). This list is the spec the team reviews.

**Hours 1-12:**

| Person | Builds | Proves |
|---|---|---|
| Lean lead | Heads-up NLHE engine: blinds, legal actions, min-raise, short all-ins, showdown | W1, W2 |
| P2 | Cards, deck, shuffle from draws, readable evaluator, runouts, exact equity. Benchmark preflop all-in by hour 4. | W3, W4 |
| P3 | Bot v1: equity vs pot odds; risk, aggression and bluff sliders as exact formulas; `Reason` record | W9, W10, W11 (algebra part) |
| P4 | GUI and API (keep the working Python bridge; spike `Std.Http` only if time allows), Makefile, `make check` in WSL running `lake check` and `lake comparator` | W6, W7 |

**Hour-12 checkpoint:** heads-up hand playable in the browser. The review labels river
and all-in decisions. W1-W4, W6, W7, W9 and W10 are proved. Comparator passes in WSL.

**Stretch ladder, in order:**

1. W8: skill + luck = result, with the luck graph in the GUI (3-6 h).
2. W5: the equity enumeration proofs (6-11 h).
3. W11: the bluff share on the real bot (4-10 h).
4. M3: live review, replay and sufficiency (4-7 h). This is the "wow" demo feature (see section 5).
5. M1: 3-6 players with side pots (8-16 h).
6. M2: shuffle fairness by counting (8-15 h).
7. M4: the opponent-model bluff rule (2-5 h).
8. M6: Leduc mode (10-20 h), only if everything above is done.

---

## 4. Proofs about the code, or only about a model?

The rules say judges care whether proofs cover the real code. Watch these points:

- **The Kuhn prototype is about the code.** Its theorems name `aiBetWeight` and the rule
  functions directly, and `aiMove_matches_weight` ties the move to the weights. One part is
  a spec-side definition: `expectedWin`, the expected-payoff calculator in `Spec.lean`. It is
  part of the trusted surface, so a reviewer must read it. Copy this pattern.
- **W11 algebra alone is about a formula, not the bot.** The proof that `s/(1+2s)` balances the
  caller is about a formula. The bluff-slider claim only counts once it is proved about the bot's
  actual river decision function (W11, part 2).
- **M7 over real numbers would be about a model.** A Pratt theorem over `ℝ` says nothing about
  a bot that computes in `Rat`. W9 must be stated about the bot's own utility function.
- **Randomness.** Proofs cover functions of explicit draws. The OS random source, and turning
  random bytes into a fair draw below n (modulo bias), are outside the proof (C01, C02). Say so.
- **The GUI must stay a thin display.** Any number the JavaScript computes (equity, pot sizes)
  is unverified. Every number on screen should come from the Lean binary. The Kuhn server's
  `--mock` mode is unverified, and the GUI badges it.
- **Pre-river verdicts are estimates.** The identity W8 is exact for any value function, but
  "this was a mistake" is exact only on the river and in all-in spots. Label the others in the UI.
- **Safe exploitation (M4).** The full guarantee needs the game value, so it holds only in
  Kuhn. In hold'em, only the per-decision rule and the budget lemma are proved.
- **Differential tests** against our `poker-calculations` library give evidence that the evaluator
  and equity code are right, not proof. Report them as tests.
- **Trusted shell.** The HTTP/JSON layer, the Python bridge (if kept), the Lean compiler and runtime are trusted, not verified.

---

## 5. Parked idea: live review

**Verdict: un-park it as stretch step 4. It is cheap if design rule 5 is followed from hour 0.**

- **What we can prove.** Write the bot as `act s = decideFrom (reason s)`, where `reason s` holds
  the exact equity, pot odds and slider terms.
  - **Replay** (0.5-1 h): the move shown equals `decideFrom` of the reason shown. This is true by
    construction, so it is honest but weak.
  - **Sufficiency** (3-6 h): any spot with the same reason gets the same move. This is the meaningful
    theorem: the listed facts force the move (an "abductive explanation", E07).
  - **Minimality** (6-12 h): no listed fact can be dropped. It is optional, and true only if the
    record is built carefully.
- **What we cannot prove.** That the explanation *text* is a good English rendering of the
  record. Generate the text from the record with fixed templates, and keep templates short.
  LLM commentary would be plausible only, not faithful (E08). Leave it out, or label it as unverified.
- **Live hints for the human** are the bot's own evaluation of the human's spot. They are
  fine in our closed app against our own bot. Real-money sites and GTO Wizard's terms ban
  real-time assistance (E05), so say so in the demo.
- **Cost and risk.** About 4-7 hours plus GUI work. The risk is low, because it reuses the
  equity code and the `Reason` record. The demo value is high: "the bot shows exactly why
  it bluffed, and Lean proves that is the real reason".
