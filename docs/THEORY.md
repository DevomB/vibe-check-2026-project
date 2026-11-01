# The theory behind the slider and the review

This document explains, for every number the bot and the review use, the formula, where
the Lean engine computes it, the source that supports it, and the exact conditions under
which that source applies. It is written to be checked: each section names one Lean
function and one or more sources from [the research index](research/INDEX.md). Line numbers
refer to the engine as committed at `64b2e3d` on `sunday/one-slider`.

Two rules for reading it. First, a Lean theorem says only what its statement says, and the
README's "What we trust" section lists what a reader must still check. Second, nothing here
claims that the bot plays well. The README lists "the bot playing well" as not proved, and
the one-slider work does not change that. Where a setting agrees with a textbook result we say
"matches the textbook ratio", never "optimal" or "GTO".

## 1. One slider, two internal numbers

The player sees one slider, **Risk, 0 to 100**, meaning appetite for risk. The engine keeps its
two internal numbers unchanged: `caution` (today's code calls it `risk`), which says how heavily
a lost chip counts, and `bluffPct`, the share of bluffs in the bot's river betting set. The map
is `Sliders.ofRisk` in `engine/Engine/Slider.lean` (line 39):

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
| 0 | 100 | 0 | Ivy, exactly |
| 25 | 50 | 17 | (new) |
| 40 | 20 | 26 | (new) |
| 50 | 0 | 33 | (new: the old Mia was internal caution 50 with 33%) |
| 75 | 0 | 47 | (new) |
| 100 | 0 | 60 | Vex, exactly, and the practice challenges' bot |

Every proved theorem is stated over an arbitrary `Sliders` value, so all of them keep holding
for every value `ofRisk` can produce. The theorems about the map itself are in section 1.1.

### 1.1 The eleven theorems of the one-slider change, in plain words

All eleven are registered in `engine/Checks/Challenge.lean` and `engine/comparator.json`
(60 names in all, with the three merged from `sunday/review-fixes`), so Comparator checks
each statement. Seven are in `engine/Engine/Proofs/OneSlider.lean`, three in
`engine/Engine/Proofs/Explain.lean`, one in `engine/Engine/Proofs/OneSliderRiver.lean`.

- `botDecide_action_shown` (OneSlider.lean, line 43). The extra Risk number the bot is handed
  to print in its reasons (`shownRisk`) never changes the move.
- `ofRisk_bluff_le_60` (line 51). At every Risk the bluff share is at most 60, so
  `bluff_frequency` (T7) applies at every Risk.
- `ofRisk_bluff_monotone` (line 56). More Risk never bluffs less.
- `ofRisk_caution_antitone` (line 62). More Risk never weighs a lost chip more: caution falls
  or stays.
- `more_risk_never_folds_a_call` (line 86). Facing a bet in one spot (the same seed, cards,
  board and chips), if the bot calls or raises at Risk r, it also calls or raises at every
  higher Risk. It holds because, facing a bet, the bot reads only caution and never the bluff
  share (`botDecide_facing_bet_bluff`, line 78), and caution falls with Risk.
- `more_risk_never_checks_a_bet` (OneSliderRiver.lean, line 38). The river half of the same
  fact. On a river board with no card twice, with nothing to call and a bet allowed, if the bot
  bets its two cards at Risk r, it bets them at every higher Risk r'. The value hands are the
  same at every Risk, and the bluffs, the last `bluffCount 324 b` ranked hands, only grow as the
  bluff share rises through 0 to 60 (`bluffCount_step`, checked by `decide` over the 60 steps,
  and `bluffCount_mono_60`, in the same file).
- `ideal_is_textbook` (OneSlider.lean, line 104). Risk 50 maps to caution 0 and bluff share 33.
- `ideal_river_set` (line 109). At Risk 50, on every river board with no card twice, the
  betting set has 324 value hands and 160 bluffs.
- `botDecide_no_bet_off_river` (Explain.lean, line 100). With no bet to face before the river,
  the bot reads neither setting: any two settings give the same move. So before the river,
  Risk changes the bot's play only when it faces a bet.
- `exploreHandAt_moves` (Explain.lean, line 157). The Risk explorer's move at Risk r is exactly
  what `botDecide` returns with the settings a new game at Risk r would use (`Sliders.ofRisk r`)
  and the move's recorded seed, cards, board and chips. This covers river moves too, where the
  bluff share changes with Risk.
- `exploreHandAt_more_risk_continues` (line 166). For a recorded move that faced a bet, if the
  explorer shows a call or raise at Risk r, it shows one at every higher Risk up to 100. The
  "up to 100" is a hypothesis because past 100 the explorer has no entry.

Together, `more_risk_never_folds_a_call` (facing a bet), `more_risk_never_checks_a_bet` (the
river with no bet to face) and `botDecide_no_bet_off_river` (no bet to face before the river)
cover every place the slider acts: more Risk never makes the bot fold a call or check a bet,
and before the river with nothing to face, Risk plays no part.

None of the eleven says the bot plays well. They say what the map does, what the bot does at
one decision, and that the explorer shows the real bot.

## 2. The formulas, where they live, and what supports them

### 2.1 Pot odds: the equity a call needs

**Formula.** A call that pays `cost` chips to win `prize` chips breaks even when the share of
the bot's hands you beat (ties counting half) is at least `cost / (prize + cost)`.

**Where.** `gradeRiver` in `engine/Engine/Review.lean` (line 146) sets `equityNeeded` to
`cost / (prize + cost)` and `equityHad` to `(2 × wins + ties) / (2 × hands)` (lines 157 and
158). `RiverSpot.prize` (line 107) and `RiverSpot.cost` (line 103) take back any part of the
bet you cannot match.

**Source.** A03 records the caller's required equity as S / (P + 2S) for a bet S into a pot P;
the note works it out itself as standard pot-odds arithmetic. With prize = P + S and cost = S,
`cost / (prize + cost)` is the same number. This is plain arithmetic, not a model result, so it
holds without extra conditions. F02 (Glosten and Milgrom)
is the reason the review measures that equity against the hands the bot would bet with, not a
random hand: the bet itself is information, and a zero-profit pricer conditions on it.

**Theorems.** `review_call_best_iff_equity`: calling is graded Best exactly when `equityHad` is
at least `equityNeeded`. `review_worth` and `review_lost` tie the worths and the loss to the
chips really at stake.

### 2.2 The bluff ratio: why 33% is the textbook setting

**Formula.** The bot's river bet is pot-sized, and for a pot-sized bet the break-even share of
bluffs in the bettor's range is bet / (pot + 2 × bet) = 1/3. In general it is s / (1 + 2s) with
s = bet / pot.

**Where.** `riverBetOrCheck` (line 178) with `View.potBetTarget` (line 165) in
`engine/Engine/Slider.lean` makes the river bet pot-sized (cut down to the legal range when
needed); this sizing is code with no theorem about it. In `engine/Engine/River.lean`, `valueCount` (line 70) takes the top `valuePct` = 30%
(line 22) of the 1,081 candidate hands, rounded down, so 324 value hands; `bluffCount values b`
(line 75) adds `values × b / (100 − b)` bluffs, rounded to the nearest whole hand with halves
up; `riverBettingSet` (line 81) puts the two together. At b = 33 that is 324 × 33 / 67 = 159.6, so 160 bluffs, and bluffs are
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
share), `value_and_bluffs_apart`, `bot_bets_its_set`, `botDecide_river_follows_set`, and
`value_strongest` and `bluffs_weakest` (value hands are the strongest candidates, bluffs the
weakest; registered on this branch from `sunday/review-fixes`).

### 2.3 Minimum defence frequency

**Formula.** Against a bet S into a pot P, the caller must continue with share P / (P + S) of
its hands for a pure bluff to break even. For a pot-sized bet that is 1/2.

**Where.** Nowhere. We checked `engine/` on 2026-11-01: the engine does not compute this number.
The review grades each call by pot odds against the bot's actual set (2.1), not by how often you
defend.

**Source.** A03 works it out next to the bluff share, in a simpler model than von Neumann's:
a bluff never wins at showdown and giving up scores 0. A03 marks it as "not exactly von
Neumann's model".

### 2.4 The loss weight: what caution means

**Formula.** Each lost chip counts (1 + caution / 50) times a won chip. In whole numbers,
`callPays` in `engine/Engine/Slider.lean` (line 98) calls when

```
100 × (2 × win × pot + tie × (pot − toCall)) ≥ 2 × (100 + 2 × caution) × loss × toCall
```

where win, tie and loss are the counts of the bot's possible outcomes. At caution 0 this is
plain chip profit. Against a pot-sized bet the bot needs a 1/3 win chance at caution 0, 1/2 at
50 and 3/5 at 100. The examples at lines 103 to 106 check caution 0 and 50; caution 100
follows from the formula, which with no ties needs a win share of at least
(100 + 2 × caution) / (300 + 2 × caution).

**Source.** B01 (Pratt 1964): a more risk-averse decision maker turns down every risky-or-sure
choice that a less risk-averse one turns down. Our loss weight is the row "loss penalty relative
to current stack" in B01's table: it is a penalty on one decision, not a fixed utility over final
chips, which we disclose here. F03 (Avellaneda and Stoikov) is the market-making reading
of the same dial, see section 4.

**Theorems.** `more_risk_takes_fewer_gambles` (for any gamble, if a more cautious bot takes it a
less cautious one does), `risk_monotone` and `botDecide_risk_monotone` (at one decision, if the
bot calls or raises at some caution it does so at every lower caution), `callPays_iff_takes`,
`bot_calls_only_when_worth_it`, `bot_folds_only_when_not_worth_it`, `no_loss_always_taken`.
These compare one decision at a time; they say nothing about whole games. For the user's slider
the direction flips: more Risk never folds a call the bot would have called at less Risk. That
is `more_risk_never_folds_a_call`, and on the river `more_risk_never_checks_a_bet` (section 1.1).

### 2.5 Exact equity

**Formula.** The bot's win chance is a count, never a decimal: on the river, how many of the 990
possible opponent hands it beats, ties and loses to; on the turn, the same over all 45,540
(river card, opponent hand) pairs. Every hand is scored with the spec's `bestScore` and counted
by the spec's `showdown` rule.

**Where.** `countsFor` in `engine/Engine/Equity.lean` (line 175), with `riverCounts` (line 79)
and `turnCounts` (line 112). The flop uses 1,000 seeded deals and the preflop uses a stored
table; those two are estimates, listed as trusted data in the README.

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

**Where.** `labelFor` in `engine/Engine/Review.lean` (line 132); MVP section 6.

**Source.** None sets these numbers. **The bands are our own choice.** E01 (Chess.com) shows
the convention of labelling a move by what it lost against the best move, with fixed bands and
an unpublished formula; E02 (Lichess) publishes its formula; E05 (GTO Wizard) reports EV lost
per action in big blinds and colours it by band without publishing thresholds. We publish ours.

**Theorems.** `review_best_iff` (Best exactly when nothing was lost), `review_label_monotone`
(fewer big blinds lost never gets a worse label). The band edges themselves are only in
`labelFor`; a reader must check them there.

## 3. Why Risk 50 is the "ideal", and the exact limit of that claim

At Risk 50 the internal pair is (caution 0, bluffPct 33).

- Caution 0 means the bot calls exactly when the call does not lose chips on average: chip
  profit at least zero, so break-even calls are taken (`callPays_iff_takes`,
  `bot_calls_only_when_worth_it`, `bot_folds_only_when_not_worth_it`). That is the risk-neutral
  rule, and it is the rule the market makers in F01 and F02 use.
- Its river bet is pot-sized, and A03's break-even bluff share for a pot-sized bet is 1/3. With
  bluffPct 33 the set has 160 bluffs among 484 bets (`bluff_frequency`; `ideal_river_set`
  states it for Risk 50 directly). The range viewer shows these numbers on every river board.
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
  bets. The caller is the market maker; at Risk 50 it is risk neutral, like Kyle's market makers,
  though unlike them it does not condition on the bet (next bullet).
- **Glosten and Milgrom (F02).** A customer who agrees to trade at your quote may know
  something, so the quote must be the expected value *given that they accepted it*. The review
  does this: it grades your call against the hands the bot would have bet with
  (`RiverSpot.botHands`, Review.lean line 119, built from `riverBettingSet`), not against a
  random hand. The bluffs are their liquidity
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

The names are invented; none is a real player, and none is named after any chess.com bot we
found.

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

| Number | Lean function | File and line | Theorems |
|---|---|---|---|
| One slider to two numbers | `Sliders.ofRisk` | `engine/Engine/Slider.lean` 39 | `ofRisk_bluff_le_60`, `ofRisk_bluff_monotone`, `ofRisk_caution_antitone`, `ideal_is_textbook` |
| Loss weight 1 + caution/50 | `callPays` | `engine/Engine/Slider.lean` 98 | `callPays_iff_takes`, `risk_monotone`, `more_risk_takes_fewer_gambles`, `more_risk_never_folds_a_call` |
| Pot-sized river bet | `View.potBetTarget`, `riverBetOrCheck` | `engine/Engine/Slider.lean` 165, 178 | none about the size: `bot_bets_its_set` says which hands bet; the pot sizing (`clampTo v.potBetTarget`) is code with no theorem |
| The bot's move | `decideView`, `botDecide` | `engine/Engine/Slider.lean` 195, 230 | `botDecide_legal`, `botDecide_risk_monotone`, `botDecide_action_shown`, `botDecide_no_bet_off_river`, `more_risk_never_folds_a_call`, `more_risk_never_checks_a_bet` |
| Value hands (30%) and bluff count | `valuePct`, `valueCount`, `bluffCount`, `riverBettingSet` | `engine/Engine/River.lean` 22, 70, 75, 81 | `bluff_frequency`, `value_and_bluffs_apart`, `value_strongest`, `bluffs_weakest`, `ideal_river_set` |
| Exact counts | `riverCounts`, `turnCounts`, `countsFor` | `engine/Engine/Equity.lean` 79, 112, 175 | `enumeration_exact`, `countsFor_river`, `countsFor_turn` |
| Review's model of the bot's hands | `riverSpotOf`, `RiverSpot.cost`, `RiverSpot.prize`, `RiverSpot.botHands` | `engine/Engine/Review.lean` 96, 103, 107, 119 | `no_hindsight`, `bot_hand_in_review`, `botHands_ne_nil_of_board` |
| Grade bands | `labelFor` | `engine/Engine/Review.lean` 132 | `review_best_iff`, `review_label_monotone` |
| Equity needed, equity had | `gradeRiver` | `engine/Engine/Review.lean` 146 (fields at 157 and 158) | `review_call_best_iff_equity`, `review_worth` |
| Range viewer | `rangeOf` | `engine/Engine/Explain.lean` 46 | `rangeOf_adds_up`, `rangeOf_counts` |
| Risk explorer | `exploreHandAt` | `engine/Engine/Explain.lean` 296 | `exploreHandAt_moves`, `exploreHandAt_more_risk_continues` |
