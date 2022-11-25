;; Copyright 2022 Ryan Culpepper
;; Dual-licensed under Apache 2.0 and MIT terms.

#lang racket/base
(require racket/contract/base
         (only-in racket/base [exact-nonnegative-integer? nat?])
         "unchecked/huffman.rkt")

(define encode-table/c (or/c hash? vector? list?))

(provide (contract-out
          [make-huffman-code
           (-> (or/c list? vector? hash?)
               encode-table/c)]))
