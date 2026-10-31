import __LIB__.Impl

/-! # Specification: the codec loses nothing. Humans own this file. -/

namespace __LIB__.Spec
open __LIB__

/-- Headline. Decoding an encoded text gives back exactly the original text. -/
def roundtrip : Prop := ∀ s : List Char, decode (encode s) = s

/-- Every run the encoder produces has a positive length. -/
def countsPositive : Prop := ∀ (s : List Char), ∀ p ∈ encode s, 0 < p.2

end __LIB__.Spec
