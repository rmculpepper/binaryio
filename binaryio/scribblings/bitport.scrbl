#lang scribble/manual
@(require scribble/example
          (for-label racket/base racket/contract
                     binaryio/bitvector
                     binaryio/bitport))

@(begin
  (define the-eval (make-base-eval))
  (the-eval '(require binaryio/bitvector binaryio/bitport)))

@; ----------------------------------------
@title[#:tag "bitport"]{Bitports}

@defmodule[binaryio/bitport]
@history[#:added "1.2"]

An @deftech{output bitport} is like an output string port
(@racket[open-output-bytes]), except that instead of accumulating bytes, it
accumulates bits and packs them into a byte string.

@defproc[(output-bitport? [v any/c]) boolean?]{

Returns @racket[#t] if @racket[v] is an output bitport, @racket[#f] otherwise.
}

@defproc[(open-output-bitport [msf? boolean? #t])
         output-bitport?]{

Creates a new empty output bitport.

If @racket[msf?] is true, then the bytes produced by the bitport (through
@racket[output-bitport-get-output]) represents the sequence in @tech{most
significant first} bit order.
}

@defproc[(output-bitport-partial [bp output-bitport?]) sbv?]{

Returns @racket[bp]'s current partial bitvector, consisting of the last bits
written (between 0 and 7, inclusive) that have not yet been packed into a byte.
}

@defproc[(output-bitport-write-bit [bp output-bitport?] [bit (or/c 0 1)]) void?]{

Writes a single bit to @racket[bp].

Equivalent to @racket[(output-bitport-write-sbv (make-sbv bit 1))].
}

@defproc[(output-bitport-write-sbv [bp output-bitport?] [sbv sbv?]) void?]{

Writes the bitvector @racket[sbv] to @racket[bp].
}

@defproc[(output-bitport-get-output [bp output-bitport?]
                                    [#:reset? reset? boolean? #f]
                                    [#:pad pad-sbv sbv? empty-sbv])
         (values bytes? exact-nonnegative-integer?)]{

Returns @racket[(values _output _bits-written)], where @racket[_output] is the
accumulated output of @racket[bp] as a @emph{big-endian} byte string and
@racket[_bits-written] is the number of bits written to @racket[bp]. The byte
string is big-endian in the following sense: the first bit written is the
@emph{most} significant bit of the first byte in the byte string.

If @racket[bp] contains an incomplete byte (because @racket[_bits-written] is
not divisible by 8), then the final byte of the output is padded with the lower
bits of @racket[pad-sbv] (extended with zeros if more padding bits are
needed). If @racket[_bits-written] is divisible by 8, no padding is included.

If @racket[reset?] is true, then all written bits are removed from @racket[bp].
}

@defproc[(output-bitport-pad [bp output-bitport?]
                             [#:pad pad-sbv sbv? 0])
         exact-nonnegative-integer?]{

Pads the bits written to @racket[bp] to a whole byte, using the lower bits of
@racket[pad-sbv]. If the number of bits written to @racket[bp] is divisible by
8, then no padding is done. The result is the number of padding bits added
(between 0 and 7, inclusive).
}

@defproc[(bytes-bit-set? [bs bytes?] [bit-index exact-nonnegative-integer?])
         boolean?]{

Returns @racket[#t] if the bit at @racket[bit-index] is set in @racket[bs],
@racket[#f] otherwise.

The byte string is interpreted as big-endian in the following sense: within a
single byte in @racket[bs], bits are indexed started with the @emph{most}
significant bit first. So for example, @racket[(bytes-bit-set? (bytes b) 0)] is
@racket[(bitwise-bit-set? b 7)].

@examples[#:eval the-eval
(bytes-bit-set? (bytes 1 128) 0)
(bytes-bit-set? (bytes 1 128) 7)
(bytes-bit-set? (bytes 1 128) 8)
(bytes-bit-set? (bytes 1 128) 15)
]}

@(close-eval the-eval)