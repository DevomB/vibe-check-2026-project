# What is proved, and what is not

Sun Nov 1, 2026, main at c2f4034. Every theorem named here is stated in
[`engine/Checks/Challenge.lean`](../engine/Checks/Challenge.lean), proved under
`engine/Engine/Proofs/`, listed in [`engine/comparator.json`](../engine/comparator.json) (61
names), and checked on every push to main by `checks/audit.sh`, `lake comparator` and
`lake check`, using only the three standard axioms. The README's "What we trust" section lists
the definitions a reader must still read. Most important first.

## Proved

1. **The game is correct.** Chips are never created or destroyed (`step_keeps_chips`,
   `startHand_keeps_chips`, `chips_always_1000`). No card is dealt twice (`shuffle_same_cards`,
   `shuffle_fair`, `no_card_dealt_twice`). Only legal moves are accepted and illegal ones are
   rejected (`accepted_move_is_legal`, `illegal_move_rejected`), and whoever is to act can
   always act (`player_to_act_may_act`). Every hand ends within 200 moves (`every_hand_ends`).

2. **The review is honest.** Each grade is exact pot-odds arithmetic against the hands the
   bot would really bet with (`review_worth`, `review_lost`). A call is Best exactly when your
   equity meets the price (`review_best_iff`, `review_call_best_iff_equity`). Fewer blinds lost
   never earns a worse label (`review_label_monotone`). The grade uses no hindsight
   (`no_hindsight`), the bot's real hand is always among the hands it considers
   (`bot_hand_in_review`), and that list is never empty (`review_hands_ne_nil`,
   `botHands_ne_nil_of_board`).

3. **The bot follows its own rules.** Its move is always legal (`botDecide_legal`). It calls
   exactly when the call pays at its caution (`callPays_iff_takes`,
   `bot_calls_only_when_worth_it`, `bot_folds_only_when_not_worth_it`), and a call that cannot
   lose chips is always taken (`no_loss_always_taken`). More caution never means more calls
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
   (`ofRisk_bluff_monotone`, `ofRisk_caution_antitone`). More Risk never turns a call into a
   fold (`more_risk_never_folds_a_call`) or a river bet into a check
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
   every Risk and never goes from call to fold as Risk rises (`exploreHandAt_moves`,
   `exploreHandAt_more_risk_continues`; the caution sweep: `exploreHand_moves`,
   `exploreHand_risk_monotone`). The range viewer's numbers add up and are the review's own
   counts (`rangeOf_adds_up`, `rangeOf_counts`).

## Not proved, most important first

1. **That the bot plays well.** No theorem about winning, exploitability or equilibrium. It
   would need a best-response computation over the whole game. The bot is a fixed-rule bot;
   Risk 50 matches the textbook bluff ratio inside its own river set, which is not a claim of
   optimal play. See [THEORY.md](THEORY.md), sections 3 and 6.

2. **The web side.** The browser, the Node bridge and the JSON layer (`Protocol.lean`'s
   serialisation) are tested, not proved. The buttons the UI offers (`legalOptions`) are not
   proved equal to the rules (`Legal`); the engine rejects illegal moves anyway (T3).

3. **The estimates.** Preflop equity comes from a stored table and flop equity from 1,000
   seeded deals. Only the turn and river counts are exact.

4. **Randomness.** The shuffle is proved to be a permutation of the 52 cards, not to be random
   or evenly distributed.

5. **The river set ignores earlier streets.** The review's grades are exact for that model,
   not a claim about full-hand strategy. A provable upgrade later: make the set depend on the
   betting so far, then reprove `bluff_frequency`, `bot_bets_its_set` and
   `botDecide_river_follows_set`.

6. **Small gaps.** The text of the bot's reasons is not proved faithful to the decision (only
   that the quoted Risk does not change the move). The river bluff reason still quotes the
   internal share. Session state beyond the game, such as the hand logs, has no theorems. The
   turn counts run 46 parallel tasks; the compiler is trusted to run them.
