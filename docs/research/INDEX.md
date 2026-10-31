# Source index

43 source folders: A 8, B 7, C 8, D 7, E 10. Each folder has a `summary.md` (short) and a
`notes.md` (full extraction, with every URL fetched on 2026-10-31). Some folders bundle
several closely related items; the notes list each one. Items the agents could not open
are marked UNVERIFIED in the notes and are not counted here. Free full texts are listed in
[PAPERS.md](PAPERS.md).

Verdicts: **use** = we build on it; **maybe** = background or a stretch goal; **ignore** = related work only.

| id | title | year | type | group | verdict | folder |
|---|---|---|---|---|---|---|
| A01 | Kuhn poker equilibrium family and game value (Hoehn et al. AAAI 2005; Ganzfried and Sandholm) | 2005 | peer-reviewed | A | use | [A01](sources/A01-kuhn-poker-equilibrium/) |
| A02 | Bayes' Bluff: Opponent Modelling in Poker (Southey et al., UAI), Leduc rules, plus OpenSpiel Leduc code | 2005 | peer-reviewed + code | A | use | [A02](sources/A02-bayes-bluff-leduc/) |
| A03 | Ferguson and Ferguson, On the Borel and von Neumann Poker Models (indifference, bluff share) | ~2003 (venue unsure) | paper | A | use | [A03](sources/A03-von-neumann-indifference/) |
| A04 | CFR (NeurIPS 2007), CFR+ (arXiv 2014), Discounted CFR (abstract only) | 2007-2019 | peer-reviewed + preprint | A | maybe | [A04](sources/A04-cfr-family/) |
| A05 | Ganzfried and Sandholm, Safe Opponent Exploitation (ACM TEAC) | 2015 | peer-reviewed | A | use | [A05](sources/A05-safe-opponent-exploitation/) |
| A06 | Johanson, Waugh, Bowling, Zinkevich, Accelerating Best Response Calculation (IJCAI) | 2011 | peer-reviewed | A | use | [A06](sources/A06-best-response-exploitability/) |
| A07 | Landscape: Cepheus, DeepStack, ReBeL, Student of Games, subgame solving (mostly abstracts) | 2015-2023 | mixed | A | maybe | [A07](sources/A07-big-poker-ai-landscape/) |
| A08 | elazarg/GameTheory, a Lean 4 game theory library | 2026 | code repo | A | maybe | [A08](sources/A08-lean-gametheory-library/) |
| B01 | Pratt, Risk Aversion in the Small and in the Large (Econometrica); abstract only, wording checked via Kimball NBER w2848 | 1964 | peer-reviewed | B | use | [B01](sources/B01-pratt-1964-risk-aversion/) |
| B02 | Mathlib docs: finite Jensen, convexity, ordered-field instances for Rat | 2026 | official library docs | B | use (if Mathlib) | [B02](sources/B02-mathlib-jensen-convexity/) |
| B03 | Isabelle AFP: Von Neumann-Morgenstern Utility Theorem (Parsert, Kaliszyk) | 2018 | machine-checked | B | maybe | [B03](sources/B03-afp-vnm-utility/) |
| B04 | Harville, Assigning Probabilities to the Outcomes of Multi-Entry Competitions (JASA) and the ICM | 1973 | peer-reviewed (metadata only) | B | maybe | [B04](sources/B04-harville-1973-icm/) |
| B05 | Gilbert, The Independent Chip Model and Risk Aversion | 2009 | preprint | B | use (3-6 players) | [B05](sources/B05-gilbert-2009-icm-risk-aversion/) |
| B06 | Rockafellar and Uryasev, Optimization of Conditional Value-at-Risk (J. Risk) | 2000 | peer-reviewed | B | maybe | [B06](sources/B06-rockafellar-uryasev-2000-cvar/) |
| B07 | Davis, Waugh, Bowling, Solving Large Extensive-Form Games with Strategy Constraints (AAAI) | 2019 | peer-reviewed | B | ignore | [B07](sources/B07-davis-waugh-bowling-2019-constrained-cfr/) |
| C01 | Eberl, Fisher-Yates shuffle (Isabelle AFP, BSD) | 2016 | machine-checked | C | use | [C01](sources/C01-afp-fisher-yates/) |
| C02 | SampCert (Lean, Apache-2.0) and its paper (arXiv 2412.01671); Mathlib PMF | 2024-2025 | code + preprint | C | maybe | [C02](sources/C02-sampcert-lean/) |
| C03 | Le Roux, Coq sequential games (arXiv 0705.3316) and Le Roux, Martin-Dorel, Smaus (EPTCS 256) | 2007/2017 | papers, machine-checked | C | maybe | [C03](sources/C03-leroux-coq-sequential-games/) |
| C04 | Ramos and Soria, Lean 4 Nash analysis of the Pokémon card game metagame (arXiv 2607.08692) | 2026 | preprint, machine-checked | C | use | [C04](sources/C04-lean-pokemon-tcg-nash/) |
| C05 | Lean game theory libraries (elazarg/GameTheory, math-xmum) and AFP Nash_Equilibrium | 2026 | code + AFP | C | maybe | [C05](sources/C05-lean-gametheory-libraries/) |
| C06 | Poker hand evaluators: HenryRLee/PokerHandEvaluator (Apache-2.0), Cactus Kev (UNVERIFIED) | 2023+ | code repo | C | use | [C06](sources/C06-poker-hand-evaluators/) |
| C07 | Poker TDA Rules 2026 v1.1, plus GGPoker 2022 and UltimateBet 2008 pot-award bug reports | 2026 | official rules + news | C | use | [C07](sources/C07-poker-tda-rules-side-pots/) |
| C08 | Nipkow, Alpha-Beta Pruning (AFP 2024); Burch et al., Revisiting CFR+ (JAIR 2019) | 2019/2024 | machine-checked + peer-reviewed | C | maybe | [C08](sources/C08-game-search-cfr-gap/) |
| D01 | Lean v4.35.0 release notes and matching dependency tags | 2026 | official docs + repos | D | use | [D01](sources/D01-lean-toolchain-v4.35/) |
| D02 | Comparator, `lake check`, `lake comparator` | 2026 | official repo, PRs, notes | D | use | [D02](sources/D02-comparator-lake-check/) |
| D03 | Program verification tools: core `vcgen`, Velvet, iris-lean, Veil | 2026 | manual + repos | D | maybe | [D03](sources/D03-program-verification-tools/) |
| D04 | Testing tools: plausible, Specimen, LSpec | 2026 | repos | D | use (plausible) | [D04](sources/D04-testing-tools/) |
| D05 | Agent tooling: lean-lsp-mcp, Lean REPL | 2026 | repos | D | use (dev only) | [D05](sources/D05-agent-tooling-lsp-mcp-repl/) |
| D06 | GUI shipping: `Std.Http`, `Lean.Json`, Lean2Wasm, ProofWidgets, elan | 2026 | API docs + repos | D | use | [D06](sources/D06-gui-shipping-http-json-wasm/) |
| D07 | Performance: Counting Immutable Beans (IFL 2019), `decide` vs `native_decide`, `Rat` in core | 2019/2026 | peer-reviewed + manual | D | use | [D07](sources/D07-performance-decide-rat/) |
| E01 | Chess.com Game Review and Accuracy help pages | n.d. | official product docs | E | use | [E01](sources/E01-chesscom-game-review/) |
| E02 | Lichess Accuracy page and lila `AccuracyPercent.scala` (AGPL) | n.d. | product docs + code | E | use | [E02](sources/E02-lichess-accuracy/) |
| E03 | Burch et al., AIVAT (arXiv 1612.06915; AAAI 2018) | 2016/2018 | peer-reviewed | E | use | [E03](sources/E03-aivat/) |
| E04 | Billings and Kan, DIVAT (tech report TR06-07; ICGA Journal) | 2006 | tech report | E | maybe | [E04](sources/E04-divat/) |
| E05 | GTO Wizard Analyzer, PokerTracker 4 All-in Equity, RTA press reports | n.d./2025 | product docs + press | E | use | [E05](sources/E05-poker-review-tools/) |
| E06 | Baron and Hershey, Outcome Bias in Decision Evaluation (JPSP); Duke, Thinking in Bets (book) | 1988/2018 | peer-reviewed + book | E | use (pitch) | [E06](sources/E06-outcome-bias/) |
| E07 | Ignatiev, Narodytska, Marques-Silva, Abduction-Based Explanations (AAAI) | 2019 | peer-reviewed | E | use | [E07](sources/E07-abductive-explanations/) |
| E08 | Jacovi and Goldberg, Towards Faithfully Interpretable NLP Systems (ACL) | 2020 | peer-reviewed (position paper) | E | use (framing) | [E08](sources/E08-faithfulness-jacovi-goldberg/) |
| E09 | Zinkevich et al., Optimal Unbiased Estimators for Evaluating Agent Performance (AAAI) | 2006 | peer-reviewed | E | use | [E09](sources/E09-advantage-sum-zinkevich/) |
| E10 | White and Bowling, MIVAT: Learning a Value Analysis Tool for Agent Evaluation (IJCAI) | 2009 | peer-reviewed | E | use | [E10](sources/E10-mivat-white-bowling/) |

## Not opened (UNVERIFIED, not counted)

Kuhn 1950 (original paper); Chen and Ankenman, The Mathematics of Poker (book); Libratus and
Pluribus (Science pages blocked); MCCFR (Lanctot et al. 2009); Cepheus (metadata only); Pratt's
full text (paywalled); Arrow 1965/1971; Hurd's 2002 thesis (certificate error); Cactus Kev's page
(expired certificate); the Two Plus Two evaluator; the TDA Addendum; Vestergaard 2006; the
DIVAT ICGA journal page (403); Hold'em Manager 3 docs (none found); GTO Wizard's own RTA clause
(seen only through press).
