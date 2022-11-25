#lang scribble/manual
@(require scribble/example
          (for-label racket/base racket/contract
                     binaryio/bitvector))

@(begin
  (define the-eval (make-base-eval))
  (the-eval '(require binaryio/bitvector)))

@; ----------------------------------------
@title[#:tag "sbv"]{Short Bitvectors}

@defmodule[binaryio/bitvector]
@history[#:added "1.2"]

A @deftech{short bitvector} is an immutable bitvector represented as a
Racket exact nonnegative integer. The bitvector
@racket[[_b_0 _b_1 _b_2 ... _b_L-1]]
is represented as the integer
@racketblock[
(+ _L
   (* _b_0 (arithmetic-shift 1 (+ 0 SBV-LENGTH-BITS)))
   (* _b_1 (arithmetic-shift 1 (+ 1 SBV-LENGTH-BITS)))
   (* _b_2 (arithmetic-shift 1 (+ 2 SBV-LENGTH-BITS)))
   ...
   (* _b_L-1 (arithmetic-shift 1 (+ _L-1 SBV-LENGTH-BITS))))
]
where @racket[SBV-LENGTH-BITS] is currently @racket[16]. That is, a bitvector is
represented as a length field plus a shifted @emph{little-endian} encoding of
its bits (the first bit of the bitvector is represented by the @emph{least}
significant bit of the encoded number, before shifting).

Consequently, bitvectors up to about 46 bits are represented using fixnums (on
64-bit versions of Racket), and only bitvectors up to @racket[(sub1 (expt 2
SBV-LENGTH-BITS))] bits are representable.

@defthing[SBV-LENGTH-BITS exact-nonnegative-integer? #:value 16]{

Number of bits used to represent the length of a bitvector.
}

@defthing[SBV-LENGTH-BOUND exact-nonnegative-integer?
                           #:value @#,(racketvalfont (number->string (expt 2 16)))]{

Bound for representable bitvector lengths. Specifically, a length must be
@emph{strictly less than} @racket[SBV-LENGTH-BOUND] to be representable.
}

@defproc[(sbv? [v any/c]) boolean?]{

Returns @racket[#t] if @racket[v] represents a @tech{short bitvector},
@racket[#f] otherwise.

Equivalent to @racket[exact-nonnegative-integer?]. See also
@racket[canonical-sbv?].
}

@defproc[(canonical-sbv? [v any/c]) boolean?]{

Returns @racket[#t] if @racket[v] is a canonical representation of a
@tech{short bitvector}, @racket[#f] otherwise.

For example, @racket[(make-sbv @#,(racketvalfont "#b1011") 2)] is not
canonical because it has a bit set after the first two bits.

@bold{Warning: } In general, the functions in this library may produce bad
results if given non-canonical bitvector values.
}

@defproc[(make-sbv [le-bits exact-nonnegative-integer?]
                   [bitlength exact-nonnegative-integer?])
         sbv?]{

Returns @racket[#t] if @racket[v] is a @tech{short bitvector}, @racket[#f]
otherwise. The number @racket[le-bits] is interpreted in a @emph{little-endian}
fashion: the first bit of the bitvector is the @emph{least} significant bit of
@racket[le-bits].

If @racket[le-bits] has a bit set after the first @racket[bitlength] bits, then
the result is non-canonical (see @racket[canonical-sbv?]).
If @racket[bitlength] is not less then @racket[SBV-LENGTH-BOUND], an error is
raised.

@examples[#:eval the-eval
(sbv->string (make-sbv 6 3))
]}

@defproc[(make-be-sbv [be-bits exact-nonnegative-integer?]
                      [bitlength exact-nonnegative-integer?])
         sbv?]{

Like @racket[make-sbv], but interprets @racket[be-bits] in a @emph{big-endian}
fashion: the first bit of the bitvector is the @emph{most} significant bit of
@racket[be-bits] (interpreted as a @racket[bitlength]-bit number).

Equivalent to @racket[(sbv-reverse (make-sbv be-bits bitlength))].

@examples[#:eval the-eval
(sbv->string (make-be-sbv 6 3))
]}

@defthing[empty-sbv sbv? #:value (make-sbv 0 0)]{

The empty bitvector.
}

@defproc[(sbv-empty? [sbv sbv?]) boolean?]{

Returns @racket[#t] if @racket[v] is the empty bitvector, @racket[#f] otherwise.
}

@defproc[(sbv-length [sbv sbv?]) exact-nonnegative-integer?]{

Returns the length of the bitvector.
}

@defproc[(sbv-bits [sbv sbv?]) exact-nonnegative-integer?]{

Returns the little-endian encoding of the bitvector's bits.

@examples[#:eval the-eval
(sbv-bits (string->sbv "1011"))
]}

@defproc[(sbv-bit-field [sbv sbv?]
                        [start exact-nonnegative-integer?]
                        [end exact-nonnegative-integer?])
         exact-nonnegative-integer?]{

Returns the little-endian encoding of the bitvector's bits from @racket[start]
(inclusive) to @racket[end] (exclusive).

If @racket[end] is greater than @racket[(sbv-length sbv)], then the ``out of
range'' bits are set to zero.

@examples[#:eval the-eval
(sbv-bit-field (string->sbv "11100") 1 4)
(sbv-bit-field (string->sbv "11100") 1 10)
]}

@defproc[(sbv-slice [sbv sbv?]
                    [start exact-nonnegative-integer?]
                    [end exact-nonnegative-integer?])
         sbv?]{

Returns the bitvector containing the subsequence of bits from @racket[sbv] from
indexes @racket[start] (inclusive) to @racket[end] (exclusive).

If @racket[end] is greater than @racket[(sbv-length sbv)], then the ``out of
range'' bits are set to zero.

@examples[#:eval the-eval
(sbv->string (sbv-slice (string->sbv "11100") 1 4))
(sbv->string (sbv-slice (string->sbv "11100") 1 10))
]}

@defproc[(sbv-shift [sbv sbv?] [lshift exact-integer?]) sbv?]{

If @racket[lshift] is positive, adds @racket[lshift] zero bits to the beginning
of the bitvector. If @racket[lshift] is negative, removes @racket[(- lshift)]
bits from the beginning of the bitvector.

@examples[#:eval the-eval
(sbv->string (sbv-shift (string->sbv "11100") 3))
(sbv->string (sbv-shift (string->sbv "11100") -2))
]}

@defproc[(sbv-bit-set? [sbv sbv?] [index exact-nonnegative-integer?]) boolean?]{

Returns @racket[#t] if the bit at index @racket[index] of @racket[sbv] is set
(@racket[1]), @racket[#f] if it is unset (@racket[0]). If @racket[index] is not
less than @racket[(sbv-length sbv)], and @racket[sbv] is canonical, then
@racket[#f] is returned.

@examples[#:eval the-eval
(sbv-bit-set? (string->sbv "1101") 0)
(sbv-bit-set? (string->sbv "1101") 1)
(sbv-bit-set? (string->sbv "1101") 2)
]}

@defproc[(sbv-ref [sbv sbv?] [index exact-nonnegative-integer?]) (or/c 0 1)]{

Like @racket[sbv-bit-set?], but returns the bit at the given index.

@examples[#:eval the-eval
(sbv-ref (string->sbv "1101") 0)
(sbv-ref (string->sbv "1101") 1)
(sbv-ref (string->sbv "1101") 2)
]}

@deftogether[[
@defproc[(sbv-car [sbv sbv?]) (or/c 0 1)]
@defproc[(sbv-cdr [sbv sbv?]) sbv?]
]]{

Returns the first bit of the bitvector and the rest of the bitvector, respectively.

Equivalent to @racket[(sbv-ref sbv 0)] and @racket[(sbv-shift sbv -1)].

@examples[#:eval the-eval
(sbv-car (string->sbv "110"))
(sbv->string (sbv-cdr (string->sbv "110")))
]}

@defproc[(sbv-append [sbv sbv?] ...) sbv?]{

Returns the concatenation of the given bitvectors.

@examples[#:eval the-eval
(sbv->string (sbv-append (string->sbv "1011") (string->sbv "00")))
]}

@defproc[(sbv-cons [bit (or/c 0 1)] [sbv sbv?]) sbv?]{

Adds a bit to the beginning of the bitvector.

Equivalent to @racket[(sbv-append (make-sbv bit 1) sbv)].
}

@defproc[(sbv-reverse [sbv sbv?]) sbv?]{

Reverses the bits of the bitvector.

@examples[#:eval the-eval
(sbv->string (sbv-reverse (string->sbv "1101")))
]}

@defproc[(sbv-prefix? [sbv1 sbv?] [sbv2 sbv?]) boolean?]{

Returns @racket[#t] if @racket[sbv1] is a prefix of @racket[sbv2].

@examples[#:eval the-eval
(sbv-prefix? (string->sbv "110") (string->sbv "110"))
(sbv-prefix? (string->sbv "110") (string->sbv "1100"))
(sbv-prefix? (string->sbv "110") (string->sbv "100110"))
(sbv-prefix? (string->sbv "110") (string->sbv "11"))
]}

@defproc[(sbv->string [sbv sbv?]) string?]{

Returns a string of @litchar{0} and @litchar{1} characters representing the bits
of @racket[sbv].

@examples[#:eval the-eval
(sbv->string (sbv-append (make-sbv 1 1) (make-sbv 1 1) (make-sbv 0 1)))
]

If @racket[sbv] is canonical, then @racket[sbv] is equal to
@racketblock[
(make-be-sbv (string->number (sbv->string sbv) 2) (sbv-length sbv))
]}

@defproc[(string->sbv [s (and/c string? #rx"^[01]*$")]) sbv?]{

Parses @racket[s], which should consist of @litchar{0} and @litchar{1}
characters, and returns the corresponding bitvector.
}

@(close-eval the-eval)
