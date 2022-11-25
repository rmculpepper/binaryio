#lang scribble/manual
@(require scribble/example
          (for-label racket/base racket/contract
                     binaryio/fixup-port))

@; ----------------------------------------
@title[#:tag "fixup-port"]{Fixup Ports}

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
