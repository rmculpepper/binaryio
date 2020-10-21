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


(for ([vals (list (list 0.0 -0.0 +nan.0 +inf.0 -inf.0)
                  (list pi +max.0 -max.0 +min.0 -min.0 epsilon.0))]
      [double? (list #t #f)]
      #:when #t
      [val vals])
  (test-case (format "Double-float constant ~e" val)
    (when PRINT? (printf "testing double-float constant ~e\n" val))
    (test-float val 8 #t)
    (test-float val 8 #f)
    (when double?
      (test-float val 4 #t)
      (test-float val 4 #f))))

;; For many random floats between 0 and 1, exclusive, of varying sizes and endian-ness, test
;; - roundtripping via write-float and read-float

(for ([i (in-range 40)])
   (define val (random))
   (test-case (format "Random float ~e" val)
     (when PRINT? (printf "testing random float ~e\n" val))
     (test-float val 8 #t)
     (test-float val 8 #f)))

(for ([i (in-range 40)])
  ;; Use integers to test 4-byte rountrip
  (define val (exact->inexact (random #e1e6)))
  (test-case (format "Random integer float ~e" val)
    (when PRINT? (printf "testing random float ~e\n" val))
    (test-float val 8 #t)
    (test-float val 8 #f)
    (test-float val 4 #t)
    (test-float val 4 #f)))
