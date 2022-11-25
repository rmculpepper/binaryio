#lang scribble/manual
@(require scribble/example
          (for-label racket/base racket/contract
                     binaryio/bytes
                     binaryio/integer))

@(begin
  (define the-eval (make-base-eval))
  (the-eval '(require binaryio)))

@; ----------------------------------------
@title[#:tag "integer"]{Integers}

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

@(close-eval the-eval)
