#lang scribble/manual
@(require scribble/example
          (for-label racket/base racket/contract
                     binaryio/bytes
                     binaryio/integer
                     binaryio/float
                     binaryio/reader))

@; ----------------------------------------
@title[#:tag "binary-reader"]{Binary Reader}

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
