#lang scribble/manual
@(require scribble/example
          (for-label racket/base racket/contract
                     binaryio/bytes
                     binaryio/integer
                     binaryio/float))

@(begin
  (define the-eval (make-base-eval))
  (the-eval '(require binaryio)))

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

Like @racket[read-bytes], but returns a bytestring of exactly
@racket[len] bytes. If fewer than @racket[len] bytes are available
before the end of input, an exception is raised.

@examples[
#:eval the-eval
(define-values (in out) (make-pipe))
(write-bytes #"abcde" out)
(close-output-port out)
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
@racket[size] arguments are supported, and the default byte order is
always big endian (network byte order) rather than system-dependent.

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
sizes---that is, @racket[(- end start)]---are supported, and the
default byte order is always big endian (network byte order) rather
than system-dependent.
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
@section[#:tag "float"]{Floating-point numbers}

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
