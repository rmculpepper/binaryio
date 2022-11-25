#lang info

;; ========================================
;; pkg info

(define collection "binaryio")
(define deps
  '(["base" #:version "6.3"]
    "binaryio-lib"
    "rackunit-lib"
    "math-lib"))
(define implies
  '("binaryio-lib"))
(define build-deps
  '("racket-doc"
    "scribble-lib"))

;; ========================================
;; collect info

(define name "binaryio")
(define scribblings
  '(["scribblings/binaryio.scrbl" (multi-page)]))
