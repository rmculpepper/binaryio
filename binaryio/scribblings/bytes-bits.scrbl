#lang scribble/manual
@(require scribble/example
          (for-label racket/base racket/contract
                     binaryio/bytes-bits
                     binaryio/bitvector))

@(begin
  (define the-eval (make-base-eval))
  (the-eval '(require binaryio/bytes-bits binaryio/bitvector)))

@; ----------------------------------------
@title[#:tag "bytes-bits"]{Bytes as Bits}

This module provides support for interpreting a Racket byte string
(@racket[bytes?]) as a sequence of bits. It supports two @deftech{bit indexing
orders}:
@itemlist[

@item{In @deftech{most significant first} order, the first bit in the sequence
corresponds to the most significant bit of the first byte of the byte string.

For example, the bit sequence @tt{11000000} is represented by
@racket[(bytes @#,racketvalfont{#b11000000})].}

@item{In @deftech{least significant first} order, the first bit in the sequence
corresponds to the least significant bit of the first byte of the byte
string. (This is the natural order corresponding to using
@racket[bitwise-bit-set?] on the remainder modulo 8 of the bit index.)

For example, the bit sequence @tt{11000000} is represented by
@racket[(bytes @#,racketvalfont{#b00000011})].}

]
This library uses @emph{most significant first} order by default.

@defmodule[binaryio/bytes-bits]
@history[#:added "1.3"]

@defproc[(bytes-bit-length [bs bytes?]) exact-nonnegative-integer?]{

Returns the length of @racket[bs] in bits.

Equivalent to @racket[(* 8 (bytes-length bs))].
}

@defproc[(bytes-bit-set? [bs bytes?]
                         [bit-index exact-nonnegative-integer?]
                         [msf? boolean? #t])
         boolean?]{

Returns @racket[#t] if the bit in @racket[bs] at @racket[bit-index] is set (1),
@racket[#f] if it is unset (0).

If @racket[msf?] is @racket[#t] (the default), then bits within each byte are
indexed in @tech{most significant first} order. If @racket[msf?] is @racket[#f],
then bits within each byte are indexed in @emph{least significant first} order.

@examples[#:eval the-eval
(eval:alts
 (define bs (bytes @#,racketvalfont{#b00000001} @#,racketvalfont{#b00000011}))
 (define bs (bytes #b00000001 #b00000011)))
(bytes-bit-set? bs 0)
(bytes-bit-set? bs 0 #f)
(bytes-bit-set? bs 6)
(bytes-bit-set? bs 7)
]}

@defproc[(bytes-bit-set! [bs bytes?]
                         [bit-index exact-nonnegative-integer?]
                         [value boolean?]
                         [msf? boolean? #t])
         void?]{

Sets the bit in @racket[bs] at position @racket[bit-index] to 1 if
@racket[value] is @racket[#t] or 0 if @racket[value] is @racket[#f].

The @racket[msf?] argument determines how @racket[bit-index] is interpreted as
for @racket[bytes-bit-set?].
}

@defproc[(bytes-bits->sbv [bs bytes?]
                          [start-biti exact-nonnegative-integer? 0]
                          [end-biti (or/c #f exact-nonnegative-integer?) #f]
                          [msf? boolean? #t])
         sbv?]{

Returns a @tech{short bitvector} representing the subsequence of bits in
@racket[bs] from @racket[start-biti] (inclusive) to @racket[end-biti]
(exclusive). If @racket[end-biti] is @racket[#f], it is interpreted as
@racket[(bytes-bit-length bs)].

@examples[#:eval the-eval
(sbv->string (bytes-bits->sbv bs 4 12))
(sbv->string (bytes-bits->sbv bs 12 16))
(bytes-bits->string bs 12 16 #t)
(sbv->string (bytes-bits->sbv bs 12 16 #f))
(bytes-bits->string bs 12 16 #f)
]}

@defproc[(bytes-bits->string [bs bytes?]
                             [start-biti exact-nonnegative-integer? 0]
                             [end-biti (or/c #f exact-nonnegative-integer?) #f]
                             [msf? boolean? #t])
         string?]{

Returns a string of @litchar{0} and @litchar{1} characters representing the bits
of @racket[bs] from @racket[start-biti] (inclusive) to @racket[end-biti]
(exclusive). If @racket[end-biti] is @racket[#f], it is interpreted as
@racket[(bytes-bit-length bs)].

@examples[#:eval the-eval
(bytes-bits->string bs)
(bytes-bits->string bs 0 #f #f)
]}

@defproc[(string->bytes-bits [s (and/c string? #rx"^[01]$")]
                             [msf? boolean? #t])
         bytes?]{

Parses @racket[s], which should consist of @litchar{0} and @litchar{1}
characters, and returns the byte string representing the bit sequence. If the
length of @racket[s] is not a multiple of 8, then the sequence is padded with 0
bits.

@examples[#:eval the-eval
(string->bytes-bits "00010011")
]}

@(close-eval the-eval)
