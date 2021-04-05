#lang scribble/manual
@(require scribble/example
          (for-label racket/base racket/contract
                     binaryio/bytes
                     binaryio/integer
                     binaryio/float
                     binaryio/reader
                     binaryio/fixup-port
                     binaryio/bitvector
                     binaryio/bitport))

@(begin
  (define the-eval (make-base-eval))
  (the-eval '(require binaryio binaryio/bitvector binaryio/bitport)))

@title{binaryio: Functions for Reading and Writing Binary Data}
@author[@author+email["Ryan Culpepper" "ryanc@racket-lang.org"]]

This library provides functions for reading, writing, and converting
binary data. It is designed for the use case of implementing network
protocols, although this library focuses on low-level support, not
high-level protocol specification.

@defmodule[binaryio]

This module combines the exports of @racketmodname[binaryio/bytes],
@racketmodname[binaryio/integer], and @racketmodname[binaryio/float].


@; ----------------------------------------
@section[#:tag "bytes"]{Bytes}

@defmodule[binaryio/bytes]

@defproc[(read-bytes* [len exact-nonnegative-integer?]
                      [in input-port? (current-input-port)])
         bytes?]{

Like @racket[read-bytes], but returns a byte string of exactly
@racket[len] bytes. If fewer than @racket[len] bytes are available
before the end of input, an exception is raised.

@examples[
#:eval the-eval
(define in (open-input-bytes #"abcde"))
(read-bytes* 4 in)
(eval:error (read-bytes* 2 in))
]
}

@defproc[(write-null-terminated-bytes [bstr bytes?]
                                      [out output-port? (current-output-port)]
                                      [start exact-nonnegative-integer? 0]
                                      [end exact-nonnegative-integer? (bytes-length bstr)])
         void?]{

Writes bytes to @racket[out] from @racket[bstr] from index
@racket[start] (inclusive) to @racket[end] (exclusive), and then
writes a null (0) byte terminator.

If @racket[bstr] contains any null bytes between @racket[start] and
@racket[end], an error is raised.
}

@defproc[(read-null-terminated-bytes [in input-port? (current-input-port)])
         bytes?]{

Reads from @racket[in] until a null (0) byte is found, then returns
the bytes read, @emph{excluding} the null terminator. If no null
terminator is found before the end of input, an error is raised.

@examples[
#:eval the-eval
(define-values (in out) (make-pipe))
(write-null-terminated-bytes #"abcde" out)
(read-null-terminated-bytes in)
]
}


@; ----------------------------------------
@section[#:tag "integer"]{Integers}

@defmodule[binaryio/integer]

@defproc[(integer->bytes [val exact-integer?] [size exact-positive-integer?] [signed? boolean?]
                         [big-endian? boolean? #t]
                         [dest (and/c bytes? (not/c mutable?)) (make-bytes size)]
                         [start exact-nonnegative-integer? 0])
         bytes?]{

Like @racket[integer->integer-bytes], except that arbitrary
@racket[size] arguments are supported, and @racket[big-endian?]
defaults to @racket[#t] (network byte order) rather than the host byte
order.

@examples[
#:eval the-eval
(integer->bytes -1 3 #t)
(integer->bytes (expt 23 31) 18 #f)
]
}

@defproc[(bytes->integer [bstr bytes?] [signed? boolean?]
                         [big-endian? boolean? #t]
                         [start exact-nonnegative-integer? 0]
                         [end exact-nonnegative-integer? (bytes-length bstr)])
         exact-integer?]{

Like @racket[integer-bytes->integer], except that arbitrary
sizes---that is, @racket[(- end start)]---are supported, and
@racket[big-endian?] defaults to @racket[#t] (network byte order)
rather than the host byte order.
}

@defproc[(integer-bytes-length [val exact-integer?] [signed? boolean?])
         exact-nonnegative-integer?]{

Returns the number of bytes needed to encode @racket[val], including
the sign bit if @racket[signed?] is true.

@examples[
#:eval the-eval
(integer-bytes-length 127 #t)
(integer-bytes-length 128 #t)
]
}

@defproc[(integer-bytes-length<=? [val exact-integer?]
                                  [nbytes exact-nonnegative-integer?]
                                  [signed? boolean?])
         boolean?]{

Equivalent to @racket[(<= (integer-bytes-length val signed?) nbytes)],
but can be faster for small values of @racket[nbytes].
}

@defproc[(write-integer [val exact-integer?]
                        [size exact-positive-integer?]
                        [signed? boolean?]
                        [out output-port? (current-output-port)]
                        [big-endian? boolean? #t])
         void?]{

Writes the encoding of @racket[val] to @racket[out].

Equivalent to @racket[(write-bytes (integer->bytes val size signed? big-endian?) out)].
}

@defproc[(read-integer [size exact-positive-integer?]
                       [signed? boolean?]
                       [in input-port? (current-input-port)]
                       [big-endian? boolean? #t])
         exact-integer?]{

Reads @racket[size] bytes from @racket[in] and decodes it as an
integer. If fewer than @racket[size] bytes are available before the
end of input, an error is raised.

Equivalent to @racket[(bytes->integer (read-bytes* size in) signed? big-endian?)].
}


@; ----------------------------------------
@section[#:tag "float"]{Floating-point}

@defmodule[binaryio/float]

@defproc[(write-float [val real?]
                      [size (or/c 4 8)]
                      [out output-port? (current-output-port)]
                      [big-endian? boolean? #t])
         void?]{

Equivalent to @racket[(write-bytes (real->floating-point-bytes val size big-endian?) out)].
}

@defproc[(read-float [size (or/c 4 8)]
                     [in input-port? (current-input-port)]
                     [big-endian? boolean? #t])
         real?]{

Equivalent to @racket[(floating-point-bytes->real (read-bytes* size in) big-endian?)].
}


@; ----------------------------------------
@section[#:tag "binary-reader"]{Binary Reader}

@defmodule[binaryio/reader]

@history[#:added "1.1"]

@defproc[(make-binary-reader [in input-port?]
                             [#:limit limit (or/c exact-nonnegative-integer? #f) #f]
                             [#:error-handler error-handler (binary-reader-error-handler? #f) #f])
         binary-reader?]{

Creates a new @deftech{binary reader} that reads from @racket[in] with
an initial limit of @racket[limit] bytes.

The binary reader wraps the input port with the following additional
features:
@itemlist[

@item{Convenience functions for reading binary encodings of integers
and floating-point numbers of different lengths, endianness, etc.}

@item{The @racket[error-handler] hook for customizing error
message. See @racket[make-binary-reader-error-handler] for details.}

@item{Automatic handling of short reads. If @racket[in] returns
@racket[eof] or fewer bytes than requested in a read operation on the
binary reader, the @racket[error-handler] is used to raise an
error. Thus, for example, the caller of @racket[(b-read-bytes _br
_len)] can rely on receiving a bytestring of exactly @racket[_len]
bytes.}

@item{A stack of limits, maintained with @racket[b-push-limit] and
@racket[b-pop-limit]. On every read operation, the limits are
decremented by the number of bytes read. If a read operation requests
more bytes than the current limit, the @racket[error-handler] is
used to raise an error.}

]

Binary readers are not thread-safe. Be careful when interleaving uses
of a binary reader with direct uses of its input port. For example,
direct reads from @racket[in] do not count against limits imposed on
the binary reader.
}

@defproc[(binary-reader? [v any/c]) boolean?]{

Returns @racket[#t] if @racket[v] is a binary reader created by
@racket[make-binary-reader], @racket[#f] otherwise.
}

@defproc[(make-binary-reader-error-handler
          [#:error error-callback
           (or/c #f (->* [binary-reader? symbol? string?] [] #:rest list? none/c)) #f]
          [#:show-data? show-data?-callback (or/c #f (-> binary-reader? symbol? boolean?)) #f])
         binary-reader-error-handler?]{

Creates an error handler object for customizing the reporting of
binary reader errors.

@itemlist[

@item{When an error occurs, the @racket[error-callback] is called with
the binary reader, the name of the function that raised the error, and
a format string and arguments for the error message. If
@racket[error-callback] is @racket[#f], the @racket[error] procedure
is called instead (omitting the binary reader argument). The
@racket[error-callback] must escape, typically by throwing an
exception; if it returns an exception is raised.}

@item{When a short read occurs, the @racket[show-data?-callback]
determines whether the error message contains the data actually read.}

]}

@defproc[(binary-reader-error-handler? [v any/c]) boolean?]{

Returns @racket[#t] if @racket[v] is an error handler object created
by @racket[make-binary-reader-error-handler], @racket[#f] otherwise.
}


@defproc[(b-get-limit [br binary-reader?]) (or/c exact-nonnegative-integer? #f)]{

Returns @racket[br]'s current limit. The value @racket[#f] means no
limit; the idiom @racket[(or (b-get-limit br) +inf.0)] may be useful
for comparisons.
}

@defproc[(b-at-limit? [br binary-reader?]) boolean?]{

Returns @racket[#t] if @racket[(b-get-limit br)] is zero.
}

@defproc[(b-at-limit/eof? [br binary-reader?]) boolean?]{

Returns @racket[#t] if @racket[(b-get-limit br)] is zero or if peeking
on the underlying input port returns @racket[eof].
}

@defproc[(b-push-limit [br binary-reader?] [limit exact-nonnegative-integer?]) void?]{

Pushes a new limit on @racket[br]. If the new @racket[limit] is larger
than the current limit, an exception is raised.
}

@defproc[(b-pop-limit [br binary-reader?]) void?]{

Pops the current limit from @racket[br] and restores the previous
limit, decremented by the number of bytes read since the current limit
was pushed.
}

@defproc[(b-call/save-limit [br binary-reader?]
                            [proc (-> any)])
         any]{

Saves the current limit stack of @racket[br] and calls @racket[proc], restoring
@racket[br]'s limit stack when the call to @racket[proc] returns normally or
escapes.

@history[#:added "1.2"]}

@defproc[(b-check-exhausted [br binary-reader?] [what (or/c string? #f)])
         void?]{

Raises an exception unless @racket[(b-at-limit/eof? br)] is true. If
@racket[what] is a string, the text ``after reading @racket[what]'' is
included.
}

@deftogether[[
@defproc[(b-read-bytes [br binary-reader?]
                       [len exact-nonnegative-integer?])
         bytes?]
@defproc[(b-read-bytes! [br binary-reader?] [bs bytes?]
                        [start exact-nonnegative-integer? 0]
                        [end exact-nonnegative-integer? (bytes-length bs)])
         exact-nonnegative-integer?]
@defproc[(b-read-byte [br binary-reader?]) byte?]
@defproc[(b-read-integer [br binary-reader?]
                         [size exact-positive-integer?]
                         [signed? boolean?]
                         [big-endian? boolean? #t])
         exact-integer?]
@defproc[(b-read-float [br binary-reader?]
                       [size (or/c 4 8)]
                       [big-endian? boolean? #t])
         real?]
]]{

Read operations on binary readers. Note that @racket[b-read-bytes] etc
never return @racket[eof]; if fewer bytes than requested are available
before the end of input, the binary reader's short-read handler is
called to raise an exception. If @racket[br]'s current limit is
smaller than the number of bytes requested, @racket[br]'s long-read
handler is called to raise an exception.
}

@deftogether[[
@defproc[(b-read-be-int  [br binary-reader?] [size exact-positive-integer?])
         exact-integer?]
@defproc[(b-read-be-uint [br binary-reader?] [size exact-positive-integer?])
         exact-nonnegative-integer?]
@defproc[(b-read-le-int  [br binary-reader?] [size exact-positive-integer?])
         exact-integer?]
@defproc[(b-read-le-uint [br binary-reader?] [size exact-positive-integer?])
         exact-integer?]
]]{

Specialized versions of @racket[b-read-integer] for reading big-endian
and little-endian encodings of signed and unsigned integers,
respectively.
}

@defproc[(b-read-nul-terminated-bytes [br binary-reader?])
         bytes?]{

Reads bytes until a NUL byte is found, and returns the accumulated
bytes @emph{without} the NUL terminator. If no NUL terminator is found
before the current limit or the end of input is reached, the binary
reader's error handler is used to raise an error.
}

@defproc[(b-read-bytes-line+eol [br binary-reader?]
                                [eol-mode (or/c 'linefeed 'return 'return-linefeed 'any 'any-one)])
         (values bytes? bytes?)]{

Reades bytes until a line ending is found, as determined by
@racket[eol-mode]. Returns the line contents and the line ending as separate
byte strings. If no line ending is found before the current limit or the end of
input is reached, the binary reader's error handler is used to raise an error.

@history[#:added "1.2"]}

@defproc[(b-read-bytes-line [br binary-reader?]
                            [eol-mode (or/c 'linefeed 'return 'return-linefeed 'any 'any-one)])
         bytes?]{

Like @racket[b-read-bytes-line+eol] but does not return the line ending.

@history[#:added "1.2"]}

@; ----------------------------------------
@section[#:tag "fixup-port"]{Fixup Ports}

@history[#:added "1.1"]

@defmodule[binaryio/fixup-port]

@defproc[(open-fixup-port) fixup-port?]{

Creates a new fixup port. A fixup port acts as an output port that
writes to an internal buffer. It also supports a stack of
@emph{fixups}---locations in the output buffer where additional data
must be inserted later. The primary use case for fixups is
length-prefixed data, where the length is not known in advance.

Operations on fixup ports are not thread-safe.
}

@defproc[(fixup-port? [v any/c]) boolean?]{

Returns @racket[#t] if @racket[v] is a fixup port created by
@racket[open-fixup-port], @racket[#f] otherwise.
}

@defproc[(push-fixup [fp fixup-port?] [size (or/c exact-positive-integer? #f) #f])
         void?]{

Pushes a new fixup corresponding to the current location in the output
buffer. If @racket[size] is an integer, then @racket[size] bytes are
reserved for the fixup and its value must be exactly @racket[size]
bytes; otherwise the fixup's value may be any size. (Sized fixups may
have better performance than unsized fixups.)
}

@defproc[(pop-fixup [fp fixup-port?] [fixup (-> exact-nonnegative-integer? bytes?)])
         void?]{

Pops the current fixup and sets its value to the result of
@racket[(fixup _len)], where @racket[_len] is the number of bytes
(including subsequent fixup values) written to @racket[fp] since the
fixup was pushed.

If the fixup was created with size @racket[_size], then @racket[(fixup
_len)] must return exactly @racket[_size] bytes, otherwise an error is
raised.
}

@defproc[(fixup-port-flush [fp fixup-port?] [out output-port?]) void?]{

Writes the buffered output and fixups to @racket[out]. There must be
no pending fixups on @racket[fp]; otherwise an exception is raised.
}


@; ----------------------------------------
@section[#:tag "sbv"]{Short Bitvectors}

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

@; ----------------------------------------
@section[#:tag "bitport"]{Bitports}

@defmodule[binaryio/bitport]
@history[#:added "1.2"]

An @deftech{output bitport} is like an output string port
(@racket[open-output-bytes]), except that instead of accumulating bytes, it
accumulates bits and packs them into a byte string.

@defproc[(output-bitport? [v any/c]) boolean?]{

Returns @racket[#t] if @racket[v] is an output bitport, @racket[#f] otherwise.
}

@defproc[(open-output-bitport)
         output-bitport?]{

Creates a new empty output bitport.
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


@;; ============================================================
@(close-eval the-eval)
