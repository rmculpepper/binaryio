;; Copyright 2019-2021 Ryan Culpepper
;; Dual-licensed under Apache 2.0 and MIT terms.

#lang racket/base
(require racket/contract/base
         (only-in racket/base [exact-nonnegative-integer? nat?])
         "unchecked/bitvector.rkt")

(define (sbv? v) (exact-nonnegative-integer? v))
(define (bit? v) (or (eqv? v 0) (eqv? v 1)))

(provide SBV-LENGTH-BITS
         SBV-LENGTH-BOUND
         empty-sbv
         sbv?
         canonical-sbv?

         (contract-out
          [make-sbv (-> nat? nat? sbv?)]
          [make-be-sbv (-> nat? nat? sbv?)]
          [sbv-empty? (-> sbv? boolean?)]
          [sbv-length (-> sbv? nat?)]
          [sbv-bits (-> sbv? nat?)]
          [sbv-bit-field (-> sbv? nat? nat? nat?)]
          [sbv-slice (-> sbv? nat? nat? sbv?)]
          [sbv-shift (-> sbv? exact-integer? sbv?)]
          [sbv-bit-set? (-> sbv? nat? boolean?)]
          [sbv-ref (-> sbv? nat? bit?)]
          [sbv-car (-> sbv? bit?)]
          [sbv-cdr (-> sbv? sbv?)]
          [sbv-cons (-> bit? sbv? sbv?)]
          [sbv-append (->* [] #:rest (listof sbv?) sbv?)]
          [sbv-reverse (-> sbv? sbv?)]
          [sbv-prefix? (-> sbv? sbv? boolean?)]
          [sbv->string (-> sbv? string?)]
          [string->sbv (-> (and/c string? #rx"^[01]*$") sbv?)]))
