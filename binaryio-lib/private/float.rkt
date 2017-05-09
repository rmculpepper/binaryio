#lang racket/base
(require "common.rkt")
(provide write-float4
         write-float8

         read-float4
         read-float8

         write-le-float4
         write-le-float8

         read-le-float4
         read-le-float8)


;; ============================================================
;; Internal

;; quotient/round-up : Nat Nat -> Nat
(define (quotient/round-up n d)
  (+ (quotient n d) (if (zero? (remainder n d)) 0 1)))

(define (byte->int1 b)
  (if (>= b 128) (- b 256) b))


;; ============================================================

(define (write-float* who port size val signed? big-endian?)
  (void (write-bytes (real->floating-point-bytes val size big-endian?) port)))

(define (read-float* who port size signed? big-endian?)
  (floating-point-bytes->real (-read-bytes who size port) big-endian?))

(define-syntax-rule (defw write-X (pre-arg ...) size big-endian?)
  (define (write-X pre-arg ... val [port (current-output-port)])
    (write-int* 'write-X port size val big-endian?)))

(define-syntax-rule (defr read-X (pre-arg ...) size big-endian?)
  (define (read-X pre-arg ... [port (current-input-port)])
    (read-int* 'read-X port size big-endian?)))


;; ============================================================
;; Readers and Writers

;; ----------------------------------------
;; Network byte-order (ie, big-endian)

(defw write-float4 () 4 #t)
(defw write-float8 () 8 #t)

(defr read-float4 () 4 #t)
(defr read-float8 () 8 #t)

;; ----------------------------------------
;; Little-endian

(defw write-le-float4 () 4 #f)
(defw write-le-float8 () 8 #f)

(defr read-le-float4 () 4 #f)
(defr read-le-float8 () 8 #f)
