#lang racket/base
(require "common.rkt")
(provide write-float
         read-float

         write-le-float
         read-le-float)

;; ============================================================
;; Readers and Writers

;; ----------------------------------------
;; Network byte-order (ie, big-endian)

(define (write-float val size [port (current-output-port)])
  (void (write-bytes (real->floating-point-bytes val size #t) port)))

(define (read-float size [port (current-input-port)])
  (floating-point-bytes->real (-read-bytes 'read-float size port) #t))

;; ----------------------------------------
;; Little-endian

(define (write-le-float val size [port (current-output-port)])
  (void (write-bytes (real->floating-point-bytes val size #f) port)))

(define (read-float size [port (current-input-port)])
  (floating-point-bytes->real (-read-bytes 'read-float size port) #f))
