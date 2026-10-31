# C02: SampCert (Lean) and "Verified Foundations for Differential Privacy"

## Summary (also in summary.md)
TL;DR: SampCert is a Lean + Mathlib library of verified random samplers (Laplace, Gaussian, uniform and others) for differential privacy, used in AWS. It is the main example of "verified randomness" in Lean.
- Its probability type `SLang α := α → ℝ≥0∞` is simple: a weight for each outcome. The only random primitive is a uniform byte.
- Trust boundary: the primitives carry `@[extern]` attributes, so they run as C code that is not verified against the Lean definitions. Our shuffle has the same boundary: the random source stays outside the proof.
- It has a uniform sampler folder (`Samplers/Uniform`) that shows how to get a uniform number below n from bytes (the files were listed but not opened; details unsure).
- It is too heavy to import for a hackathon (Mathlib, its own pinned toolchain). Use it as a design reference only.
- No shuffles, permutations or games.

Verdict: maybe. It is a good model for the trust boundary and for uniform sampling from bytes. Do not depend on it.

## Citation
- Software: Jean-Baptiste Tristan (principal developer), Markus de Medeiros (developer), others credited. "SampCert: Verified Differential Privacy", version 1.0.0, 2024, DOI 10.5281/zenodo.11204806 (DOI given in the README; I did not open the Zenodo page).
- Paper: Markus de Medeiros, Muhammad Naveed, Tancrède Lepoint, Temesghen Kahsai, Tristan Ravitch, Stefan Zetzsche, Anjali Joshi, Joseph Tassarotti, Aws Albarghouthi, Jean-Baptiste Tristan. "Verified Foundations for Differential Privacy". arXiv:2412.01671 [cs.CR], v1 2 Dec 2024, v3 29 Apr 2025.
- Venue: the arXiv page shows no journal reference. I believe it appeared at a PL conference, but I could not confirm it: venue unsure. Treat as preprint.
- Source type: code repository (artifact) + preprint.
- License: Apache-2.0 (repo).
- URLs fetched 2026-10-31:
  - https://github.com/leanprover/SampCert (README)
  - https://github.com/leanprover/SampCert/tree/main/SampCert (directory)
  - https://github.com/leanprover/SampCert/blob/main/SampCert/SLang.lean (core definitions)
  - https://github.com/leanprover/SampCert/tree/main/SampCert/Samplers and .../Samplers/Uniform (directory listings)
  - https://arxiv.org/abs/2412.01671 (abstract page)
  - http://export.arxiv.org/api/query?search_query=all:SampCert&max_results=5 (search)
- Citation count: Semantic Scholar returned HTTP 429; not obtained.

## Claim status
| Claim | Status |
|---|---|
| Verified discrete Laplace and Gaussian samplers, generic DP framework (pure, zCDP, Rényi) | Machine-checked in Lean 4 + Mathlib (exact toolchain in the repo's `lean-toolchain`, not read) |
| "over 12,000 lines of proof" | Stated in the abstract |
| Used in AWS Clean Rooms Differential Privacy | Stated by the authors (README and abstract); not checkable by us |
| Earlier flaws in DP mechanisms and random number generation caused real vulnerabilities | Opinion/claim in the abstract, citing prior work |

## Setting and definitions
Plain words: a randomized program is described by how much weight (probability) it gives to each possible result. SampCert writes the samplers in Lean, proves their output distributions are the intended ones, and then runs them.

Precise (from `SLang.lean`):
- `abbrev SLang (α : Type u) : Type u := α → ℝ≥0∞`: a distribution is a function from outcomes to extended non-negative reals. The module docs say the probability space "should be interpreted as discrete".
- Normalized distributions: `SPMF α := { f : SLang α // HasSum f 1 }`.
- `probPure a` (Dirac: weight 1 on `a`), `probBind p f := fun b => ∑' a, p a * f a b`.
- `probUniformByte := fun _ => 1 / UInt8.size`: the single random primitive, a uniform byte.
- `probUniformP2 i`: uniform on `[0, 2^i)`, built from bytes (`UInt8.size * w + v.toNat`), with a bit shift for fewer than 8 bits.
- `UniformPowerOfTwoSample n`: uniform on the largest power of two at most n.
- `probWhile cond body init := fun x => ⨆ i, probWhileCut cond body i init x`: a loop is the limit (supremum) of its unrollings. This is how rejection sampling (loop until the sample is below n) is modelled.
- Runtime: `@[extern "prob_Pure"]`, `@[extern "prob_Bind"]`, `@[extern "prob_UniformByte"]`, `@[extern "prob_While"]` on the primitives, and `@[extern "my_run"] opaque run (c : SLang.SPMF T) : IO T`. The repo has an `ffi.cpp`.

## Main results
- From the abstract: a generic DP definition, composition framework, and verified discrete Laplace and Gaussian samplers that avoid floating point.
- The README highlights use of Mathlib results such as the Poisson summation formula (for the Gaussian).
- I did not open the uniform sampler files (`Basic.lean`, `Code.lean`, `Properties.lean`), so I do not state its theorem. Unsure.

## Assumptions and limitations
- The C implementations behind `@[extern]` are not proved to match the Lean definitions. The byte source is trusted. This is the same "randomness stays outside the proof" boundary we will have.
- Note for our CLAUDE.md rules: `@[extern]` and `implemented_by` that change meaning are on the reject list. SampCert uses `extern` for runtime only. If we copy this pattern, our proofs must be about the Lean definitions that are actually executed, or the reviewer will object.
- Heavy dependency on Mathlib.

## What is formally verified
- Machine-checked in Lean 4 with Mathlib: sampler distributions and DP properties. Not verified: the FFI layer and the randomness source.

## Code artifacts and licenses
- github.com/leanprover/SampCert, Apache-2.0.

## Relevance to our project
- Shows a working Lean pattern: program = distribution, single uniform-byte primitive, loops via `probWhile`.
- Shows how to get a uniform number below n from bytes (power-of-two sample plus rejection). We need this if we want "uniform deck" to reach down to bytes. Simpler for us: keep the proof at the "draw sequence" level (see C01) and state the byte-to-draw step as trusted.
- Mathlib PMF (fetched 2026-10-31 from GitHub, master branch; the docs site leanprover-community.github.io failed with a certificate error):
  - https://github.com/leanprover-community/mathlib4/tree/master/Mathlib/Probability/ProbabilityMassFunction (files: Basic, Binomial, Constructions, Integrals, Monad; listing may be truncated)
  - https://github.com/leanprover-community/mathlib4/blob/master/Mathlib/Probability/ProbabilityMassFunction/Constructions.lean : `PMF.map (f : α → β) (p : PMF α) : PMF β`; `PMF.map_apply : (map f p) b = ∑' a, if b = f a then p a else 0`; `PMF.ofFinset`, `PMF.ofFintype`. No lemma about mapping along a bijection or `Equiv`.
  - https://github.com/leanprover-community/mathlib4/blob/master/Mathlib/Probability/Distributions/Uniform.lean : on current master, as the fetch tool read it, `uniformOfFinset` and `ofMultiset` live in the `MeasureTheory.Measure` namespace, and the `PMF.uniformOfFinset` / `PMF.uniformOfFintype` names are deprecated aliases dated 2026-10-04. Lemmas: `uniformOfFinset_apply_singleton` (`= if a ∈ s then (s.card)⁻¹ else 0`), `uniformOfFinset_apply` (`= #{x ∈ s | x ∈ t} / #s`), `ofMultiset_apply_singleton`. No lemma about pushing a uniform distribution along a bijection.
  - Risk: the uniform-distribution API in Mathlib changed in October 2026. The names depend on which Mathlib rev matches our toolchain. Check with `#check` before writing a PMF statement. This is one more reason to prove uniformity by counting (bijection from draw sequences to decks, see C01), which needs no probability library at all.

## Candidate theorems for us
| Plain English | Lean 4 shape (sketch) | Hours |
|---|---|---|
| Our "draw a number below n" helper, run on uniform random bytes, gives each number below n the same chance (rejection sampling) | `theorem drawBelow_uniform (n : ℕ+) : drawBelowDist n = PMF.uniformOfFintype (Fin n)` (names unsure) | 8–16 (stretch; needs a loop model like `probWhile`) |
| Simpler alternative: rejection keeps a byte only if it is below the largest multiple of n that fits, and every kept value maps to each residue the same number of times | `theorem reject_counts (n) (h : 0 < n ∧ n ≤ 256) (r : Fin n) : ((List.range (256 / n * n)).filter (· % n = r)).length = 256 / n` | 1–2 (`decide` for n ≤ 52) |
