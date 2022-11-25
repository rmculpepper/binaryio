;; Copyright 2022 Ryan Culpepper
;; Dual-licensed under Apache 2.0 and MIT terms.

#lang racket/base
(require racket/contract/base
         (only-in racket/base [exact-nonnegative-integer? nat?])
         "unchecked/bytes-bits.rkt")

(provide (contract-out
          [bytes-bit-length
           (-> bytes? nat?)]
          [bytes-bit-set?
           (->* [bytes? nat?] [boolean?] boolean?)]
          [bytes-set-bit!
           (->* [(and/c bytes? (not/c immutable?)) nat? boolean?] [boolean?] any)]
          [bytes-bits->string
           (->* [bytes?] [nat? (or/c #f nat?) boolean?] string?)]
          [string->bytes-bits
           (->* [(and/c string? #rx"^[01]*$")] [boolean?] bytes?)]))
