;; Copyright 2017-2018 Ryan Culpepper
;; SPDX-License-Identifier: Apache-2.0 OR MIT

#lang racket/base
(provide (all-defined-out))

;; read-bytes* : InputPort Nat -> Bytes
(define (read-bytes* len [port (current-input-port)] #:who [who 'read-bytes*])
  (define r (read-bytes len port))
  (if (and (bytes? r) (= (bytes-length r) len))
      r
      (error who (string-append "unexpected end of input"
                                "\n  tried to read: ~s bytes"
                                "\n  available: ~s bytes"
                                "\n  received: ~e")
             len (if (bytes? r) (bytes-length r) 0) r)))

;; ----------------------------------------
;; Null-terminated bytes

(define (write-null-terminated-bytes src [port (current-output-port)]
                                     [start 0] [end (bytes-length src)]
                                     #:who [who 'write-null-terminated-bytes])
  (unless (<= start (bytes-length src))
    (raise-range-error who "bytes" "starting " start src 0 (bytes-length src)))
  (unless (<= start end (bytes-length src))
    (raise-range-error who "bytes" "ending " end src start (bytes-length src) 0))
  (for ([b (in-bytes src start end)] [i (in-range start end)])
    (when (zero? b)
      (error who "byte string contains null byte\n  byte string: ~e\n  at index: ~s" src i)))
  (write-bytes src port start end)
  (void (write-byte 0 port)))

(define (read-null-terminated-bytes [port (current-input-port)]
                                    #:limit [limit +inf.0]
                                    #:who [who 'read-null-terminated-bytes])
  (define out (open-output-bytes))
  (define (err/limit)
    (error who (string-append "limit reached before null terminator"
                              "\n  limit: ~s bytes"
                              "\n  received: ~e")
           limit (get-output-bytes out)))
  (define (err/eof)
    (let ([b (get-output-bytes out)])
      (error who (string-append "unexpected end of input before null terminator"
                                "\n  available: ~s bytes"
                                "\n  received: ~e")
             (bytes-length b) b)))
  (let loop ([i 0])
    (unless (< i limit) (err/limit))
    (define next (read-byte port))
    (cond [(eof-object? next) (err/eof)]
          [(zero? next) (get-output-bytes out)]
          [else (begin (write-byte next out) (loop (add1 i)))])))

;; if limit = +inf, then could also use regexp-match:
;;   (regexp-match #"\0" port 0 #f match-out), (get-output-bytes match-out)
;; FIXME: test which is faster
