;; Copyright 2017-2018 Ryan Culpepper
;; Dual-licensed under Apache 2.0 and MIT terms.

#lang racket/base
(require racket/contract/base
         "private/float.rkt")

(provide (contract-out
          [write-float
           (->* [real? (or/c 4 8)]
                [output-port? boolean? #:who symbol?]
                void?)]
          [read-float
           (->* [(or/c 4 8)]
                [input-port? boolean? #:who symbol?]
                real?)]
          ))
