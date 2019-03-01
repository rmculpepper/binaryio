;; Copyright 2019 Ryan Culpepper
;; Dual-licensed under Apache 2.0 and MIT terms.

#lang racket/base
(require racket/contract/base
         "unchecked/reader.rkt")
(provide binary-reader?
         binary-reader-error-handler?
         (contract-out
          [make-binary-reader
           (->* [input-port?]
                [#:limit (or/c exact-nonnegative-integer? #f)
                 #:error-handler (or/c binary-reader-error-handler? error-handler/c #f)]
                binary-reader?)]
          [make-binary-reader-error-handler
           (->* []
                [#:error (or/c #f error-handler/c)
                 #:show-data? (or/c #f (-> binary-reader? symbol? boolean?))]
                binary-reader-error-handler?)]
          [b-get-limit
           (-> binary-reader? (or/c exact-nonnegative-integer? #f))]
          [b-at-limit?
           (-> binary-reader? boolean?)]
          [b-at-limit/eof?
           (-> binary-reader? boolean?)]
          [b-push-limit
           (-> binary-reader? exact-nonnegative-integer? void?)]
          [b-pop-limit
           (-> binary-reader? void?)]
          [b-check-exhausted
           (-> binary-reader? (or/c string? #f) void?)]

          [b-read-bytes!
           (->* [binary-reader? bytes?]
                [exact-nonnegative-integer? exact-nonnegative-integer?]
                exact-nonnegative-integer?)]
          [b-read-bytes
           (-> binary-reader? exact-nonnegative-integer? bytes?)]
          [b-read-byte
           (-> binary-reader? byte?)]
          [b-read-integer
           (->* [binary-reader? exact-positive-integer? boolean?]
                [boolean?]
                exact-integer?)]
          [b-read-float
           (->* [binary-reader? (or/c 4 8)]
                [boolean?]
                real?)]

          [b-read-be-int  (-> binary-reader? exact-positive-integer? exact-integer?)]
          [b-read-be-uint (-> binary-reader? exact-positive-integer? exact-integer?)]
          [b-read-le-int  (-> binary-reader? exact-positive-integer? exact-integer?)]
          [b-read-le-uint (-> binary-reader? exact-positive-integer? exact-integer?)]

          [b-read-nul-terminated-bytes (-> binary-reader? bytes?)]
          ))

(define error-handler/c
  (->* [binary-reader? symbol? string?] [] #:rest list? none/c))
