# Summary: C02: SampCert (Lean) and "Verified Foundations for Differential Privacy"

**Source:** de Medeiros et al. "Verified Foundations for Differential Privacy." arXiv preprint. https://arxiv.org/abs/2412.01671. Code: SampCert (Apache-2.0), https://github.com/leanprover/SampCert

TL;DR: SampCert is a Lean + Mathlib library of verified random samplers (Laplace, Gaussian, uniform and others) for differential privacy, used in AWS. It is the main example of "verified randomness" in Lean.
- Its probability type `SLang α := α → ℝ≥0∞` is simple: a weight for each outcome. The only random primitive is a uniform byte.
- Trust boundary: the primitives carry `@[extern]` attributes, so they run as C code that is not verified against the Lean definitions. Our shuffle has the same boundary: the random source stays outside the proof.
- It has a uniform sampler folder (`Samplers/Uniform`) that shows how to get a uniform number below n from bytes (the files were listed but not opened; details unsure).
- It is too heavy to import for a hackathon (Mathlib, its own pinned toolchain). Use it as a design reference only.
- No shuffles, permutations or games.

Verdict: maybe. It is a good model for the trust boundary and for uniform sampling from bytes. Do not depend on it.


Full extraction: [notes.md](notes.md).
