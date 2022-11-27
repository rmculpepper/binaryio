;; Copyright 2019-2021 Ryan Culpepper
;; Dual-licensed under Apache 2.0 and MIT terms.

#lang racket/base
(require racket/contract/base
         (only-in racket/base [exact-nonnegative-integer? nat?])
         (only-in "bitvector.rkt" sbv?)
         (except-in "unchecked/bitport.rkt" bytes-bit-set?)
         "bytes-bits.rkt")

(define (bit? v) (or (eqv? v 0) (eqv? v 1)))

(provide output-bitport?
         bytes-bit-set?

         (contract-out
          [open-output-bitport
           (->* [] [boolean?] output-bitport?)]
          [output-bitport-partial
           (-> output-bitport? sbv?)]
          [output-bitport-write-bit
           (-> output-bitport? bit? void?)]
          [output-bitport-write-sbv
           (-> output-bitport? sbv? void?)]
          [output-bitport-get-output
           (->* [output-bitport?]
                [#:reset? boolean?
                 #:pad sbv?]
                (values bytes? nat?))]
          [output-bitport-pad
           (->* [output-bitport?]
                [#:pad sbv?]
                nat?)]))
