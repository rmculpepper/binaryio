;; Copyright 2019-2021 Ryan Culpepper
;; Dual-licensed under Apache 2.0 and MIT terms.

#lang racket/base
(require racket/match
         "bitvector.rkt")
(provide open-output-bitport
         output-bitport?
         output-bitport-partial
         output-bitport-write-bit
         output-bitport-write-sbv
         output-bitport-get-output
         output-bitport-pad

         bytes-bit-set?)

;; ============================================================
;; Output Bitport

;; A OutputBitport is (output-bitport ByteOutputPort ShortBitvector Nat)
(struct output-bitport (out partial) #:mutable)

(define (open-output-bitport)
  (output-bitport (open-output-bytes) empty-sbv))

(define (output-bitport-write-bit bb bit)
  (output-bitport-write-sbv bb (make-sbv bit 1)))

(define (output-bitport-write-sbv bb sbv)
  (match-define (output-bitport out partial) bb)
  (define partial* (sbv-append partial sbv))
  (set-output-bitport-partial! bb (-flush-partial partial* out)))

(define (-flush-partial partial out)
  (define len (sbv-length partial))
  (define blen (quotient len 8))
  (for ([i (in-range blen)])
    (define flush-byte (sbv-bit-field partial (* i 8) (* (add1 i) 8)))
    (define flush-byte* (reverse-byte flush-byte))
    (write-byte flush-byte* out))
  (sbv-shift partial (* blen -8)))

;; output-bitport-get-output : OutputBitPort -> (values Bytes Nat)
;; Returns bytes and end bit index.
(define (output-bitport-get-output bb #:reset? [reset? #f] #:pad [pad-sbv empty-sbv])
  (match-define (output-bitport out partial) bb)
  (define padlen (output-bitport-pad bb #:pad pad-sbv))
  (define bs (get-output-bytes out reset?))
  (define end (- (* 8 (bytes-length bs)) padlen))
  (unless (or reset? (zero? padlen))
    ;; This doesn't erase the padding byte, but future operations will overwrite it.
    ;; (There is no operation that gets out's bytes w/o padding.)
    (file-position out (sub1 (file-position out))))
  (when reset? (set-output-bitport-partial! bb empty-sbv))
  (values bs end))

(define (output-bitport-pad bb #:pad [pad-sbv empty-sbv])
  (match-define (output-bitport out partial) bb)
  (define len (sbv-length partial))
  (define padlen (- (* (quotient (+ len 7) 8) 8) len))
  (output-bitport-write-sbv bb (make-sbv (sbv-bit-field pad-sbv 0 padlen) padlen))
  (unless (sbv-empty? (output-bitport-partial bb))
    (error 'output-bitport-pad "internal error: non-empty partial!"))
  padlen)

;; ============================================================
;; Input

(define (bytes-bit-set? bs biti)
  (define bytei (quotient biti 8))
  (define biti-in-byte (remainder biti 8))
  (define b (bytes-ref bs bytei))
  (bitwise-bit-set? b (- 7 biti-in-byte)))

;; ============================================================
;; Input Bitport

#|
;; An input-bitport is (input-bitport port bv)
(struct input-bitport (in cache) #:mutable #:transparent)
(define (-input-cache-bits bin nbits)
  (match-define (input-bitport in cache) bin)
  (cond [(< (sbv-length cache) nbits)
         (define next (read-byte in))
         (cond [(byte? next)
                (define cache* (bv-append cache (make-sbv next 8)))
                (set-input-bitport-cache! bin cache*)]
               [else cache])]
        [else cache]))
(define (read-bit bin)
  (define bv (read-bv 1 bin))
  (cond [(eof-object? bv) eof]
        [else (bv-car bv)]))
(define (read-bv n bin)
  (define cache (-input-cache-bits bin 1))
  (cond [(bv-empty? cache) eof]
        [else
         (define-values (bv cache*) (bv-split cache n))
         (set-input-bitport-cache! bin cache*)
         bv]))
|#
