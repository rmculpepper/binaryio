;; Copyright 2019-2021 Ryan Culpepper
;; SPDX-License-Identifier: Apache-2.0 OR MIT

#lang racket/base
(require racket/contract/base
         (only-in racket/base [exact-nonnegative-integer? nat?])
         (only-in "bitvector.rkt" sbv?)
         (only-in "bitport.rkt" output-bitport?)
         "unchecked/prefixcode.rkt")

(define encode-table/c (or/c hash? vector? list?))
(define decode-tree/c any/c)
(define decode-error-handler/c (-> (or/c 'bad 'incomplete) nat? nat? any/c any))

(provide (contract-out
          [prefixcode-encode
           (->* [encode-table/c sequence?]
                [boolean? #:pad sbv?]
                (values bytes? nat?))]
          [prefixcode-encode!
           (-> output-bitport? encode-table/c sequence? void?)]
          [prefixcode-build-decode-tree
           (-> encode-table/c decode-tree/c)]
          [prefixcode-decode
           (->* [decode-tree/c bytes?]
                [nat? nat? boolean? #:end (or/c sbv? #f) #:handle-error decode-error-handler/c]
                bytes?)]
          [prefixcode-decode-list
           (->* [decode-tree/c bytes?]
                [nat? nat? boolean? #:end (or/c sbv? #f) #:handle-error decode-error-handler/c]
                list?)]
          [prefixcode-decode!
           (->* [(or/c output-port? procedure?) decode-tree/c bytes?]
                [nat? nat? boolean? #:end (or/c sbv? #f) #:handle-error decode-error-handler/c]
                any)]
          [prefixcode-decode1
           (->* [decode-tree/c bytes?]
                [nat? nat? boolean? #:end (or/c sbv? #f)]
                (values (or/c 'ok 'bad 'end 'incomplete) nat? any/c))]))
