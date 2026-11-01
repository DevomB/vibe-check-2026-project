/**
 * What the Lean proofs guarantee, in plain words, for the "What is guaranteed?" drawer.
 *
 * Each entry says only what its theorems say. The names and meanings come from the theorem
 * statements in `engine/Checks/Challenge.lean`, and every theorem listed here must be in
 * `engine/comparator.json` (checked by `guarantees.test.ts`), so a renamed or dropped theorem
 * fails the tests.
 */

/** The ids the drawer can be opened at. The review uses "review", "bluff" and "risk". */
export type GuaranteeId = "chips" | "cards" | "legal" | "risk" | "review" | "equity" | "bluff" | "hindsight";

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
    ],
    theorems: ["step_keeps_chips", "startHand_keeps_chips", "chips_always_1000"],
    assumes: ["The game started as a new game and then changed only by moves and new hands that the engine accepted."],
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
    ],
    theorems: ["shuffle_same_cards", "shuffle_fair", "no_card_dealt_twice"],
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
      "In every game, the player whose turn it is has chips and has not bet more than the other player.",
      "Whenever the player to act may act, the bot's move is legal, at every slider setting.",
    ],
    theorems: ["accepted_move_is_legal", "illegal_move_rejected", "player_to_act_may_act", "botDecide_legal"],
    assumes: [
      "The rules are the ones written in Legal, in engine/Poker/Spec/Basics.lean.",
      "For a rejection: the hand is not over yet.",
    ],
    limits: [
      "The buttons and raise limits on the page come from code that is not proved to match the rules. The engine still rejects any illegal move it gets.",
      "The code that keeps the game between requests is not covered.",
    ],
  },
  {
    id: "risk",
    code: "T4",
    title: "More Risk never turns a fold into a call",
    says: [
      "In one spot, if the bot calls or raises at some Risk, it also calls or raises at every lower Risk.",
      "The bot calls exactly when the call, weighted by Risk, is worth at least as much as folding.",
      "A lost chip counts 1 + Risk/50 times: once at Risk 0, twice at Risk 50, three times at Risk 100.",
      "A call that can never lose chips is taken at every Risk.",
    ],
    theorems: [
      "risk_monotone",
      "botDecide_risk_monotone",
      "callPays_iff_takes",
      "bot_calls_only_when_worth_it",
      "bot_folds_only_when_not_worth_it",
      "more_risk_takes_fewer_gambles",
      "no_loss_always_taken",
    ],
    assumes: [
      "The same spot: the same game state, cards, Bluff setting and win, tie and loss counts.",
      "For the call rule: the amount to call is not more than the pot.",
    ],
    limits: [
      "It compares one decision at a time. It says nothing about whole games, or how often a bot wins.",
      "It holds for any win, tie and loss counts. It does not say the counts are exact on the flop or preflop.",
    ],
  },
  {
    id: "review",
    code: "T5",
    title: "The review grades call and fold correctly, under its model",
    says: [
      "A graded call or fold is Best exactly when it was worth at least as much as the other choice.",
      "A decision that lost fewer big blinds never gets a worse label.",
      "The worths shown are the exact averages over the bot's possible hands, in big blinds. Folding is worth 0.",
      "Calling is Best exactly when the equity you had is at least the equity you needed.",
    ],
    theorems: ["review_worth", "review_lost", "review_best_iff", "review_label_monotone", "review_call_best_iff_equity"],
    assumes: [
      "The bot's possible hands are every hand its river rule bets with on that board, minus the hands that use your cards. Each one counts the same.",
      "For the worths and equities: the bot can hold at least one hand, and calling costs chips.",
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
    title: "The Bluff slider sets the bluffs in the river betting set",
    says: [
      "On a river board, the bot's river betting set has 324 value hands.",
      "Its number of bluffs is the whole number nearest to the one that makes bluffs b% of the set, with halves rounded up.",
      "No hand is both a value hand and a bluff.",
      "With no bet to face on the river, the bot bets exactly the hands in this set.",
    ],
    theorems: ["bluff_frequency", "value_and_bluffs_apart", "bot_bets_its_set"],
    assumes: ["The board has five different cards, and Bluff is 0 to 60."],
    limits: [
      "It is about the set of hands, not how often the bot bluffs in played games.",
      "Your cards, the earlier betting and luck change what you see at the table.",
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
      "Look the same: the same chips, the same board and your same two cards.",
      "For the second theorem: the bot's cards are ones it bets with on that board, and they are not your cards.",
    ],
    limits: ["A right decision can still lose chips. The grade looks at the decision, not the cards that came."],
  },
];

/** What the guarantees rest on without a proof. */
export const TRUSTED: readonly string[] = [
  "The Lean 4.35 kernel, which checks the proofs, and the Lean compiler, which builds the engine the app runs.",
  "Three standard axioms: propext, Quot.sound and Classical.choice.",
  "The rule definitions the theorems use, such as Legal. A person must read them to check they say the right thing.",
  "The preflop table: win, tie and loss counts estimated from random deals. It is data, not a proof.",
  "The web app and the JSON layer: the page, the server route and the code that turns the game into JSON. No proof covers them.",
];

/** The guarantee with this id, if there is one. */
export function guaranteeById(id: string): Guarantee | undefined {
  return GUARANTEES.find((g) => g.id === id);
}
