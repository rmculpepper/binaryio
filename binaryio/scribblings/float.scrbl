#lang scribble/manual
@(require scribble/example
          (for-label racket/base racket/contract
                     binaryio/bytes
                     binaryio/float))

@; ----------------------------------------
@title[#:tag "float"]{Floating-point}

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
