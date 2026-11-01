# FoldProof: Hold'em with a proved game review

Design a poker bot's personality, play heads-up Texas Hold'em against it in the browser,
then get a chess.com-style review of your calls and folds. The whole game runs in Lean, and
Lean proofs check the rules, the bot and the river grade. The river grade is proved to follow
its stated rules, and it never looks at the bot's cards. Your other calls and folds get an
"any hand" grade, worked out in Lean but not proved.

## Run it

You need:

- git and curl.
- GNU make and a POSIX shell. On Windows, use Git Bash.
- Node 22.12 or newer, with npm. The test runner (vitest 5) needs 22.12.
- Internet on the first install. It downloads elan, Lean 4.35.0 and the npm packages.

```bash
make install && make run
```

`make install` installs elan if it is missing, builds the Lean engine (which also checks
every proof), and installs the web packages. `make run` builds the web app, starts it at
http://localhost:3000 and opens the browser. The first Lean build took about 2 minutes on
CI's Linux machine; allow a few minutes on a laptop. If port 3000 is busy, run
`make run PORT=3001`.

On Windows without make, with Node and Lean already installed, run this in PowerShell:

```powershell
npm ci
Push-Location engine; lake build; Pop-Location
npm run build
npm start
```

To check the proofs yourself: `checks/audit.sh` builds the engine and fails on any `sorry`
or extra axiom. `lake comparator` and `lake check` (from `engine/`) need Linux.

**Evidence.** Commit `923fdb3` on `main` passed every CI check: the proof audit, Comparator,
`lake check`, and a fresh Linux clone that runs `make install`, `make run`, 492 tests and an
HTTP smoke test
([run 41360657401](https://github.com/DevomB/FoldProof/actions/runs/41360657401)).
It carries 100 Comparator theorems, including the one-street river model and the proof that
the shuffle gives every deck order exactly once.
Other documents link here rather than repeat this line. CI skips commits that change only
docs, so the final commit gets a run started by hand, and this line moves to it.

## What is proved

The theorems name the engine's own functions (`step`, `shuffle`, `botDecide`,
`reviewRiver`), not copies of them. Each statement is in
[`engine/Checks/Challenge.lean`](engine/Checks/Challenge.lean), the file the team agreed
on, and [`engine/comparator.json`](engine/comparator.json) lists them all. CI checks that each
proof proves exactly that statement, with only the three standard axioms.

The review's theorems (T5, T8) cover one grade: your call or fold after the bot opens the
river with a bet (`"model": "river-set"` in the review). Your other calls and folds facing a
bet get an "any hand" grade (`"model": "any-hand"`): every hand the bot could hold counts
the same, and a call is assumed to check down to showdown. It uses the same arithmetic and
labels, but no theorem covers it. Bets, raises and checks are not graded.

| # | In plain words | Lean theorems |
| --- | --- | --- |
| T1 | In every game the engine can reach, there are exactly 1,000 chips. Moves and new deals never create or destroy chips. | `step_keeps_chips`, `startHand_keeps_chips`, `chips_always_1000` |
| T1b | At a showdown the better hand wins the pot and ends with more chips, the other with fewer; a tie leaves both as they were; a fold pays the player who did not fold. Every hand of a reachable game is a real deal to two players with chips. | `showdown_pays_better_hand`, `fold_pays_other_player`, `fold_records_other_player`, `game_hand_from_deal` |
| T2 | The shuffle keeps exactly the 52 cards. In every reachable game, no card is dealt twice. The shuffle method is fair if its picks are: it picks each next card from the cards left, at a place given by the generator's number reduced modulo the cards left; with n different cards there are exactly n! valid pick lists, every order comes from one of them, and each order from exactly one, so if the picks are equally likely every order has the same chance, 1 in n!. The shuffle reads only 64 bits of its seed, and 2^64 is less than 52!; together those two theorems mean most deck orders can never come out. That the generator's numbers are random is not proved; it is a fixed rule so games can be replayed. | `shuffle_same_cards`, `shuffle_fair`, `no_card_dealt_twice`, `shuffle_eq_pickWith`, `pickWith_perm`, `allValidPicks_length`, `mem_allValidPicks`, `allValidPicks_nodup`, `every_order_possible`, `picks_one_to_one`, `each_order_once`, `shuffle_uses_64_bits`, `fewer_seeds_than_orders` |
| T2b | While a hand is played the board has 0, 3, 4 or 5 cards as the street says; a showdown has all five. | `board_matches_street`, `showdown_has_five_cards` |
| T3 | The engine accepts only legal moves. An illegal move is rejected and changes nothing. The player to act is allowed to act. The bot only picks legal moves. A legal move in a hand that is not over is always accepted. The buttons and raise range the engine offers are exactly the legal moves. | `accepted_move_is_legal`, `illegal_move_rejected`, `legal_move_accepted`, `player_to_act_may_act`, `botDecide_legal`, `legalOptions_exact` |
| Risk | One Risk slider (0 to 100) sets the bot's caution (how heavily a lost chip counts) and its bluff share. Risk 0 counts a lost chip three times and has no river bluffs. Risk 50 plays for plain chip profit and bluffs 33% of its river bets ([docs/THEORY.md](docs/THEORY.md) says why that matches the textbook ratio). The share never passes 60%. More Risk never makes the bot more cautious and never makes it bluff less. The Risk quoted in the bot's reason never changes its move. | `ofRisk_caution_antitone`, `ofRisk_bluff_monotone`, `ofRisk_bluff_le_60`, `ideal_is_textbook`, `botDecide_action_shown` |
| T4 | In one spot, more Risk never turns a call or raise into a fold when the bot faces a bet, and never turns a river bet into a check. Before the river, with nothing to call, Risk plays no part. Facing a bet, if the bot does not raise, it calls exactly when the call is worth it, with a lost chip counted (1 + caution/50) times, and it always takes a call that can never lose chips. | `more_risk_never_folds_a_call`, `more_risk_never_checks_a_bet`, `more_bluff_never_checks_a_bet`, `botDecide_no_bet_off_river`, `risk_monotone`, `botDecide_risk_monotone`, `more_risk_takes_fewer_gambles`, `callPays_iff_takes`, `bot_calls_only_when_worth_it`, `bot_folds_only_when_not_worth_it`, `no_loss_always_taken`, `viewOf_toCall_le_pot` |
| T5 | For the river grade (your call or fold after the bot opens the river with a bet): the worths are exact averages over the hands the bot can hold, in big blinds. Best means the choice was worth at least as much as the other one. Losing fewer big blinds never gets a worse label. Calling is Best exactly when your equity is at least the equity needed. The review's list of hands the bot can hold is never empty: not when the bot bets first on the river, and not on any river board. | `review_worth`, `review_lost`, `review_best_iff`, `review_label_monotone`, `review_call_best_iff_equity`, `review_hands_ne_nil`, `botHands_ne_nil_of_board` |
| T6 | On the turn and the river, the bot's win counts look at every possible outcome exactly once: 990 opponent hands on the river, 45,540 (river card, opponent hand) pairs on the turn. | `enumeration_exact`, `riverOpponentHands_length`, `turnOutcomes_length`, `countsFor_river`, `countsFor_turn` |
| T7 | On any river board, at any bluff share from 0% to 60%, the bot's betting set has 324 value hands and the whole number of bluffs that comes nearest to making bluffs that share of the set; at Risk 50 that is 160 bluffs. No hand is both. With no bet to face and a legal bet available, the bot bets on the river exactly the hands in the set. The candidate hands are ranked strongest first: the value hands are the strongest and the bluffs the weakest. | `bluff_frequency`, `value_and_bluffs_apart`, `bot_bets_its_set`, `botDecide_river_follows_set`, `rankRiverHands_sorted`, `value_strongest`, `bluffs_weakest`, `ideal_river_set` |
| T7b | If your hand beats every bluff and loses to every value hand, then against a pot-sized bet calling and folding are worth the same exactly when one bet in three is a bluff (for any bet size: when bluffs × prize = value × cost); more bluffs favour calling, fewer favour folding. The review grades both choices Best exactly then, with the hands your cards block removed. The Risk 50 set is two bluffs short of one third (160 of 162), so before blockers calling loses 1/121 of the bet; no whole bluff percent is exact and 33% is the closest. Before blockers, against the Risk 100 set calling gains 0.8 bets per call and against the Risk 0 set every call loses; for any bet size more bluffs never make the call worth less. This is the caller's half of an equilibrium, one street, call or fold; nothing about earlier betting or whole games. | `bluff_catcher_call_total`, `bluff_catcher_indifferent`, `one_third_bluffs_indifferent`, `more_bluffs_call_better`, `fewer_bluffs_fold_better`, `review_both_best_iff_one_third`, `risk50_two_bluffs_short`, `risk50_bluff_catcher_call_loses`, `no_bluff_setting_is_exact`, `bluff_33_is_closest`, `maniac_bluff_catcher_total`, `rock_bluff_catcher_total`, `more_bluffs_more_call_total` |
| T7c | The bot's side of the one-street river model. The real bot's river bet is pot-sized: when it opens the river with a bet and the pot is a legal size, it bets exactly the pot. A bluff gains the pot for each of your folds and loses the bet for each of your calls, so for any bet size it breaks even exactly when your calls times the bet equal your folds times the pot; for a pot-sized bet, exactly when you call with half of your hands, with more calls making bluffs lose and fewer making them win. Betting a value hand never gains less than checking it. Together with T7b: if your hand beats every bluff and loses to every value hand, neither side can gain by checking instead of betting, or by calling instead of folding, exactly when one bet in three is a bluff and you call half the time. One river decision in that model: nothing is claimed about earlier streets, other bet sizes, or whole games. | `bluff_total`, `bluff_breaks_even_iff`, `half_calls_bluff_breaks_even`, `more_calls_bluff_loses`, `fewer_calls_bluff_wins`, `value_bet_never_worse`, `river_equilibrium_iff`, `bot_river_bet_is_pot_sized` |
| T8 | Two hands that look the same to you get the same river grade, whatever the bot really holds. When the bot bets, its real hand is always one of the hands the river grade counts. | `no_hindsight`, `bot_hand_in_review` |
| T9 | Every hand ends: from any reachable game, a hand has at most 200 accepted moves. | `every_hand_ends` |
| App | The game the app plays is always a reachable game, so T1, T2, T3 and T9 hold for it. A command the engine rejects leaves the game unchanged. While a hand is going, the engine always accepts the bot's move. | `app_game_reachable`, `handle_keeps_reachable`, `handle_error_unchanged`, `respond_keeps_session_unless_accepted`, `bot_move_accepted` |
| Panels | The Risk explorer shows the real bot's move at each Risk from 0 to 100, as a new game at that Risk would set the bot; facing a bet, it never goes from call back to fold as Risk rises. The range viewer's counts add up and are the counts the grade uses. (`exploreHand_moves` and `exploreHand_risk_monotone` cover the explorer's earlier form, which moved caution only.) | `exploreHandAt_moves`, `exploreHandAt_more_risk_continues`, `rangeOf_adds_up`, `rangeOf_counts`, `exploreHand_moves`, `exploreHand_risk_monotone` |

[SPEC.md](SPEC.md) gives each rule in more detail. [docs/PITCH.md](docs/PITCH.md) ties each
claim in the pitch to its theorems and says where each one stops.

## What we trust

A Lean proof shows that the code does what the theorem says. It does not show that the
theorem says the right thing, and it says nothing about code outside the proof. This
section lists everything a reader must still trust.

**How the proofs are checked.** On every push to `main` that changes the engine, the app or
the build files, GitHub runs
[`.github/workflows/lean-proofs.yml`](.github/workflows/lean-proofs.yml) on a fresh Linux
machine:

1. `checks/audit.sh`: builds the engine and fails if any `sorry`, `admit`,
   `native_decide`, `maxHeartbeats 0` or new `axiom` appears, or if a main theorem uses
   an axiom other than the three below.
2. `lake comparator`: checks that each theorem listed in `engine/comparator.json` proves
   exactly the statement in `engine/Checks/Challenge.lean`.
3. `lake check`: Lean's kernel checks the whole engine again.
4. A fresh clone runs `make install`, `make run`, the tests and an HTTP smoke test.

**We trust these tools:**

- **Lean 4.35.0**: its kernel (the part that checks proofs) and its compiler (the part
  that turns the engine into the `poker` program the web app runs).
- **Three standard axioms**: `propext`, `Quot.sound` and `Classical.choice`. Every Lean
  project that uses ordinary logic relies on them. We use no other axiom and no
  `native_decide`.
- **GitHub Actions and bubblewrap**: the Linux machine and sandbox that run the checks.

**We trust these definitions.** A theorem means only what its definitions mean, so a
reader must check that each of these says the right thing. Each one is short and has a
plain-English docstring.

- Rules of the game, in [`engine/Poker/Spec/`](engine/Poker/Spec/): `State.total` (where
  chips can be), `Legal` (which moves are allowed), `State.MayAct` (who may act),
  `fullDeck` and `FairDeck` (what a fair deck is), the hand ranking, and `showdown` with its
  `Outcome` (who wins, or a tie, from two hands and a board). T1b says the engine's result
  is this `showdown`.
- Which hands and games can happen, in
  [`Engine/Proofs/Reachable.lean`](engine/Engine/Proofs/Reachable.lean):
  `Hand.Reachable`, `Game.Reachable`, `Hand.dealtCards`.
- What "a hand ends" means, in
  [`Engine/Proofs/EndsSpec.lean`](engine/Engine/Proofs/EndsSpec.lean): `RunsTo` and
  `RunsWith` (a run of moves the engine accepts).
- How the shuffle picks cards, in
  [`Engine/Proofs/ShuffleSpec.lean`](engine/Engine/Proofs/ShuffleSpec.lean): `pickWith` (build
  a deck by taking the card at each given position from the cards left), `ValidPicks` and
  `allValidPicks` (which position lists are in range, and the list of all of them), `seedPicks`
  (the positions the generator gives from a seed) and `factorial`; with `shuffle`, `nextSeed`
  and `mixSeed` in `Engine/Deck.lean`. T2's fairness theorems are about these.
- How many shared cards each street has, in
  [`Engine/Proofs/BoardSpec.lean`](engine/Engine/Proofs/BoardSpec.lean): `Street.boardCards`
  (0 before the flop, then 3, 4 and 5). T2b compares the board against it.
- What the bot's internal caution means, in
  [`Engine/Proofs/RiskSpec.lean`](engine/Engine/Proofs/RiskSpec.lean): `riskWeight` (a lost
  chip counts 1 + caution/50 times), `Gamble.Takes`, `callGamble`. The spec files call this
  internal number `risk`. The Risk the player sets (0 to 100, higher means more risk-seeking)
  is mapped to it by `Sliders.ofRisk`: caution falls from 100 at Risk 0 to 0 at Risk 50 and
  stays 0 above, while the bluff share rises. See [docs/THEORY.md](docs/THEORY.md).
- What the bot and equity counts must do, in `Engine/Proofs/BotSpec.lean`
  (`AlwaysLegal`, `RiskMonotone`) and `Engine/Proofs/EquitySpec.lean`
  (`OpponentCanHold`, `TurnOutcomePossible`, `timesListed`, `timesListedTurn`,
  `countResults`).
- What Bluff means, in [`Engine/Proofs/BluffSpec.lean`](engine/Engine/Proofs/BluffSpec.lean):
  `NearestWhole` (the nearest whole hand), `RanksAbove` (the order of the river ranking:
  higher score first, then lower card IDs) and `cardId` (a card's place in a new deck).
- What the review must compute, in
  [`Engine/Proofs/ReviewSpec.lean`](engine/Engine/Proofs/ReviewSpec.lean): `callResult`
  (what a call wins against one bot hand), `choiceTotal` and `RiverSpot.total` (what a
  choice wins over all the bot's possible hands), `Frac.LE` (comparing fractions) and
  `SameForHuman` (two hands that look the same to the human).
- What the river game-theory theorems mean, in
  [`Engine/Proofs/BluffCatcherSpec.lean`](engine/Engine/Proofs/BluffCatcherSpec.lean):
  `CatchesBluffs` (your hand loses to every value hand and beats every bluff, with no ties),
  `RiverSpot.valueHands` and `RiverSpot.bluffHands` (the bot's value hands and bluffs that your
  cards do not block; together they are the review's `botHands`, by
  `botHands_eq_value_append_bluffs`); and in
  [`Engine/Proofs/EquilibriumSpec.lean`](engine/Engine/Proofs/EquilibriumSpec.lean):
  `bluffGain` and `bluffTotal` (what betting a bluff gains over checking, for one answer of
  yours and over all of them), `valueGain` and `valueTotal` (the same for a value hand),
  `callCount` (how many of your answers are calls) and `RiverEquilibrium` (calling and folding
  are worth the same to you; a bluff gains nothing over checking; a value bet gains at least as
  much as checking). They build on `callResult` and `choiceTotal` above. T7b and T7c are about
  these.

The engine code itself (`step`, `startHand`, `shuffle`, the bot, the review) is what the
theorems are about, so it does not have to be trusted for what they prove. But some
theorem statements name engine definitions directly. A reader must check that these say
the right thing too:

- `HandEnd` (`Engine/Hand.lean`: `.folded w` names the winner of a fold, `.showdown r` the
  showdown's result) and the hand's `ended`, `hole`, `board`, `street` and `chips.stack`
  fields. T1b and T2b read these.
- `Game.Reachable` is built from `newGame`, `Game.act` and `Game.nextHand`, and
  `Hand.Reachable` from `startHand` and `step`. T1-T3, T1b, T2b and T9 hold for the games
  these build (T1b and T2b through `game_hand_from_deal`).
- `riverBettingSet`, `rankRiverHands`, `riverRole` and `riverBets` (`Engine/River.lean`):
  the set T7 counts, the ranking it is cut from, and the bot's river choice. The review's
  range is built from the same set.
- `RiverSpot.botHands` (the review's range: the betting set minus the hands that use
  the human's cards), `RiverSpot.prize` and `RiverSpot.cost` (the chips a call can win
  and costs) appear in `RiverSpot.total`, so they fix what T5's worths mean.
- `riverSpotOf` is what the review sees of a hand (T8 `no_hindsight`).
- `labelFor` sets the label bands (Good under 0.5 BB, Inaccuracy under 2, Mistake under
  5, then Blunder). The bands are the team's choice: no poker tool publishes cutoffs. T5
  proves that Best means nothing lost and that labels only get worse as more is lost; the
  band edges themselves are only in `labelFor`.
- `viewOf` (`Engine/Slider.lean`): the bot's view of the table. `Action.continues`: the
  move is a call or a raise. T4 uses both, and `Sliders.ofRisk` (above).
- The app layer, in `Engine/Session.lean` and `Engine/Protocol.lean`: `Session.handle`
  (what each command does), `respond` (one request line in, one reply out),
  `parseRequest`, `parsePeek` and `stateJson`. The "App" row above is about these.
- The panels, in `Engine/Explain.lean`: `exploreHandAt` (the Risk explorer the app shows),
  `exploreHand` (its earlier form) and `rangeOf` (the range viewer).

One proof helper is built by a small Lean command instead of written by hand:
`#make_dealFrom` in `Engine/Proofs/Chips.lean` makes `dealFrom` (the body of `dealHand`,
with the shuffled deck as an input) and the fact `dealHand_eq_dealFrom`. Lean's kernel
checks both, and no main theorem's statement mentions them. It exists because Lean would
otherwise try to run the 52-card shuffle on an unknown seed inside a proof.

**We trust this data, without proof:**

- **The preflop table**, [`data/preflop.json`](data/preflop.json): win, tie and loss
  counts for each starting hand, estimated from 50,000 random deals per hand with seed
  20261031. Rebuild it with the command stored in the file
  (`npx --yes tsx@4.20.6 scripts/gen-preflop.ts`). These are estimates, not exact counts.
- **Flop counts** are estimated from 1,000 seeded random deals. Turn and river counts are
  exact (T6).

**Not covered by any proof:**

- **The web app**: the Next.js pages, the browser code, Node, and the bridge that passes
  JSON between the browser and the Lean `poker` program (`src/lean/`,
  `src/app/api/game/`). If the bridge sent a different move than the player clicked, no
  theorem would catch it. The engine still rejects any illegal move it receives (T3).
- **The JSON text**: that `stateJson` and the review reply show the right numbers, and
  that `parseRequest` reads requests correctly, is tested, not proved. What is proved is
  how `respond` changes the game (the "App" row). `engine/Main.lean` only reads and writes
  the lines.
- **Recorded review inputs**: the Risk explorer is proved equal to the bot on the inputs
  the session recorded. That the session records the right inputs, and the right river
  spot for the review, is tested, not proved.
- **`Task.spawn` in `turnCounts`**: the turn counts run 46 tasks in parallel. The proofs
  treat a task as the plain function it runs; the compiler is trusted to run them
  correctly.
- **Whole games**: the bot theorems are about one decision at a time. They do not say
  how often a bot wins. The river grade's model ignores the earlier betting.
- **The "any hand" grades**: calls and folds other than the answer to the bot's opening
  river bet. They are new and no theorem covers them. The app marks them as not proved.

**Functions without a body (`opaque`)**: none.

## Where things are

| Path | What it holds |
| --- | --- |
| `engine/Poker/Spec/` | The rules, written by people: cards, deck, legal moves, hand ranking. |
| `engine/Engine/` | The game the app runs: shuffle, betting, bot, equity counts, river set, review, session and JSON protocol. |
| `engine/Engine/Proofs/` | The proofs, and the `*Spec.lean` definitions they rely on. |
| `engine/Checks/` | `Challenge.lean` (the agreed statements) and `Solution.lean` (the proofs Comparator checks). |
| `src/` | The Next.js app: `app/api/game/` (the server route), `lean/` (the bridge to the `poker` program), `components/`, `hooks/`, `lib/`. |
| `checks/` | `audit.sh` (the proof audit) and `http-smoke.mjs` (the HTTP smoke test). |
| `data/preflop.json` | The preflop table (estimates). |
| `docs/` | [PITCH.md](docs/PITCH.md) (the pitch and its claim table), [DEMO.md](docs/DEMO.md) (the demo hands and checks), [THEORY.md](docs/THEORY.md) (the formulas behind the slider and the review, with sources), [research/](docs/research/) (background research). |
| `tests/diff/` | Differential tests and recorded results. |

## More

- [SPEC.md](SPEC.md): what "correct" means, in plain words, for each theorem.
- [docs/THEORY.md](docs/THEORY.md): each number the bot and the review use, where Lean
  computes it, and the source behind it.
- [MVP.txt](MVP.txt): the original plan and rule decisions. Sections 3-6 still define how
  the game and the bot behave.
- [RULES.md](RULES.md): the hackathon's judging criteria.
- [CLAUDE.md](CLAUDE.md): the organizers' rules for Lean verification.
- [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md): how the team worked in parallel.
