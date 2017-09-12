#lang racket/base
(require rackunit
         binaryio/float
         racket/math
         math/flonum)
(provide (all-defined-out))

(define PRINT? #f)

(define (test-float val size be?)
  (define-values (in out) (make-pipe))
  (write-float val size out be?)
  (check-equal? (read-float size in be?) (real->double-flonum val) "write read roundtrip"))

;; For several constants and special values, test
;; - roundtripping via write-float and read-float


(for ([val (list 0.0 -0.0 pi +nan.0 +inf.0 -inf.0 +max.0 -max.0 +min.0 -min.0 epsilon.0)])
  (test-case (format "Double-float constant ~e" val)
    (when PRINT? (printf "testing double-float constant ~e\n" val))
    (test-float val 8 #t)
    (test-float val 8 #f)))

(for ([val (list 0.0f0 -0.0f0 pi.f +nan.f +inf.f -inf.f)])
  (test-case (format "single-float constant ~e" val)
    (when PRINT? (printf "testing single-float constant ~e\n" val))
    (test-float val 4 #t)
    (test-float val 4 #f)))

;; For many random floats between 0 and 1, exclusive, of varying sizes and endian-ness, test
;; - roundtripping via write-float and read-float

(for ([i (in-range 40)])
   (define val (random))
   (test-case (format "Random float ~e" val)
     (when PRINT? (printf "testing random float ~e\n" val))
     (test-float val 8 #t)
     (test-float val 8 #f)
     (test-float (real->single-flonum val) 4 #t)
     (test-float (real->single-flonum val) 4 #f)))
