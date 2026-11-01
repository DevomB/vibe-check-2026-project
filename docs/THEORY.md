# The theory behind the slider and the review

This document explains, for every number the bot and the review use, the formula, where
the Lean engine computes it, the source that supports it, and the exact conditions under
which that source applies. It is written to be checked: each section names one Lean
function and one or more sources from [the research index](research/INDEX.md). Line numbers
will be added once the one-slider Lean change has landed.

Two rules for reading it. First, a Lean theorem says only what its statement says, and the
README's "What we trust" section lists what a reader must still check. Second, nothing here
claims that the bot plays well. The README lists "the bot playing well" as not proved, and
the one-slider work does not change that. Where a setting agrees with a textbook result we say
"matches the textbook ratio", never "optimal" or "GTO".

## 1. One slider, two internal numbers

The player sees one slider, **Risk, 0 to 100**, meaning appetite for risk. The engine keeps its
two internal numbers unchanged: `caution` (today's code calls it `risk`), which says how heavily
a lost chip counts, and `bluffPct`, the share of bluffs in the bot's river betting set. The map
is `Sliders.ofRisk` in `engine/Engine/Slider.lean`:

```lean
def Sliders.ofRisk (r : Nat) : Sliders :=
  let r := min r 100
  if r ≤ 50 then ⟨100 - 2 * r, (33 * r + 25) / 50⟩
  else ⟨0, 33 + (27 * (r - 50) + 25) / 50⟩
```

Below 50, more Risk lowers caution and raises bluffing. Above 50, caution is already 0 and only
bluffing rises. The direction flips from the old UI, where higher Risk meant more careful.

| User Risk | Internal caution | Internal bluffPct | Who this was in the old roster |
|---|---|---|---|
| 0 | 100 | 0 | Ivy |
| 25 | 50 | 17 | (new) |
| 40 | 20 | 26 | (new) |
| 50 | 0 | 33 | Mia |
| 75 | 0 | 47 | (new) |
| 100 | 0 | 60 | Vex, and the practice challenges' bot |

Every proved theorem is stated over an arbitrary `Sliders` value, so all of them keep holding
for every value `ofRisk` can produce. The theorems about the map itself are listed in the
lane 1 report (`tasks/reports/sunday-1-one-slider.md`).

## 2. The formulas, where they live, and what supports them

### 2.1 Pot odds: the equity a call needs

**Formula.** A call that pays `cost` chips to win `prize` chips breaks even when the share of
the bot's hands you beat (ties counting half) is at least `cost / (prize + cost)`.

**Where.** `gradeRiver` in `engine/Engine/Review.lean` sets `equityNeeded` to
`cost / (prize + cost)` and `equityHad` to `(2 × wins + ties) / (2 × hands)`. `RiverSpot.prize`
and `RiverSpot.cost` take back any part of the bet you cannot match.

**Source.** A03 derives the caller's required equity as S / (P + 2S) for a bet S into a pot P.
With prize = P + S and cost = S, `cost / (prize + cost)` is the same number. This is plain
arithmetic, not a model result, so it holds without extra conditions. F02 (Glosten and Milgrom)
is the reason the review measures that equity against the hands the bot would bet with, not a
random hand: the bet itself is information, and a zero-profit pricer conditions on it.

**Theorems.** `review_call_best_iff_equity`: calling is graded Best exactly when `equityHad` is
at least `equityNeeded`. `review_worth` and `review_lost` tie the worths and the loss to the
chips really at stake.

### 2.2 The bluff ratio: why 33% is the textbook setting

**Formula.** The bot's river bet is pot-sized, and for a pot-sized bet the break-even share of
bluffs in the bettor's range is bet / (pot + 2 × bet) = 1/3. In general it is s / (1 + 2s) with
s = bet / pot.

**Where.** `riverBetOrCheck` with `View.potBetTarget` in `engine/Engine/Slider.lean` makes the
river bet pot-sized (cut down to the legal range when needed). In `engine/Engine/River.lean`,
`valueCount` takes the top `valuePct` = 30% of the 1,081 candidate hands, rounded down, so 324
value hands; `bluffCount values b` adds `values × b / (100 − b)` bluffs, rounded to the nearest
whole hand with halves up. At b = 33 that is 324 × 33 / 67 = 159.6, so 160 bluffs, and bluffs are
160 of 484 bets, 33.1%.

**Source.** A03 (Ferguson and Ferguson, restating von Neumann's one-bet poker model) derives
the share from the caller's indifference equation. The ratio is exact only under these
conditions, copied from A03: one final betting decision with no cards to come and a caller who
can only call or fold; a polarized betting range, where every bet hand either beats the caller's
hand or loses to it, with no ties; chip payoffs, so a risk-neutral caller; the effective bet when
a stack is short; no rake. The brief also names Chen and Ankenman's river game as a reference;
A03 records that book as not opened (UNVERIFIED), so we do not cite anything from it.

**What this does not say.** The bot's betting set is board-only and ignores the earlier
betting. Its pre-river bets use fixed 65% and 75% win-chance rules against a random hand. The 30%
value cut is our choice. So the ratio is matched inside our own river set; the bot is not a
solved or unexploitable strategy.

**Theorems.** `bluff_frequency` (the set has the nearest whole number of bluffs to the target
share), `value_and_bluffs_apart`, `bot_bets_its_set`, `botDecide_river_follows_set`, and, on
the branch `sunday/review-fixes`, the newly registered `value_strongest` and `bluffs_weakest`
(value hands are the strongest candidates, bluffs the weakest).

### 2.3 Minimum defence frequency

**Formula.** Against a bet S into a pot P, the caller must continue with share P / (P + S) of
its hands for a pure bluff to break even. For a pot-sized bet that is 1/2.

**Where.** Nowhere. We checked `engine/` on 2026-11-01: the engine does not compute this number.
The review grades each call by pot odds against the bot's actual set (2.1), not by how often you
defend.

**Source.** A03 derives it alongside the bluff share, under the same conditions.

### 2.4 The loss weight: what caution means

**Formula.** Each lost chip counts (1 + caution / 50) times a won chip. In whole numbers,
`callPays` in `engine/Engine/Slider.lean` calls when

```
100 × (2 × win × pot + tie × (pot − toCall)) ≥ 2 × (100 + 2 × caution) × loss × toCall
```

where win, tie and loss are the counts of the bot's possible outcomes. At caution 0 this is
plain chip profit. Against a pot-sized bet the bot needs a 1/3 win chance at caution 0, 1/2 at
50 and 3/5 at 100 (the examples next to `callPays`).

**Source.** B01 (Pratt 1964): a more risk-averse decision maker turns down every risky-or-sure
choice that a less risk-averse one turns down. Our loss weight is the row "loss penalty relative
to current stack" in B01's table: it is a penalty on one decision, not a fixed utility over final
chips, and B01 says to disclose that. F03 (Avellaneda and Stoikov) is the market-making reading
of the same dial, see section 4.

**Theorems.** `more_risk_takes_fewer_gambles` (for any gamble, if a more cautious bot takes it a
less cautious one does), `risk_monotone` and `botDecide_risk_monotone` (at one decision, if the
bot calls or raises at some caution it does so at every lower caution), `callPays_iff_takes`,
`bot_calls_only_when_worth_it`, `bot_folds_only_when_not_worth_it`, `no_loss_always_taken`.
These compare one decision at a time; they say nothing about whole games. For the user's slider
the direction flips: more Risk never folds a call the bot would have called at less Risk. That
statement is lane 1's new theorem, listed in its report.

### 2.5 Exact equity

**Formula.** The bot's win chance is a count, never a decimal: on the river, how many of the 990
possible opponent hands it beats, ties and loses to; on the turn, the same over all 45,540
(river card, opponent hand) pairs. Every hand is scored with the spec's `bestScore` and counted
by the spec's `showdown` rule.

**Where.** `countsFor` in `engine/Engine/Equity.lean`. The flop uses 1,000 seeded deals and the
preflop uses a stored table; those two are estimates, listed as trusted data in the README.

**Source.** C06: fast hand evaluators are validated by exhaustive comparison with each other, not
by proof, and no proof-assistant evaluator was found; ours uses the spec's own scorer. E05:
poker tools measure hands by equity, the share of the pot a hand expects to win; our counts are
that share, exact.

**Theorems.** `enumeration_exact`, `riverOpponentHands_length`, `turnOutcomes_length`,
`countsFor_river`, `countsFor_turn` (T6). Limit: the bot's equity is against a random hand, not
against what your betting says you hold.

### 2.6 The grade bands

**Formula.** The review labels a call or fold by the big blinds it lost against the better of
the two: Best = 0, Good under 0.5, Inaccuracy under 2, Mistake under 5, Blunder from 5. Exact
fractions, compared before any rounding.

**Where.** `labelFor` in `engine/Engine/Review.lean`; MVP section 6.

**Source.** None sets these numbers. **The bands are our own choice.** E01 (Chess.com) shows
the convention of labelling a move by what it lost against the best move, with fixed bands and
an unpublished formula; E02 (Lichess) publishes its formula; E05 (GTO Wizard) reports EV lost
per action in big blinds and colours it by band without publishing thresholds. We publish ours.

**Theorems.** `review_best_iff` (Best exactly when nothing was lost), `review_label_monotone`
(fewer big blinds lost never gets a worse label). The band edges themselves are only in
`labelFor`; a reader must check them there.

## 3. Why Risk 50 is the "ideal", and the exact limit of that claim

At Risk 50 the internal pair is (caution 0, bluffPct 33).

- Caution 0 means the bot calls exactly when the call wins chips on average
  (`callPays_iff_takes`, `bot_calls_only_when_worth_it`, `bot_folds_only_when_not_worth_it`).
  That is the risk-neutral rule, and it is the rule the market makers in F01 and F02 use.
- Its river bet is pot-sized, and A03's break-even bluff share for a pot-sized bet is 1/3. With
  bluffPct 33 the set has 160 bluffs among 484 bets (`bluff_frequency`). The range viewer shows
  these numbers on every river board.
- Above 50 the bot bluffs more than that ratio. Below 50 it folds calls that pay and bluffs less.

So Risk 50 **matches the textbook ratio** at the one point where a textbook result applies:
the river, a pot-sized bet, call or fold. It is not a solved or unexploitable strategy. Before
the river the bot bets on fixed 65% and 75% rules; its win chance is against a random hand, not
your range; the river set ignores the earlier betting; the 30% value cut is ours; and nothing is
proved about how often any setting wins.

## 4. The market-making reading

Calling a river bet is like a market maker deciding whether to trade with a customer who may
know more. Three sources make this precise in their own setting; none of their formulas is in
the engine, and this section is a reading, not a theorem.

- **Kyle (F01).** Market makers see only the order flow, cannot tell an insider's orders from
  noise, set the price at the expected value given that flow, and earn zero on average. The
  bettor is the insider: it knows its own hand. Its bluffs are the noise that hides its strong
  bets. The caller is the market maker, and at Risk 50 it is exactly Kyle's risk-neutral pricer.
- **Glosten and Milgrom (F02).** A customer who agrees to trade at your quote may know
  something, so the quote must be the expected value *given that they accepted it*. The review
  does this: it grades your call against the hands the bot would have bet with (`RiverSpot.botHands`,
  built from `riverBettingSet`), not against a random hand. The bluffs are their liquidity
  traders, the trades that make dealing pay. Their market shuts down when there are too many
  insiders; against a bot that never bluffs (Risk 0), no bluff-catching call pays, and folding is
  right. The bot's own calls do not condition on your bet; that is a disclosed gap.
- **Avellaneda and Stoikov (F03).** A dealer with a risk-aversion parameter shifts its
  indifference price away from the risk-neutral one; the shift grows with the parameter and
  disappears at zero. Our loss weight plays that role: at caution 0 the bot calls at pot odds,
  and each step of caution raises the equity it needs. The mechanism differs (exponential
  utility over a running inventory there, a linear penalty on one decision here), so only the
  role of the parameter carries over, not the formula.

## 5. The presets, ranked by distance from the ideal

The named opponents are points on the one slider. Tier is distance from 50.

| Tier | Name | Risk | Internal (caution, bluffPct) | Plays like |
|---|---|---|---|---|
| 1 | Mia | 50 | (0, 33) | Pro: the textbook setting |
| 2 | Dex | 40 | (20, 26) | Solid regular: slightly careful, bluffs a little less |
| 3 | Rook | 25 | (50, 17) | Average player: folds too much, rarely bluffs |
| 4 | Ivy | 0 | (100, 0) | Rock: folds unless clearly ahead, never bluffs |
| 4 | Vex | 100 | (0, 60) | Maniac: bluffs 60% of its river bets |

Why this ladder, from the sources:

- B01 orders decision makers by risk aversion, and `risk_monotone` is our version of that order.
  So below 50 the presets are ordered by caution: Ivy needs a 3/5 win chance against a pot-sized
  bet, Rook 1/2, Dex about 0.41, Mia 1/3 (from `callPays`).
- Above 50 caution is already 0, so Vex calls exactly as Mia does. The only difference is that
  Vex bluffs 60% of its river bets where Mia bluffs 33%. By A03's arithmetic, against a bettor
  whose bets are 60% bluffs, calling a pot-sized bet with a hand that beats every bluff wins
  0.6 × 2 − 0.4 × 1 = 0.8 pots on average, so Vex is exploited by calling it down. That is what
  makes it a maniac rather than a stronger player, and it is why the two extremes tie at tier 4.
- Nothing in A03 or B01 argues for a different table. One wording note for the UI: say that Vex
  and Mia call identically and differ only in bluffing, so that "more Risk" above 50 is not read
  as "calls more".

The names are invented; none is a real player or a chess.com bot.

## 6. What is not proved

The README's "What we trust" section is the list of record. The items that bear on this document:

- The web app, the browser code, Node and the JSON bridge are tested, not proved. The
  conversion of the engine's state to JSON (`engine/Engine/Protocol.lean`) is not proved.
- The buttons the browser offers (`legalOptions`) are not proved equal to the rules (`Legal`);
  the engine rejects illegal moves anyway (T3).
- The preflop table and the flop's 1,000 deals are estimates. Only the turn and river counts are
  exact (T6).
- The shuffle is proved to be a permutation of the 52 cards (T2), not to be random.
- The turn counts run 46 parallel tasks; the compiler is trusted to run them.
- T10 does not apply: there is no separate fast evaluator; the engine uses the spec's `bestScore`.
- Whole games and "the bot playing well": the bot theorems are about one decision at a time.
  Matching the textbook bluff ratio inside a board-only river set is not a proof of good play.
- The market-making reading in section 4 is an explanation, not a theorem.

## Appendix: where each number lives

| Number | Lean function | File | Theorems |
|---|---|---|---|
| Equity needed, equity had | `gradeRiver` | `engine/Engine/Review.lean` | `review_call_best_iff_equity`, `review_worth` |
| Pot-sized river bet | `riverBetOrCheck`, `View.potBetTarget` | `engine/Engine/Slider.lean` | `bot_bets_its_set` |
| Value hands (30%) and bluff count | `valueCount`, `bluffCount`, `riverBettingSet` | `engine/Engine/River.lean` | `bluff_frequency`, `value_and_bluffs_apart`, `value_strongest`, `bluffs_weakest` |
| Loss weight 1 + caution/50 | `callPays` | `engine/Engine/Slider.lean` | `callPays_iff_takes`, `risk_monotone`, `more_risk_takes_fewer_gambles` |
| One slider to two numbers | `Sliders.ofRisk` | `engine/Engine/Slider.lean` | lane 1's `ofRisk_*` theorems |
| Exact counts | `countsFor` | `engine/Engine/Equity.lean` | `enumeration_exact`, `countsFor_river`, `countsFor_turn` |
| Grade bands | `labelFor` | `engine/Engine/Review.lean` | `review_best_iff`, `review_label_monotone` |
| Review's model of the bot's hands | `RiverSpot.botHands`, `riverSpotOf` | `engine/Engine/Review.lean` | `no_hindsight`, `bot_hand_in_review`, `botHands_ne_nil_of_board` |
