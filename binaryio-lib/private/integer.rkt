#lang racket/base
(provide integer->bytes
         bytes->integer

         int1?  int2?  int3?  int4?  int8?  make-intN?
         uint1? uint2? uint3? uint4? uint8? make-uintN?

         write-int1
         write-int2
         write-int3
         write-int4
         write-int8
         write-intN

         write-uint1
         write-uint2
         write-uint3
         write-uint4
         write-uint8
         write-uintN

         read-int1
         read-int2
         read-int3
         read-int4
         read-int8
         read-intN

         read-uint1
         read-uint2
         read-uint3
         read-uint4
         read-uint8
         read-uintN

         write-le-int1
         write-le-int2
         write-le-int3
         write-le-int4
         write-le-int8
         write-le-intN

         write-le-uint1
         write-le-uint2
         write-le-uint3
         write-le-uint4
         write-le-uint8
         write-le-uintN

         read-le-int1
         read-le-int2
         read-le-int3
         read-le-int4
         read-le-int8
         read-le-intN

         read-le-uint1
         read-le-uint2
         read-le-uint3
         read-le-uint4
         read-le-uint8
         read-le-uintN)


;; ============================================================
;; Internal

;; -read-bytes : InputPort Nat -> Bytes
(define (-read-bytes who port len)
  (define r (read-bytes len port))
  (if (and (bytes? r) (= (bytes-length r) len))
      r
      (error/insufficient who port len r)))

;; FIXME: make custom exn struct
(define (error/insufficient who port len r)
  (error who
         "unexpected end of input\n  tried to read: ~s bytes\n  available: ~s bytes\n  received: ~e"
         len (if (bytes? r) (bytes-length r) 0) r))

;; quotient/round-up : Nat Nat -> Nat
(define (quotient/round-up n d)
  (+ (quotient n d) (if (zero? (remainder n d)) 0 1)))

(define (byte->int1 b)
  (if (>= b 128) (- b 256) b))


;; ============================================================
;; Predicates

(define-syntax-rule (mkintN? nbytes)
  (let* ([nbits (* nbytes 8)]
         [hi  (- (expt 2 (sub1 nbits)) 1)]
         [low (- (expt 2 (sub1 nbits)))])
    (lambda (x) (and (exact-integer? x) (<= low x hi)))))

(define-syntax-rule (mkuintN? nbytes)
  (let* ([nbits (* nbytes 8)]
         [hi (- (expt 2 nbits) 1)])
    (lambda (x) (and (exact-integer? x) (<= 0 x hi)))))

(define int1? (mkintN? 8))
(define int2? (mkintN? 16))
(define int3? (mkintN? 24))
(define int4? (mkintN? 32))
(define int8? (mkintN? 64))
(define (make-intN? n) (mkintN? n))

(define uint1? (mkuintN? 8))
(define uint2? (mkuintN? 16))
(define uint3? (mkuintN? 24))
(define uint4? (mkuintN? 32))
(define uint8? (mkuintN? 64))
(define (make-uintN? n) (mkuintN? n))


;; ============================================================

(define (integer->bytes val size signed? big-endian?)
  (case size
    [(2 4 8) (integer->integer-bytes val size signed? big-endian?)]
    [(#f)
     (define bits-needed
       (max 1 (+ (integer-length val) (if signed? 1 0))))
     (integer->bytes val (quotient/round-up bits-needed 8) signed? big-endian?)]
    [else
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

(define (write-int* who port size val signed? big-endian?)
  (void (write-bytes (integer->bytes val size signed? big-endian?) port)))

(define (read-int* who port size signed? big-endian?)
  (bytes->integer (-read-bytes who size port) signed? big-endian?))

(define-syntax-rule (defw write-X (pre-arg ...) size signed? big-endian?)
  (define (write-X pre-arg ... val [port (current-output-port)])
    (write-int* 'write-X port size val signed? big-endian?)))

(define-syntax-rule (defr read-X (pre-arg ...) size signed? big-endian?)
  (define (read-X pre-arg ... [port (current-input-port)])
    (read-int* 'read-X port size signed? big-endian?)))


;; ============================================================
;; Readers and Writers

;; ----------------------------------------
;; Network byte-order (ie, big-endian)

(defw write-int1 () 1 #t #t)
(defw write-int2 () 2 #t #t)
(defw write-int3 () 3 #t #t)
(defw write-int4 () 4 #t #t)
(defw write-int8 () 8 #t #t)
(defw write-intN (n) n #t #t)

(defw write-uint1 () 1 #f #t)
(defw write-uint2 () 2 #f #t)
(defw write-uint3 () 3 #f #t)
(defw write-uint4 () 4 #f #t)
(defw write-uint8 () 8 #f #t)
(defw write-uintN (n) n #f #t)

(defr read-int1 () 1 #t #t)
(defr read-int2 () 2 #t #t)
(defr read-int3 () 3 #t #t)
(defr read-int4 () 4 #t #t)
(defr read-int8 () 8 #t #t)
(defr read-intN (n) n #t #t)

(defr read-uint1 () 1 #f #t)
(defr read-uint2 () 2 #f #t)
(defr read-uint3 () 3 #f #t)
(defr read-uint4 () 4 #f #t)
(defr read-uint8 () 8 #f #t)
(defr read-uintN (n) n #f #t)


;; ----------------------------------------
;; Little-endian

(defw write-le-int1 () 1 #t #f)
(defw write-le-int2 () 2 #t #f)
(defw write-le-int3 () 3 #t #f)
(defw write-le-int4 () 4 #t #f)
(defw write-le-int8 () 8 #t #f)
(defw write-le-intN (n) n #t #f)

(defw write-le-uint1 () 1 #f #f)
(defw write-le-uint2 () 2 #f #f)
(defw write-le-uint3 () 3 #f #f)
(defw write-le-uint4 () 4 #f #f)
(defw write-le-uint8 () 8 #f #f)
(defw write-le-uintN (n) n #f #f)

(defr read-le-int1 () 1 #t #f)
(defr read-le-int2 () 2 #t #f)
(defr read-le-int3 () 3 #t #f)
(defr read-le-int4 () 4 #t #f)
(defr read-le-int8 () 8 #t #f)
(defr read-le-intN (n) n #t #f)

(defr read-le-uint1 () 1 #f #f)
(defr read-le-uint2 () 2 #f #f)
(defr read-le-uint3 () 3 #f #f)
(defr read-le-uint4 () 4 #f #f)
(defr read-le-uint8 () 8 #f #f)
(defr read-le-uintN (n) n #f #f)
