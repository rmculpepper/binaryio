#lang racket/base
(require rackunit
         binaryio/integer)
(provide (all-defined-out))

(define PRINT? #f)

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

(define (test-rw val size signed? be?)
  (define-values (in out) (make-pipe))
  (write-integer val size signed? out be?)
  (check-equal? (read-integer size signed? in be?) val))

(define (test-extend val size extsize signed? be?)
  (define b1 (integer->bytes val extsize signed? be?))
  (define b2 (make-bytes extsize (if (negative? val) 255 0)))
  (let ([start (if be? (- extsize size) 0)])
    (integer->bytes val size signed? be? b2 start))
  (check-equal? (bytes->list b1) (bytes->list b2) "extend")
  (check-equal? b1 b2 "integer->bytes extend"))

(define (test-integer val size signed? be?)
  (test-rt val size signed? be?)
  (test-rw val size signed? be?)
  (when (< size 8) (test-extend val size 8 signed? be?))
  (when (< size 16) (test-extend val size 16 signed? be?)))

(for ([size (in-range 1 16)])
  (for ([rsize (in-range 1 (add1 size))])
    (for ([i (in-range 20)])
      (define val (random-unsigned rsize))
      (test-case (format "unsigned ~e, size ~s (~s)" val size rsize)
        (when PRINT? (printf "testing unsigned ~e, size ~s (~s)\n" val size rsize))
        (test-integer val size #f #t)
        (test-integer val size #f #f)))))

(for ([size (in-range 1 16)])
  (for ([rsize (in-range 1 (add1 size))])
    (for ([i (in-range 20)])
      (define val (random-signed rsize))
      (test-case (format "signed ~e, size ~s (~s)" val size rsize)
        (when PRINT? (printf "testing signed ~e, size ~s (~s)\n" val size rsize))
        (test-integer val size #t #t)
        (test-integer val size #t #f)))))

;; ----------------------------------------

(define (random-bytes size)
  (define buf (make-bytes size))
  (for ([i (in-range size)]) (bytes-set! buf i (random 256)))
  buf)

(define (test-bib-rt b signed? be?)
  (check-equal? (integer->bytes (bytes->integer b signed? be?) (bytes-length b) signed? be?)
                b
                "bytes->integer->bytes roundtrip"))

(define (test-bytes-extend b extsize signed? be?)
  (define size (bytes-length b))
  (define neg? (and signed? (>= (bytes-ref b (if be? 0 (sub1 size))) 128)))
  (define ext (make-bytes (- extsize size) (if neg? 255 0)))
  (define b* (if be? (bytes-append ext b) (bytes-append b ext)))
  (check-equal? (bytes->integer b* signed? be?)
                (bytes->integer b signed? be?)
                "bytes extend"))

(define (test-bytes b signed? be?)
  (test-bib-rt b signed? be?)
  (when (< (bytes-length b) 8) (test-bytes-extend b 8 signed? be?))
  (when (< (bytes-length b) 16) (test-bytes-extend b 16 signed? be?)))

(for ([size (in-range 1 16)])
  (for ([i (in-range 20)])
    (define b (random-bytes size))
    (when PRINT? (printf "testing bytes (~s) ~e\n" size b))
    (test-case (format "bytes (~s) ~v" size b)
      (test-bytes b #t #t)
      (test-bytes b #t #f)
      (test-bytes b #f #t)
      (test-bytes b #f #f))))
