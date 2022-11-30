#lang scribble/manual
@(require scribble/example
          (for-label racket/base racket/contract racket/port
                     binaryio/bitvector
                     binaryio/bitport
                     binaryio/prefixcode))

@(begin
  (define the-eval (make-base-eval))
  (the-eval '(require binaryio/bitvector binaryio/prefixcode racket/port)))

@; ----------------------------------------
@title[#:tag "prefixcode"]{Prefix Codes: Encoding and Decoding}

@defmodule[binaryio/prefixcode]
@history[#:added "1.2"]

This module provides encoding and decoding support using
@hyperlink["https://en.wikipedia.org/wiki/Prefix_code"]{prefix codes} (aka
@as-index{prefix-free codes}), including
@hyperlink["https://en.wikipedia.org/wiki/Huffman_coding"]{Huffman codes}.
See @racketmodname[binaryio/huffman] for support for computing such codes.

@defproc[(prefixcode-encode [encode-table (or/c (hash/c any/c sbv?)
                                                (listof (cons/c any/c sbv?))
                                                (vectorof sbv?))]
                            [input sequence?]
                            [msf? boolean? #t]
                            [#:pad pad-sbv sbv? empty-sbv])
         (values bytes? exact-nonnegative-integer?)]{

Encodes the values of @racket[input] using @racket[encode-table], which
represents the prefix code as a mapping of values to @tech{short bitvectors}. The
@racket[input] can be any sequence, including strings, byte strings, lists, and
so on. The result is a byte string containing the encoded bits, along with the
number of bits in the encoding. See @racket[output-bitport-get-output] for the
format of the encoded byte string and the interpretation of the @racket[pad-sbv]
argument.

The @racket[encode-table] must be one of the following:
@itemlist[
@item{@racket[(hash _value _code ... ...)]}
@item{@racket[(list (cons _value _code) ...)]}
@item{@racket[(vector _code ...)] --- where the vector indexes are the values}
]
Each code in the table must be unique, and the set of codes must form a valid
prefix code. Otherwise, the results of encoding and decoding are unpredictable.

If @racket[msf?] is @racket[#t] (the default), then bits within each byte are
added in @tech{most significant first} order. If @racket[msf?] is @racket[#f],
then bits within each byte are added in @tech{least significant first} order.

@examples[#:eval the-eval
(require binaryio/examples/hpack)
(define-values (enc enc-bits)
  (prefixcode-encode hpack-encode-table #"hello world!" #:pad hpack-end-code))
(values enc enc-bits)
]}

@defproc[(prefixcode-encode! [bp output-bitport?]
                             [encode-table (or/c (hash/c any/c sbv?)
                                                 (listof (cons/c any/c sbv?))
                                                 (vectorof sbv?))]
                             [input sequence?]
                             [#:pad pad-sbv sbv? empty-sbv])
         void?]{

Like @racket[prefixcode-encode], but writes the encoded bits to @racket[bp].
}

@defproc[(prefixcode-build-decode-tree [encode-table (or/c (hash/c any/c sbv?)
                                                     (listof (cons/c any/c sbv?))
                                                     (vectorof sbv?))])
         any/c]{

Converts @racket[encode-table] (see @racket[prefixcode-encode]) into a data
structure suitable for decoding the same prefix code.

The representation is not specified, but if all values in the table are readable
(or quotable), then the representation of the decoder tree is readable (or
quotable).

@examples[#:eval the-eval
(define hpack-decode-tree (prefixcode-build-decode-tree hpack-encode-table))
]}

@defproc[(prefixcode-decode [decode-tree any/c]
                            [bs bytes?]
                            [start-bit-index exact-nonnegative-integer? 0]
                            [end-bit-index exact-nonnegative-integer? (* 8 (bytes-length bs))]
                            [msf? boolean? #t]
                            [#:end end-code (or/c sbv? #f) #f]
                            [#:handle-error handle-error
                                            (-> (or/c 'bad 'incomplete)
                                                exact-nonnegative-integer?
                                                exact-nonnegative-integer?
                                                sbv?
                                                any)
                                            (lambda (mode start end code) (error ....))])
         bytes?]{

Decodes @racket[bs] (from @racket[start-bit-index], inclusive, to
@racket[end-bit-index], exclusive) using the prefix code represented by
@racket[decode-tree], which must have been produced by
@racket[prefixcode-build-decode-tree].

Each value represented by @racket[decode-tree] must be a byte, character, byte
string, or character string. Each decoded value is accumulated into a byte
string, which is the result of successful decoding.

If the decoder encounters a sequence of bits that is not a valid code prefix, it calls
@racketblock[
(handle-error 'bad _bad-start-index _bad-end-index _bad-code)
]
to handle the error.
If the decoder reaches @racket[end-bit-index] without completing the current
code, and if @racket[end-code] is @racket[#f], then it handles the error by
calling
@racketblock[
(handle-error 'incomplete _incomplete-start-index end-bit-index _incomplete-code)
]
But if @racket[end-code] is a bitvector, then no error is signaled if the bits
between the end of the last complete code and @racket[end-bit-index] are a
prefix of @racket[end-code].

Note that if @racket[handle-error] returns normally, its result is discarded, so
it is recommended that @racket[handle-error] escape (for example, by raising an
exception).

@examples[#:eval the-eval
(prefixcode-decode hpack-decode-tree enc 0 enc-bits)
(prefixcode-decode hpack-decode-tree enc #:end hpack-end-code)
(prefixcode-decode hpack-decode-tree enc #:handle-error list)
]}

@defproc[(prefixcode-decode! [output (or/c output-port? (-> any/c void?))]
                             [decode-tree any/c]
                             [bs bytes?]
                             [start-bit-index exact-nonnegative-integer? 0]
                             [end-bit-index exact-nonnegative-integer? (* 8 (bytes-length bs))]
                             [msf? boolean? #t]
                             [#:end end-code (or/c sbv? #f) #f]
                             [#:handle-error handle-error
                                             (-> (or/c 'bad 'incomplete)
                                                 exact-nonnegative-integer?
                                                 exact-nonnegative-integer?
                                                 sbv?
                                                 any)
                                             (lambda (mode start end code) (error ....))])
         (or/c void? any)]{

Like @racket[prefixcode-decode], but each decoded value is sent to
@racket[output], and the result of a successful decoding is @racket[(void)].

If @racket[output] is an output port, then a decoded value must be a byte,
character, byte string, or character string, and the value is emitted by writing
it to the port. If @racket[output] is a procedure, then any value is allowed,
and the value is emitted by calling @racket[output] on it.

If decoding completes successfully, the result is @racket[(void)]; otherwise, it
is the result of the call to @racket[handle-error].

@examples[#:eval the-eval
(call-with-output-bytes
  (lambda (out)
    (prefixcode-decode! out hpack-decode-tree enc 0 enc-bits)))
(call-with-output-bytes
  (lambda (out)
    (prefixcode-decode! out hpack-decode-tree enc 0 #:end hpack-end-code)))
(prefixcode-decode! void hpack-decode-tree enc #:handle-error list)
]}

@defproc[(prefixcode-decode-list [decode-tree any/c]
                                 [bs bytes?]
                                 [start-bit-index exact-nonnegative-integer? 0]
                                 [end-bit-index exact-nonnegative-integer? (* 8 (bytes-length bs))]
                                 [msf? boolean? #t]
                                 [#:end end-code (or/c sbv? #f) #f]
                                 [#:handle-error handle-error
                                                 (-> (or/c 'bad 'incomplete)
                                                     exact-nonnegative-integer?
                                                     exact-nonnegative-integer?
                                                     sbv?
                                                     any)
                                                 (lambda (mode start end code) (error ....))])
         list?]{

Like @racket[prefixcode-decode], but decodes the input to a list. This allows
values other than bytes, characters, and character strings to be conveniently
decoded.

Note that if @racket[handle-error] returns normally, its result is discarded, so
it is recommended that @racket[handle-error] escape (for example, by raising an
exception).
}

@defproc[(prefixcode-decode1 [decode-tree any/c]
                             [bs bytes?]
                             [start-bit-index exact-nonnegative-integer? 0]
                             [end-bit-index exact-nonnegative-integer? (* 8 (bytes-length bs))]
                             [msf? boolean? #t]
                             [#:end end-code (or/c sbv? #f) #f])
         (values (or/c 'ok 'bad 'end 'incomplete) exact-nonnegative-integer? any/c)]{

Like @racket[prefixcode-decode], but decodes a single value from the input. The
result is one of the following:
@itemlist[

@item{@racket[(values 'ok _next-bit-index _value)] --- The bits from
@racket[start-bit-index] (inclusive) to @racket[_next-bit-index] (exclusive)
represent the code for @racket[_value].}

@item{@racket[(values 'bad _next-bit-index _bad-code)] --- The bits from
@racket[start-bit-index] to @racket[_next-bit-index] do not represent a valid
code or its prefix. The @racket[_bad-code] result contains those bits as a
bitvector.}

@item{@racket[(values 'incomplete _next-bit-index _incomplete-code)] --- The
bits from @racket[start-bit-index] to @racket[_next-bit-index] represent an
incomplete code, but it is not a prefix of @racket[end-code]. The
@racket[_incomplete-code] result contains those bits as a bitvector.}

@item{@racket[(values 'end _next-bit-index _final-code)] --- The bits from
@racket[start-bit-index] to @racket[_next-bit-index] represent a prefix of
@racket[end-code] --- possibly all of @racket[end-code], possibly empty (if
@racket[start-bit-index] equals @racket[end-bit-index]). The
@racket[_final-code] result contains those bits as a bitvector.}

]

@examples[#:eval the-eval
(prefixcode-decode1 hpack-decode-tree enc 0)
(prefixcode-decode1 hpack-decode-tree enc 6)
(bytes 104 101)
]}

@(close-eval the-eval)
