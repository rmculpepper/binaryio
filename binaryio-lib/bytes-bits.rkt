;; Copyright 2022 Ryan Culpepper
;; SPDX-License-Identifier: Apache-2.0 OR MIT

#lang racket/base
(require racket/contract/base
         (only-in racket/base [exact-nonnegative-integer? nat?])
         (only-in "bitvector.rkt" sbv?)
         "unchecked/bytes-bits.rkt")

(provide (contract-out
          [bytes-bit-length
           (-> bytes? nat?)]
          [bytes-bit-set?
           (->* [bytes? nat?] [boolean?] boolean?)]
          [bytes-set-bit!
           (->* [(and/c bytes? (not/c immutable?)) nat? boolean?] [boolean?] any)]
          [bytes-bits->sbv
           (->* [bytes?] [nat? (or/c #f nat?) boolean?] sbv?)]
          [bytes-bits->string
           (->* [bytes?] [nat? (or/c #f nat?) boolean?] string?)]
          [string->bytes-bits
           (->* [(and/c string? #rx"^[01]*$")] [boolean?] bytes?)]))
