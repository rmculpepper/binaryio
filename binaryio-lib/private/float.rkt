#lang racket/base
(require "bytes.rkt")
(provide write-float
         read-float)

;; ============================================================
;; Read and write

(define (write-float val size [port (current-output-port)]
                     [big-endian? #t] #:who [who 'write-float])
  (void (write-bytes (real->floating-point-bytes val size big-endian?) port)))

(define (read-float size [port (current-input-port)]
                    [big-endian? #t] #:who [who 'read-float])
  (floating-point-bytes->real (read-bytes* size port #:who who) big-endian?))
