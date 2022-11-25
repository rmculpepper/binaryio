;; Copyright 2022 Ryan Culpepper
;; Dual-licensed under Apache 2.0 and MIT terms.

#lang racket/base
(provide bytes-bit-length
         bytes-bit-set?
         bytes-set-bit!
         bytes-bits->string
         string->bytes-bits)

;; ============================================================
;; Bytes

;; Bit index order: Consider the following byte vector:
;;   (bytes 1 3) = (bytes #b00000001 #b00000011)
;; How is it interpreted as a bit sequence?
;; Equivalently, how is a bit index interpreted?
;; - In this library, the sequence always starts with the first byte
;;   of the byte vector.
;; - There are two possibilities for the interpretation of bits within
;;   each byte. The example above is interpreted in each as follows:
;;   - Most Significant First  = [0 0 0 0  0 0 0 1  0 0 0 0  0 0 1 1]
;;   - Least Significant First = [1 0 0 0  0 0 0 0  1 1 0 0  0 0 0 0]
;; This library uses MSF indexing by default.

(define (bytes-bit-length bs) (* 8 (bytes-length bs)))

;; bytes-bit-set? : Bytes Nat [Boolean] -> Boolean
(define (bytes-bit-set? bs biti [msf? #t])
  (define bytei (quotient biti 8))
  (define bbiti (if msf? (- 7 (remainder biti 8)) (remainder biti 8)))
  (check-bit-index 'bytes-bit-set? bs biti bytei)
  (define b (bytes-ref bs bytei))
  (bitwise-bit-set? b bbiti))

;; bytes-set-bit! : Bytes Nat Boolean [Boolean] -> Void
(define (bytes-set-bit! bs biti one? [msf? #t])
  (define bytei (quotient biti 8))
  (define bbiti (if msf? (- 7 (remainder biti 8)) (remainder biti 8)))
  (check-bit-index 'bytes-set-bit! bs biti bytei)
  (define b (bytes-ref bs bytei))
  (define mask0 (arithmetic-shift 1 bbiti))
  (define b*
    (cond [one? (bitwise-ior b mask0)]
          [else (bitwise-and b (bitwise-not mask0))]))
  (bytes-set! bs bytei b*))

(define (check-bit-index who bs biti bytei)
  (define blen (bytes-length bs))
  (unless (< bytei blen)
    (raise-range-error who "bytes" "bit " biti 0 (sub1 (* 8 blen)))))

(define (bytes-bits->string bs [starti 0] [endi0 #f] [msf? #t])
  (define who 'bytes-bits->string)
  (define bblen (bytes-bit-length bs))
  (define endi (or endi0 bblen))
  (unless (<= 0 starti (add1 bblen))
    (raise-range-error who "bytes" "starting bit " starti 0 (add1 bblen)))
  (unless (<= starti endi (add1 bblen))
    (raise-range-error who "bytes" "ending bit " endi starti (add1 bblen)))
  (define s (make-string (- endi starti)))
  (for ([si (in-naturals)] [biti (in-range starti endi)])
    (string-set! s si (if (bytes-bit-set? bs biti msf?) #\1 #\0)))
  s)

(define (string->bytes-bits s [msf? #t])
  (define slen (string-length s))
  (define bslen (quotient (+ 7 slen) 8)) ;; slen/8 rounded up
  (define bs (make-bytes bslen 0))
  (for ([c (in-string s)] [biti (in-naturals)])
    (unless (eqv? c #\0)
      (bytes-set-bit! bs biti #t msf?)))
  bs)
