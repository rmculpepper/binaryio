#lang scribble/manual
@(require scribble/example
          (for-label racket/base racket/contract
                     binaryio/bitvector
                     binaryio/huffman
                     binaryio/prefixcode))

@(begin
  (define the-eval (make-base-eval))
  (the-eval '(require binaryio/bitvector binaryio/huffman binaryio/prefixcode)))

@title[#:tag "huffman"]{Huffman Codes}

@defmodule[binaryio/huffman]
@history[#:added "1.3"]

This module provides support for computing Huffman codes.

@defproc[(make-huffman-code [alphabet
                             (or/c (hash/c any/c rational?)
                                   (listof (cons/c any/c rational?))
                                   (vectorof rational?))])
         prefixcode-encode-table/c]{

Produces a prefix code encoder table (see @racket[prefixcode-encode]) based on
@racket[alphabet], which contains the encodable elements and their relative
frequencies. Elements with zero or negative weights are included in the code
book; negative weights are clipped to zero.

If the @racket[alphabet] consists only of exact integers, characters, and symbols, then
a @hyperlink["https://en.wikipedia.org/wiki/Canonical_Huffman_code"]{canonical
Huffman code} is constructed: alphabet elements having the same code length are sorted
and assigned sequential, ascending code values.

If @racket[alphabet] is a vector, the alphabet elements are the vector indexes,
and the resulting encode table is also represented as a vector. Otherwise, the
resulting encode table is represented as a hash table.

@examples[#:eval the-eval
(define hc
  (make-huffman-code
   (vector 2 1 1 1 1)))
(for ([code (in-vector hc)] [v (in-naturals)])
  (printf "~v ~a\n" v (sbv->string code)))
]}

@(close-eval the-eval)
