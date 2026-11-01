# What is proved, and what is not

Sun Nov 1, 2026, main at 3e01c5b. Every theorem named here is stated in
[`engine/Checks/Challenge.lean`](../engine/Checks/Challenge.lean), proved under
`engine/Engine/Proofs/`, listed in [`engine/comparator.json`](../engine/comparator.json) (100
names since the bluff-catcher, equilibrium, Risk 0 and 100, and shuffle-fairness theorems were added; see [GUARANTEES.md](GUARANTEES.md) for the full
table), and checked on every push to main by `checks/audit.sh`, `lake comparator` and
`lake check`, using only the three standard axioms. The README's "What we trust" section lists
the definitions a reader must still read. Most important first.

## Proved

1. **The game is correct.** Chips are never created or destroyed (`step_keeps_chips`,
   `startHand_keeps_chips`, `chips_always_1000`). No card is dealt twice (`shuffle_same_cards`,
   `shuffle_fair`, `no_card_dealt_twice`). Only legal moves are accepted and illegal ones are
   rejected (`accepted_move_is_legal`, `illegal_move_rejected`), and whoever is to act can
   always act (`player_to_act_may_act`). Every hand ends within 200 moves (`every_hand_ends`).
   The right player wins the pot: at a showdown the better hand ends with more chips and the
   other with fewer, a tie leaves both where they were, and a fold pays the player who did not
   fold (`showdown_pays_better_hand`, `fold_pays_other_player`, `fold_records_other_player`).
   Every hand the app plays is a real deal to two players who both have chips
   (`game_hand_from_deal`). The board has 0, 3, 4 or 5 cards as the street says, and a
   showdown has all five (`board_matches_street`, `showdown_has_five_cards`). A legal move in a
   hand that is not over is always accepted (`legal_move_accepted`), and the buttons the engine
   offers are exactly the legal moves, with the right call amount and raise range
   (`legalOptions_exact`).

2. **The river grade is honest.** This is the grade of your call or fold after the bot opens
   the river with a bet. It is exact pot-odds arithmetic against the hands the
   bot would really bet with (`review_worth`, `review_lost`). A call is Best exactly when your
   equity meets the price (`review_best_iff`, `review_call_best_iff_equity`). Fewer blinds lost
   never earns a worse label (`review_label_monotone`). The grade uses no hindsight
   (`no_hindsight`), the bot's real hand is always among the hands it considers
   (`bot_hand_in_review`), and that list is never empty (`review_hands_ne_nil`,
   `botHands_ne_nil_of_board`).

3. **The bot follows its own rules.** Its move is always legal (`botDecide_legal`). When it
   reaches its call/fold rule (a hand with a 75% win chance or more and a legal raise raises
   first), it calls exactly when the call pays at its caution (`callPays_iff_takes`,
   `bot_calls_only_when_worth_it`, `bot_folds_only_when_not_worth_it`); those theorems assume
   the call is at most the pot, which `viewOf_toCall_le_pot` proves for every view the bot
   gets. A call that cannot lose chips is always taken (`no_loss_always_taken`). More caution never means more calls
   (`more_risk_takes_fewer_gambles`, `risk_monotone`, `botDecide_risk_monotone`). On the river
   it bets exactly its value hands and its chosen bluffs (`bot_bets_its_set`,
   `botDecide_river_follows_set`), with the set ranked strongest first
   (`rankRiverHands_sorted`, `value_strongest`, `bluffs_weakest`).

4. **The numbers are exact.** The turn and river equity counts look at every possible outcome
   exactly once (`enumeration_exact`, `riverOpponentHands_length`, `turnOutcomes_length`,
   `countsFor_river`, `countsFor_turn`). The bluff count is the whole number nearest to the
   requested share (`bluff_frequency`), and value and bluff hands never overlap
   (`value_and_bluffs_apart`).

5. **The one slider does what it says.** The bluff share never exceeds 60
   (`ofRisk_bluff_le_60`). More Risk never bluffs less or weighs losses more
   (`ofRisk_bluff_monotone`, `ofRisk_caution_antitone`). Facing a bet, more Risk never turns a
   call into a fold (`more_risk_never_folds_a_call`) or a river bet into a check
   (`more_bluff_never_checks_a_bet`, `more_risk_never_checks_a_bet`), and before the river with
   no bet to face Risk plays no part (`botDecide_no_bet_off_river`). Risk 50 is caution 0 with
   a 33% bluff share (`ideal_is_textbook`): 324 value hands and 160 bluffs, the textbook
   break-even ratio for a pot-sized bet (`ideal_river_set`). The Risk number quoted in the
   bot's reasons never changes its move (`botDecide_action_shown`).

6. **The app cannot corrupt the game.** The engine always accepts the bot's move
   (`bot_move_accepted`); every accepted command keeps the game reachable
   (`handle_keeps_reachable`, `app_game_reachable`); a rejected request changes nothing
   (`handle_error_unchanged`, `respond_keeps_session_unless_accepted`); the bot's call is never
   more than the pot (`viewOf_toCall_le_pot`). The Risk explorer shows the real bot's move at
   every Risk and, facing a bet, never goes from call to fold as Risk rises (`exploreHandAt_moves`,
   `exploreHandAt_more_risk_continues`; the caution sweep: `exploreHand_moves`,
   `exploreHand_risk_monotone`). The range viewer's numbers add up and are the review's own
   counts (`rangeOf_adds_up`, `rangeOf_counts`).

7. **The bluff catcher (game theory, part 1).** Say your hand beats every bluff and loses to
   every value hand. Against a pot-sized bet, calling and folding are worth the same exactly
   when one bet in three is a bluff (`one_third_bluffs_indifferent`; any bet size:
   `bluff_catcher_indifferent`). With more bluffs calling is better, with fewer folding is
   (`more_bluffs_call_better`, `fewer_bluffs_fold_better`). The review grades both choices Best
   exactly then (`review_both_best_iff_one_third`). The real Risk 50 set is two bluffs short of
   one third, 160 against 162 (`risk50_two_bluffs_short`), so before your cards remove any
   hands, calling loses 1/121 of the bet (`risk50_bluff_catcher_call_loses`). No whole Bluff
   percent hits one third, and 33 is the closest (`no_bluff_setting_is_exact`,
   `bluff_33_is_closest`). The other presets, before your cards remove any hands: against the
   Risk 100 set a bluff catcher's pot-sized call gains 0.8 bets per call over its 810 hands
   (`maniac_bluff_catcher_total`); against the Risk 0 set every call loses the bet
   (`rock_bluff_catcher_total`); and for any bet size, more bluffs never lower a bluff
   catcher's call total (`more_bluffs_more_call_total`). This is half of an equilibrium: your
   side, not the bot's.

8. **The bot's side, and the river equilibrium (game theory, part 2).** The bot's river bet is
   pot-sized whenever the pot is a legal size (`bot_river_bet_is_pot_sized`). A pot-sized bluff
   gains nothing over checking exactly when you call with half of your hands
   (`half_calls_bluff_breaks_even`; any bet size: `bluff_breaks_even_iff`); call more and bluffs
   lose, call less and they win (`more_calls_bluff_loses`, `fewer_calls_bluff_wins`). Betting
   a value hand is never worse than checking it (`value_bet_never_worse`). Together:
   with a bluff catcher, neither side can gain by checking instead of betting, or by calling instead of folding, exactly when one
   bet in three is a bluff and you call half the time (`river_equilibrium_iff`). Risk 50 is
   two bluffs short of that (item 7), so the real bot is near this equilibrium, not on it.

9. **The shuffle method is fair if its picks are (randomness, part 1).** The real shuffle picks each next card
   from the cards that are left, using a number from a seeded generator
   (`shuffle_eq_pickWith`), and only ever makes an order of the same cards (`pickWith_perm`).
   With `n` different cards there are exactly `n!` valid pick lists (`allValidPicks_length`,
   `mem_allValidPicks`, `allValidPicks_nodup`). Every order of the cards comes from some pick
   list (`every_order_possible`), and different pick lists make different orders
   (`picks_one_to_one`). So each order comes from exactly one of the `n!` pick lists
   (`each_order_once`): if the picks are fair, every order of the deck has the same chance,
   1 in `n!`. The proof also shows a limit: the shuffle reads only 64 bits of its seed
   (`shuffle_uses_64_bits`) and 2^64 is less than 52! (`fewer_seeds_than_orders`); put
   together, most of the 52! deck orders can never come out (a consequence of the two, not a
   separate theorem).

## Not proved, most important first

1. **That the bot plays well.** No theorem about winning or exploitability over whole
   games. The river equilibrium is proved for one decision in a simple model (items 7 and 8):
   bluffs always lose, value hands always win, and the earlier betting is ignored. It
   would need a best-response computation over the whole game. The bot is a fixed-rule bot;
   Risk 50 matches the textbook bluff ratio inside its own river set, which is not a claim of
   optimal play. See [THEORY.md](THEORY.md), sections 3 and 6.

2. **The web side.** The browser, the Node bridge and the JSON layer (`Protocol.lean`'s
   serialisation) are tested, not proved. The engine's own list of legal moves is proved
   exact (`legalOptions_exact`, item 1); what the browser does with it is not.

3. **The estimates.** Preflop equity comes from a stored table and flop equity from 1,000
   seeded deals. Only the turn and river counts are exact.

4. **Randomness.** The shuffle method is proved fair (item 9): fair picks give every deck order
   the same chance. What is not proved is that the picks are fair. They come from a fixed rule
   (SplitMix64) on purpose, so a game can be replayed; "random" is not something a fixed rule
   can be proved to be. Two smaller gaps: each pick is the generator's 64-bit number modulo
   the cards left, which favours some places by at most one part in 2^64 / 52 (not proved),
   and with only 2^64 seeds most deck orders never come out (proved, item 9).

5. **The "any hand" grades.** Since Nov 1 the review also grades your other calls and folds
   facing a bet, before the river or after a river raise. It counts every hand the bot could
   hold the same and assumes a call checks down to showdown. It uses the river grade's
   arithmetic and labels, but no theorem covers it, and the app marks it as not proved.

6. **The river set ignores earlier streets.** The river grade is exact for that model,
   not a claim about full-hand strategy. A provable upgrade later: make the set depend on the
   betting so far, then reprove `bluff_frequency`, `bot_bets_its_set` and
   `botDecide_river_follows_set`.

7. **Small gaps.** The text of the bot's reasons is not proved faithful to the decision (only
   that the quoted Risk does not change the move). The river bluff reason still quotes the
   internal share. Session state beyond the game, such as the hand logs, has no theorems. The
   turn counts run 46 parallel tasks; the compiler is trusted to run them. The real-board
   examples for items 7 and 8 (a bluff catcher on a concrete board against the real Risk 0, 50
   and 100 sets) are compiled `#guard` checks, not kernel `example`s: the hand ranking uses
   well-founded recursion, so `decide` over 484 to 810 hands does not run in the kernel.
