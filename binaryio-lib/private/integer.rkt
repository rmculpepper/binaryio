#lang racket/base
(require "bytes.rkt")
(provide integer-bytes-length
         integer-bytes-length<=?

         integer->bytes
         bytes->integer

         write-integer
         read-integer)

;; ============================================================
;; Internal

;; quotient/round-up : Nat Nat -> Nat
(define (quotient/round-up n d)
  (+ (quotient n d) (if (zero? (remainder n d)) 0 1)))


;; ============================================================
;; Length calculation

(define (int-bytes-length val)
  (cond [(<= (- (expt 2 7))   val  (sub1 (expt 2 7)))  1]
        [(<= (- (expt 2 15))  val  (sub1 (expt 2 15))) 2]
        [(<= (- (expt 2 23))  val  (sub1 (expt 2 23))) 3]
        [(<= (- (expt 2 31))  val  (sub1 (expt 2 31))) 4]
        [else
         (define val-nbits (add1 (integer-length val))) ;; +1 for sign bit
         (quotient/round-up val-nbits 8)]))

(define (uint-bytes-length val)
  (cond [(<= 0  val  (sub1 (expt 2 8)))  1]
        [(<= 0  val  (sub1 (expt 2 16))) 2]
        [(<= 0  val  (sub1 (expt 2 24))) 3]
        [(<= 0  val  (sub1 (expt 2 32))) 4]
        [else
         (define val-nbits (integer-length val)) ;; no sign bit
         (quotient/round-up val-nbits 8)]))

(define (integer-bytes-length val signed?)
  (if signed? (int-bytes-length val) (uint-bytes-length val)))


;; ============================================================
;; Length predicate

(define (int-fits-bytes? val size)
  (case size ;; for common cases, precompute & avoid bignum alloc (8, maybe 4)
    [(1) (<= (- (expt 2 7))   val  (sub1 (expt 2 7)))]
    [(2) (<= (- (expt 2 15))  val  (sub1 (expt 2 15)))]
    [(3) (<= (- (expt 2 23))  val  (sub1 (expt 2 23)))]
    [(4) (<= (- (expt 2 31))  val  (sub1 (expt 2 31)))]
    [(8) (<= (- (expt 2 63))  val  (sub1 (expt 2 63)))]
    [else
     #|
     (let ([nbits-1 (sub1 (arithmetic-shift size 3))])
       (<= (- (arithmetic-shift 1 nbits-1))
           val
           (sub1 (arithmetic-shift 1 nbits-1))))
     |#
     ;; use integer-length to avoid bignum alloc for range (FIXME: test speed)
     (define nbits (arithmetic-shift size 3))
     (define val-nbits (add1 (integer-length val))) ;; +1 for sign bit
     (<= val-nbits nbits)]))

(define (uint-fits-bytes? val size)
  (case size ;; for common cases, precompute & avoid bignum alloc (8, maybe 4)
    [(1) (<= 0  val  (sub1 (expt 2 8)))]
    [(2) (<= 0  val  (sub1 (expt 2 16)))]
    [(3) (<= 0  val  (sub1 (expt 2 24)))]
    [(4) (<= 0  val  (sub1 (expt 2 32)))]
    [(8) (<= 0  val  (sub1 (expt 2 64)))]
    [else
     #|
     (let ([nbits (arithmetic-shift size 3)])
       (<= 0 val (sub1 (arithmetic-shift 1 nbits))))
     |#
     ;; use integer-length to avoid bignum alloc for range (FIXME: test speed)
     ;; another idea: test (val >> nbits) is zero
     (and (<= 0 val)
          (let ([nbits (arithmetic-shift size 3)]
                [val-nbits (integer-length val)])
            (and (<= 0 val) (<= val-nbits nbits))))]))

(define (integer-bytes-length<=? val size signed?)
  (if signed? (int-fits-bytes? val size) (uint-fits-bytes? val size)))

;; ----------------------------------------

(define (error/no-fit who size val signed?)
  (error who (string-append "integer does not fit into requested ~a bytes"
                            "\n  integer: ~e"
                            "\n  requested bytes: ~e")
         (if signed? "signed" "unsigned") val size))

;; ============================================================

(define (integer->bytes val size signed? [big-endian? #t]
                        [dest (make-bytes size)] [start 0]
                        #:who [who 'integer->bytes])
  (unless (<= (+ start size) (bytes-length dest))
    (error who (string-append "byte string length is shorter than starting position plus size"
                              "\n  byte string length: ~s"
                              "\n  starting position: ~s"
                              "\n  size: ~s")
           (bytes-length dest) start size))
  (unless (integer-bytes-length<=? val size signed?)
    (error/no-fit who size val signed?))
  (case size
    [(2 4 8) (integer->integer-bytes val size signed? big-endian? dest start)]
    [else
     ;; Currently (2017-05) Racket src comments say bitwise-bit-field
     ;; is slow for negative bignums, so convert to unsigned with
     ;; equivalent bit pattern.
     (cond [(or (fixnum? val) (not (negative? val)))
            (integer->bytes* val size signed? big-endian? dest start)]
           [else
            (define val* (+ (arithmetic-shift 1 (arithmetic-shift size 3)) val))
            (integer->bytes* val* size #f big-endian? dest start)])]))

(define (integer->bytes* val size signed? big-endian? dest start)
  (for ([i (in-range size)])
    (define desti (+ start (if big-endian? (- size i 1) i)))
    (define biti (* i 8))
    (bytes-set! dest desti (bitwise-bit-field val biti (+ biti 8))))
  dest)

;; ----------------------------------------

(define (bytes->integer src signed? [big-endian? #t]
                        [start 0] [end (bytes-length src)]
                        #:who [who 'bytes->integer])
  (unless (< start (bytes-length src))
    (raise-range-error who "bytes" "starting " start src 0 (sub1 (bytes-length src))))
  (unless (<= start end (bytes-length src))
    (raise-range-error who "bytes" "ending " end src start (sub1 (bytes-length src)) 0))
  (define size (- end start))
  (case size
    [(2 4 8)
     (integer-bytes->integer src signed? big-endian? start end)]
    [(0) 0]
    [else
     (define (src-index i) (+ start (if big-endian? i (- size i 1))))
     (define n0 (if (and signed? (>= (bytes-ref src (src-index 0)) 128)) -1 0))
     (for/fold ([acc n0]) ([i (in-range size)])
       (+ (bytes-ref src (src-index i)) (arithmetic-shift acc 8)))]))


;; ============================================================

(define (write-integer val size signed? [port (current-output-port)]
                       [big-endian? #t] #:who [who 'write-integer])
  (void (write-bytes (integer->bytes val size signed? big-endian? #:who who) port)))

(define (read-integer size signed? [port (current-input-port)]
                      [big-endian? #t] #:who [who 'read-integer])
  (let ([src (read-bytes* size port #:who who)])
    (bytes->integer src signed? big-endian?)))
