/**
 * What the Lean proofs guarantee, in plain words, for the "What is guaranteed?" drawer.
 *
 * Each entry says only what its theorems say. The names and meanings come from the theorem
 * statements in `engine/Checks/Challenge.lean`, and every theorem listed here must be in
 * `engine/comparator.json` (checked by `guarantees.test.ts`), so a renamed or dropped theorem
 * fails the tests.
 */

/** The ids the drawer can be opened at. The review uses "review", "risk" and "hindsight". */
export type GuaranteeId = "chips" | "cards" | "legal" | "risk" | "review" | "equity" | "bluff" | "bluffcatcher" | "hindsight" | "ends";

export interface Guarantee {
  id: GuaranteeId;
  /** The theorem's short name in the MVP, like "T1". */
  code: string;
  title: string;
  /** What is guaranteed, one plain sentence each. */
  says: string[];
  /** The Lean theorems that prove it, as named in `engine/comparator.json`. */
  theorems: string[];
  /** What the theorems take as given. */
  assumes: string[];
  /** What they do not cover. */
  limits: string[];
}

export const GUARANTEES: readonly Guarantee[] = [
  {
    id: "chips",
    code: "T1",
    title: "Chips are never created or destroyed",
    says: [
      "After every move the engine accepts, the stacks, the pot and the bets add up to the same number of chips as before.",
      "A new hand holds exactly the chips the two players brought to it.",
      "So every game always has exactly 1,000 chips.",
      "The engine's own game session is always such a game: whatever requests it gets, answering them in order only builds games the engine can reach.",
      "At a showdown, the result is worked out from the players' real cards and the board. The better hand ends the hand with more chips than it started with, and the other with fewer. On a tie, both keep what they started with.",
      "A fold ends the hand and gives it to the player who did not fold. That player ends the hand with more chips than they started with, and the player who folded with fewer.",
    ],
    theorems: [
      "step_keeps_chips",
      "startHand_keeps_chips",
      "chips_always_1000",
      "app_game_reachable",
      "showdown_pays_better_hand",
      "fold_pays_other_player",
      "fold_records_other_player",
      "game_hand_from_deal",
    ],
    assumes: [
      "The game started as a new game and then changed only by moves and new hands that the engine accepted. For the engine's session this is proved.",
    ],
    limits: ["It is about the engine's own game state. It does not check the numbers the web page shows."],
  },
  {
    id: "cards",
    code: "T2",
    title: "No card is dealt twice",
    says: [
      "The shuffle only changes the order of the cards. Nothing is added, lost or copied.",
      "Every shuffled deck has the 52 cards of a new deck.",
      "In every game, the cards on the table (both players' cards and the board) are all different, and all come from that deck.",
      "While a hand is played, the board has as many cards as the betting round says: none before the flop, 3 on the flop, 4 on the turn and 5 on the river.",
      "A hand only goes to a showdown with all 5 board cards.",
    ],
    theorems: ["shuffle_same_cards", "shuffle_fair", "no_card_dealt_twice", "board_matches_street", "showdown_has_five_cards"],
    assumes: ["The game started as a new game and then changed only by moves and new hands that the engine accepted."],
    limits: [
      "It does not say every order of the deck is equally likely.",
      "The shuffle uses a seed, so the same seed always deals the same cards.",
    ],
  },
  {
    id: "legal",
    code: "T3",
    title: "Only legal moves are accepted",
    says: [
      "If the engine accepts a move, the rules allow it.",
      'If a move breaks the rules while the hand is still going, the engine rejects it with "illegal move" and makes no new hand.',
      "If a move follows the rules while the hand is still going, the engine accepts it.",
      "In every game, the player whose turn it is has chips and has not bet more than the other player.",
      "Whenever the player to act may act, the bot's move is legal, at every Risk.",
      "Only a game command the engine accepts changes the game. Bad JSON, an unknown command, a review request or a rejected move leaves it exactly as it was.",
      "The buttons the engine offers you are exactly the legal moves: Fold and Check work exactly when they are legal, Call shows what a call costs, and every raise in the offered range, and no other, is legal.",
    ],
    theorems: [
      "accepted_move_is_legal",
      "illegal_move_rejected",
      "legal_move_accepted",
      "player_to_act_may_act",
      "botDecide_legal",
      "handle_error_unchanged",
      "bot_move_accepted",
      "handle_keeps_reachable",
      "respond_keeps_session_unless_accepted",
      "legalOptions_exact",
    ],
    assumes: [
      "The rules are the ones written in Legal, in engine/Poker/Spec/Basics.lean.",
      "For a rejection: the hand is not over yet.",
    ],
    limits: [
      "The browser and the Node bridge between the page and the engine are tested, not proved.",
    ],
  },
  {
    id: "risk",
    code: "T4",
    title: "More Risk never turns a call into a fold, or a bet into a check",
    says: [
      "Facing a bet in one spot, if the bot calls or raises at some Risk, it also calls or raises at every higher Risk.",
      "On the river, with nothing to call and a bet allowed, if the bot bets at some Risk, it also bets at every higher Risk.",
      "Before the river, with nothing to call, the bot makes the same move at every Risk.",
      "Risk sets two numbers inside the bot. Its caution never goes up as Risk goes up, and its bluff share never goes down.",
      "Risk 50 is the textbook setting: caution 0, so a call is judged on plain chips, and a 33% bluff share.",
      "When the bot reaches the call/fold rule, it calls exactly when the call, with a lost chip counted 1 + caution/50 times, is worth at least as much as folding. A strong hand can raise instead.",
      "The call/fold rule accepts a call that can never lose chips, at every Risk.",
      "In every spot the bot really sees, the chips it must add to call are at most the pot, so the call/fold rule above always applies.",
      "The Risk the bot quotes in its reasons does not change its move.",
      "The Risk explorer in the review shows the real bot: its move at each Risk from 0 to 100 is the move the bot's own code makes at that Risk, in the same spot.",
      "So, facing a bet, the explorer never shows a call or raise at some Risk and a fold at a higher Risk.",
      "Inside the bot, the same rule holds for caution: more caution never turns a fold into a call.",
    ],
    theorems: [
      "more_risk_never_folds_a_call",
      "more_risk_never_checks_a_bet",
      "botDecide_no_bet_off_river",
      "ofRisk_caution_antitone",
      "ofRisk_bluff_monotone",
      "ideal_is_textbook",
      "callPays_iff_takes",
      "bot_calls_only_when_worth_it",
      "bot_folds_only_when_not_worth_it",
      "no_loss_always_taken",
      "viewOf_toCall_le_pot",
      "botDecide_action_shown",
      "exploreHandAt_moves",
      "exploreHandAt_more_risk_continues",
      "risk_monotone",
      "botDecide_risk_monotone",
      "more_risk_takes_fewer_gambles",
      "exploreHand_moves",
      "exploreHand_risk_monotone",
    ],
    assumes: [
      "The same spot: the same game state, cards, board and win, tie and loss counts.",
      "For calls: the bot faces a bet. For bets: five cards on the board, nothing to call, and a bet allowed.",
    ],
    limits: [
      "It compares one decision at a time. It says nothing about whole games, or how often a bot wins.",
      "It holds for any win, tie and loss counts. It does not say the counts are exact on the flop or preflop.",
      "Textbook does not mean best against you. It names one setting: plain chips and a 33% bluff share.",
    ],
  },
  {
    id: "review",
    code: "T5",
    title: "The review grades call and fold correctly, under its model",
    says: [
      "A graded call or fold is Best exactly when it was worth at least as much as the other choice.",
      "A decision that lost fewer big blinds never gets a worse label.",
      "Lean computes each worth as an exact average over the bot's possible hands, in big blinds. Folding is worth 0. The screen shows the worths rounded.",
      "Calling is Best exactly when your share of the pot against those hands (a tie counts half) is at least the share calling needed to break even.",
      "When the bot really bet the river, the list of hands it can hold is never empty: its real hand is in it.",
      "With five different cards on the board and two in your hand, that list is never empty, whatever the bluff share.",
      "The range viewer's beat, tie and lose numbers are the same win, tie and loss counts the grade uses.",
      "The range viewer's numbers add up: value hands plus bluffs equal the hands your cards block plus the hands you beat, tie with and lose to.",
    ],
    theorems: [
      "review_worth",
      "review_lost",
      "review_best_iff",
      "review_label_monotone",
      "review_call_best_iff_equity",
      "review_hands_ne_nil",
      "botHands_ne_nil_of_board",
      "rangeOf_counts",
      "rangeOf_adds_up",
    ],
    assumes: [
      "The bot's possible hands are every hand its river rule bets with on that board, minus the hands that use your cards. Each one counts the same.",
      "For the worths and shares: calling costs chips.",
      "For the list of hands: no card was dealt twice, which T2 proves for every game.",
    ],
    limits: [
      "Only your call or fold after the bot's first river bet is graded. Raises and other streets are not.",
      "The model ignores the earlier betting, so it only estimates what the bot really holds.",
      "It makes no claim about raising.",
    ],
  },
  {
    id: "equity",
    code: "T6",
    title: "The exact counts look at every outcome once",
    says: [
      "On the river, the bot counts each two-card hand the other player could hold exactly once: 990 hands.",
      "On the turn, it counts each pair of a river card and such a hand exactly once: 45,540 outcomes.",
      "Each outcome is scored with the rules' own showdown.",
    ],
    theorems: ["enumeration_exact", "riverOpponentHands_length", "turnOutcomes_length", "countsFor_river", "countsFor_turn"],
    assumes: ["For the totals: two hole cards and five (river) or four (turn) board cards, all different."],
    limits: [
      "Flop counts are estimated from 1,000 seeded deals, and preflop counts come from a table. Neither is covered.",
      "Every hand counts the same. The counts do not use the betting so far.",
    ],
  },
  {
    id: "bluff",
    code: "T7",
    title: "Risk sets the bluffs in the river betting set",
    says: [
      "On a river board, the bot's river betting set has 324 value hands.",
      "Its number of bluffs is the whole number nearest to the one that makes bluffs b% of the set, with halves rounded up. b is the bluff share Risk sets: never above 60%.",
      "At Risk 50 the set has 324 value hands and 160 bluffs.",
      "No hand is both a value hand and a bluff.",
      "Every value hand is at least as strong as every hand the bot does not bet for value. Every bluff is no stronger than any hand that is not a bluff.",
      "With no bet to face on the river and a legal bet available, the bot bets exactly the hands in this set.",
      "A bigger bluff share never turns a river bet into a check: the value hands stay the same, and the bluffs only grow.",
    ],
    theorems: [
      "bluff_frequency",
      "value_and_bluffs_apart",
      "value_strongest",
      "bluffs_weakest",
      "bot_bets_its_set",
      "botDecide_river_follows_set",
      "rankRiverHands_sorted",
      "ofRisk_bluff_le_60",
      "ideal_river_set",
      "more_bluff_never_checks_a_bet",
    ],
    assumes: [
      "The board has five different cards.",
      "For a bigger bluff share: nothing to call, a bet allowed, and a share below 100%. Risk never sets more than 60%.",
    ],
    limits: [
      "It is about the set of hands, not how often the bot bluffs in played games.",
      "Your cards, the earlier betting and luck change what you see at the table.",
    ],
  },
  {
    id: "bluffcatcher",
    code: "T7b",
    title: "One bluff in three makes calling and folding equal",
    says: [
      "Say your hand beats every bluff the bot could hold and loses to every value hand. Against a pot-sized bet, calling and folding are worth the same exactly when one of the bot's bets in three is a bluff.",
      "With more bluffs than that, calling is worth more. With fewer, folding is worth more.",
      "For any bet size, they are equal exactly when the number of bluffs times the pot you would win equals the number of value hands times the call.",
      "The review agrees: it grades both call and fold Best exactly when one third of the bot hands your cards do not block are bluffs.",
      "At Risk 50 the bot's river set has 324 value hands and 160 bluffs, two short of one third. Before your cards remove any hands, calling a pot-sized bet with such a hand loses 1/121 of the bet on average.",
      "No whole-number bluff share gives exactly one third beside 324 value hands. 33%, the Risk 50 share, is the closest.",
      "At Risk 100 the set has 486 bluffs: calling such a bet down gains 0.8 bets per call. At Risk 0 it has none: every call loses the bet. For any bet size, more bluffs in the set never make your call worth less.",
      "The bot's side of the same model: a bluff gains nothing exactly when you call with pot / (pot + bet) of your bluff-catchers, half against a pot-sized bet. Call more and every bluff loses; call less and every bluff gains.",
    ],
    theorems: [
      "bluff_catcher_call_total",
      "bluff_catcher_indifferent",
      "one_third_bluffs_indifferent",
      "more_bluffs_call_better",
      "fewer_bluffs_fold_better",
      "review_both_best_iff_one_third",
      "risk50_two_bluffs_short",
      "risk50_bluff_catcher_call_loses",
      "no_bluff_setting_is_exact",
      "bluff_33_is_closest",
      "more_bluffs_more_call_total",
      "maniac_bluff_catcher_total",
      "rock_bluff_catcher_total",
      "bettor_indifferent_iff",
      "defend_more_bluff_loses",
      "defend_less_bluff_gains",
    ],
    assumes: [
      "Your hand beats every bluff and loses to every value hand: no ties.",
      "For the pot-sized results: the bet equals the pot before it, and you can afford the call.",
      "For the Risk 0, 50 and 100 results: the board has five different cards, and the totals are over the whole set before your cards remove any hands.",
      "The bot's side is the model's formula: the engine never models how often you call, and the bot's own calls do not use it.",
    ],
    limits: [
      "Your own cards remove some of the bot's hands, so the real share at the table moves a little either way. The review counts this exactly.",
      "Both halves are about one street in the one-street model: your call or fold against the bot's bet, and the bot's bluff against your calling share. Nothing about the bot as caller or about whole hands.",
      "It ignores the earlier betting, like the rest of the river model.",
    ],
  },
  {
    id: "hindsight",
    code: "T8",
    title: "The grade ignores the bot's real cards",
    says: [
      "Two hands that look the same to you get the same review, whatever cards the bot really holds.",
      "The bot's real hand is one of the hands the review counts.",
    ],
    theorems: ["no_hindsight", "bot_hand_in_review"],
    assumes: [
      "Look the same: the same bluff share (set by Risk), chips, board and your two cards.",
      "For the second theorem: the bot's cards are ones it bets with on that board, and they are not your cards.",
    ],
    limits: ["A right decision can still lose chips. The grade looks at the decision, not the hand the bot turned out to hold."],
  },
  {
    id: "ends",
    code: "T9",
    title: "Every hand ends",
    says: [
      "From any game the engine can reach, every run of accepted moves in one hand has at most 200 moves.",
      "So no hand goes on forever.",
    ],
    theorems: ["every_hand_ends"],
    assumes: ["The game started as a new game and then changed only by moves and new hands that the engine accepted."],
    limits: [
      "It counts moves in one hand. It does not bound how many hands a game has.",
      "It says nothing about how long each move takes to compute.",
    ],
  },
];

/** What the guarantees rest on without a proof. */
export const TRUSTED: readonly string[] = [
  "The Lean 4.35 kernel, which checks the proofs, and the Lean compiler, which builds the engine the app runs.",
  "Three standard axioms: propext, Quot.sound and Classical.choice.",
  "The rule definitions the theorems use, such as Legal. A person must read them to check they say the right thing.",
  "The preflop table: win, tie and loss counts estimated from random deals. It is data, not a proof.",
  "The browser, the Node bridge, the buttons and raise limits the page offers, and the JSON the engine writes for the page. These are tested, not proved. Which requests change the game, and what a rejected move replies, are proved.",
];

/** The guarantee with this id, if there is one. */
export function guaranteeById(id: string): Guarantee | undefined {
  return GUARANTEES.find((g) => g.id === id);
}
