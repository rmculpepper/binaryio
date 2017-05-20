#lang racket/base
(require rackunit
         binaryio/integer)
(provide (all-defined-out))

(define (random-signed size)
  (- (random-unsigned size) (expt 2 (sub1 (* size 8)))))

(define (random-unsigned size)
  (if (zero? size)
      0
      (+ (random 256) (arithmetic-shift (random-unsigned (sub1 size)) 8))))

(define (test-rt val size signed? be?)
  (check-equal? (bytes->integer (integer->bytes val size signed? be?) signed? be?)
                val
                "integer->bytes->integer roundtrip"))

(define (test-extend val size extsize signed? be?)
  (define b1 (integer->bytes val extsize signed? be?))
  (define b2 (make-bytes extsize (if (negative? val) 255 0)))
  (let ([start (if be? (- extsize size) 0)])
    (integer->bytes val size signed? be? b2 start))
  (check-equal? (bytes->list b1) (bytes->list b2) "extend")
  (check-equal? b1 b2 "integer->bytes extend"))

(define (test-integer val size signed? be?)
  (test-rt val size signed? be?)
  (when (< size 8) (test-extend val size 8 signed? be?))
  (when (< size 16) (test-extend val size 16 signed? be?)))

(for ([size (in-range 1 16)])
  (for ([rsize (in-range 1 (add1 size))])
    (for ([i (in-range 20)])
      (define val (random-unsigned rsize))
      (eprintf "testing unsigned ~e, size ~s (~s)\n" val size rsize)
      (test-integer val size #f #t)
      (test-integer val size #f #f))))

(for ([size (in-range 1 16)])
  (for ([rsize (in-range 1 (add1 size))])
    (for ([i (in-range 20)])
      (define val (random-signed rsize))
      (eprintf "testing signed ~e, size ~s (~s)\n" val size rsize)
      (test-integer val size #t #t)
      (test-integer val size #t #f))))
