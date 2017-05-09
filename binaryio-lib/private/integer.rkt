#lang racket/base
(require "common.rkt")
(provide integer->bytes
         bytes->integer

         int1?  int2?  int3?  int4?  int8?
         uint1? uint2? uint3? uint4? uint8?

         integer-fits-bytes?

         write-int
         write-uint
         write-le-int
         write-le-uint

         read-int
         read-uint
         read-le-int
         read-le-uint)


;; ============================================================
;; Internal

;; quotient/round-up : Nat Nat -> Nat
(define (quotient/round-up n d)
  (+ (quotient n d) (if (zero? (remainder n d)) 0 1)))

(define (byte->int1 b)
  (if (>= b 128) (- b 256) b))


;; ============================================================
;; Predicates

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

(define (int1? val) (int-fits-bytes? val 1))
(define (int2? val) (int-fits-bytes? val 2))
(define (int3? val) (int-fits-bytes? val 3))
(define (int4? val) (int-fits-bytes? val 4))
(define (int8? val) (int-fits-bytes? val 8))

;; ----------------------------------------

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
     (and (<= 0 val)
          (let ([nbits (arithmetic-shift size 3)]
                [val-nbits (integer-length val)])
            (and (<= 0 val) (<= val-nbits nbits))))]))

(define (uint1? val) (uint-fits-bytes? val 1))
(define (uint2? val) (uint-fits-bytes? val 2))
(define (uint3? val) (uint-fits-bytes? val 3))
(define (uint4? val) (uint-fits-bytes? val 4))
(define (uint8? val) (uint-fits-bytes? val 8))

;; ----------------------------------------

(define (integer-fits-bytes? val size [signed? #t])
  (if signed? (int-fits-bytes? val size) (uint-fits-bytes? val size)))

;; ----------------------------------------

(define (check-int who size val)
  (when size
    (unless (int-fits-bytes? val size)
      (error/no-fit who size val #t))))

(define (check-uint who size val)
  (when size
    (unless (uint-fits-bytes? val size)
      (error/no-fit who size val #f))))

(define (error/no-fit who size val signed?)
  (error who (string-append "integer does not fit into requested ~a bytes"
                            "\n  integer: ~e"
                            "\n  requested bytes: ~e")
         (if signed? "signed" "unsigned") val size))

;; ============================================================

(define (integer->bytes val size signed? big-endian?)
  (case size
    [(2 4 8) (integer->integer-bytes val size signed? big-endian?)]
    [(#f)
     (define bits-needed
       (max 1 (+ (integer-length val) (if signed? 1 0))))
     (integer->bytes val (quotient/round-up bits-needed 8) signed? big-endian?)]
    [else
     (if signed?
         (check-int 'integer->bytes size val)
         (check-uint 'integer->bytes size val))
     (define buf (make-bytes size 0))
     (for ([i (in-range size)])
       (define bufi (if big-endian? (- size i 1) i))
       (define biti (* i 8))
       (bytes-set! buf bufi (bitwise-bit-field val biti (+ biti 8))))
     buf]))

(define (bytes->integer buf signed? big-endian?)
  (case (bytes-length buf)
    [(2 4 8)
     (integer-bytes->integer buf signed? big-endian?)]
    [(0) 0]
    [else
     (define n0 (if (and signed? (>= (bytes-ref buf 0) 128)) -1 0))
     (cond [big-endian?
            (for/fold ([acc n0]) ([b (in-bytes buf)])
              (+ b (arithmetic-shift acc 8)))]
           [else ;; little-endian
            (for/fold ([acc n0]) ([b (in-bytes buf (sub1 (bytes-length buf)) -1 -1)])
              (+ b (arithmetic-shift acc 8)))])]))


;; ----------------------------------------
;; Network order (ie, big-endian)

(define (write-int val size [port (current-output-port)])
  (check-int 'write-int size val)
  (void (write-bytes (integer->bytes val size #t #t) port)))
(define (write-uint val size [port (current-output-port)])
  (check-uint 'write-uint size val)
  (void (write-bytes (integer->bytes val size #f #t) port)))

(define (read-int size [port (current-input-port)])
  (bytes->integer (-read-bytes 'read-int size port) #t #t))
(define (read-uint size [port (current-input-port)])
  (bytes->integer (-read-bytes 'read-uint size port) #f #t))

;; ----------------------------------------
;; Little-endian

(define (write-le-int val size [port (current-output-port)])
  (check-int 'write-le-int size val)
  (void (write-bytes (integer->bytes val size #t #f) port)))
(define (write-le-uint val size [port (current-output-port)])
  (check-uint 'write-le-uint size val)
  (void (write-bytes (integer->bytes val size #f #f) port)))

(define (read-le-int size [port (current-input-port)])
  (bytes->integer (-read-bytes 'read-le-int size port) #t #f))
(define (read-le-uint size [port (current-input-port)])
  (bytes->integer (-read-bytes 'read-le-uint size port) #f #f))
