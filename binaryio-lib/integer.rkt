;; Copyright 2017-2018 Ryan Culpepper
;; SPDX-License-Identifier: Apache-2.0 OR MIT

#lang racket/base
(require racket/contract/base
         "unchecked/integer.rkt")

(provide (contract-out

          [integer-bytes-length
           (-> exact-integer? boolean?
               exact-nonnegative-integer?)]
          [integer-bytes-length<=?
           (-> exact-integer? exact-positive-integer? boolean?
               boolean?)]

          [integer->bytes
           (->* [exact-integer? exact-positive-integer? boolean?]
                [boolean? bytes? exact-nonnegative-integer? #:who symbol?]
                bytes?)]
          [bytes->integer
           (->* [bytes? boolean?]
                [boolean? exact-nonnegative-integer? exact-nonnegative-integer? #:who symbol?]
                exact-integer?)]

          [write-integer
           (->* [exact-integer? exact-positive-integer? boolean?]
                [output-port? boolean? #:who symbol?]
                void?)]
          [read-integer
           (->* [exact-positive-integer? boolean?]
                [input-port? boolean? #:who symbol?]
                exact-integer?)]
          ))
