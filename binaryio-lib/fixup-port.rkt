#lang racket/base
(require racket/contract/base
         "unchecked/fixup-port.rkt")

(provide (contract-out
          [fixup-port?
           predicate/c]
          [open-fixup-port
           (-> fixup-port?)]
          [push-fixup
           (->* [fixup-port?] [(or/c exact-positive-integer? #f)] any)]
          [pop-fixup
           (-> fixup-port? (-> exact-nonnegative-integer? bytes?) any)]
          [fixup-port-flush
           (-> fixup-port? output-port? any)]))
