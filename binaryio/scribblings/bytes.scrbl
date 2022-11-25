#lang scribble/manual
@(require scribble/example
          (for-label racket/base racket/contract
                     binaryio/bytes))

@(begin
  (define the-eval (make-base-eval))
  (the-eval '(require binaryio)))

@; ----------------------------------------
@title[#:tag "bytes"]{Bytes}

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


@(close-eval the-eval)
