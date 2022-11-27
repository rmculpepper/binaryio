#lang scribble/manual
@(require scribble/example)

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
@include-section["bytes.scrbl"]
@include-section["integer.scrbl"]
@include-section["float.scrbl"]
@include-section["reader.scrbl"]
@include-section["fixup-port.scrbl"]
@include-section["bitvector.scrbl"]
@include-section["bitport.scrbl"]
@include-section["bytes-bits.scrbl"]
@include-section["prefixcode.scrbl"]
@include-section["huffman.scrbl"]
