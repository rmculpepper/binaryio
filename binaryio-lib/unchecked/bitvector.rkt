;; Copyright 2019-2021 Ryan Culpepper
;; Dual-licensed under Apache 2.0 and MIT terms.

#lang racket/base
(require (for-syntax racket/base)
         racket/match)
(provide (all-defined-out))

;; A ShortBitVector is a nonnegative exact integer
;; where [b0 b1 ...] is encoded as (SUM_k bk*2^k)<<16 + LEN

;; That is, the bits are the little-endian interpretation of the
;; prefix of the number (independent of the hardware endianness).
;; Example: (make-sbv #b1011 4) represents [1 1 0 1]

;; Bitvectors up to 2^16-1 bits are representable.
;; Bitvectors up to about 46 bits are representable by fixnums.

;; ============================================================
;; Operations on short bitvector encodings

(define SBV-LENGTH-BITS 16)
(define SBV-LENGTH-BOUND (expt 2 SBV-LENGTH-BITS))
(define SBV-LENGTH-MASK (sub1 SBV-LENGTH-BOUND))

(define (canonical-sbv? v)
  (and (exact-nonnegative-integer? v)
       (<= (integer-length v)
           (+ SBV-LENGTH-BITS (sbv-length v)))))

(define (make-sbv n len)
  (if (< len SBV-LENGTH-BOUND)
      (bitwise-ior (arithmetic-shift n SBV-LENGTH-BITS) len)
      (error 'sbv "too long\n  length: ~e" len)))

(define (make-be-sbv n len)
  (sbv-reverse (make-sbv n len)))

(define empty-sbv (make-sbv 0 0))
(define (sbv-empty? sbv) (eqv? sbv empty-sbv))

(define (sbv-length sbv)
  (bitwise-bit-field sbv 0 SBV-LENGTH-BITS))

(define (sbv-bits sbv)
  (arithmetic-shift sbv (- SBV-LENGTH-BITS)))
(define (sbv-bit-field sbv start end)
  ;; ok for start, end to be past end of bitvector (zero)
  (if (< start end)
      (bitwise-bit-field sbv (+ start SBV-LENGTH-BITS) (+ end SBV-LENGTH-BITS))
      0))
(define (sbv-shift sbv lshift)
  (make-sbv (arithmetic-shift (sbv-bits sbv) lshift)
            (max 0 (+ (sbv-length sbv) lshift))))

(define (sbv-slice sbv start end)
  (if (< start end)
      (make-sbv (bitwise-bit-field sbv (+ start SBV-LENGTH-BITS) (+ end SBV-LENGTH-BITS))
                (- end start))
      empty-sbv))

(define (sbv-ref sbv k)
  (if (sbv-bit-set? sbv k) 1 0))

(define (sbv-bit-set? sbv k)
  (bitwise-bit-set? sbv (+ k SBV-LENGTH-BITS)))

(define (sbv-car sbv) (sbv-ref sbv 0))
(define (sbv-cdr sbv) (sbv-shift sbv -1))

(define (sbv-cons bit sbv)
  (make-sbv (bitwise-ior (arithmetic-shift (sbv-bits sbv) 1) bit)
            (add1 (sbv-length sbv))))

(define (sbv-append2 a b)
  (define alen (sbv-length a))
  (define blen (sbv-length b))
  (make-sbv (bitwise-ior (sbv-bits a) (arithmetic-shift (sbv-bits b) alen))
            (+ alen blen)))

(define sbv-append
  (case-lambda
    [() empty-sbv]
    [(a) a]
    [(a b) (sbv-append2 a b)]
    [as (foldr sbv-append2 empty-sbv as)]))

(define (sbv-reverse sbv)
  (sbv-reverse/byte-loop sbv))

(define (sbv-reverse/bit-loop sbv)
  ;; This version is slow even for fixnum arguments!
  (define len (sbv-length sbv))
  (define bits (sbv-bits sbv))
  (make-sbv (let loop ([i 0] [acc 0])
              (if (< i len)
                  (loop (add1 i)
                        (bitwise-ior (if (bitwise-bit-set? bits i) 1 0)
                                     (arithmetic-shift acc 1)))
                  acc))
            len))

(define (sbv-reverse/byte-loop sbv)
  (define len (sbv-length sbv))
  (let loop ([i 0] [acc 0])
    (cond [(< i len)
           (loop (+ i 8)
                 (bitwise-ior (reverse-byte (sbv-bit-field sbv i (+ i 8)))
                              (arithmetic-shift acc 8)))]
          [else ;; may have overshot
           (make-sbv (arithmetic-shift acc (- len i)) len)])))

(define (reverse-byte byte)
  (define-syntax (quote-table stx)
    (define (revbyte n)
      (let loop ([i 0] [acc 0])
        (if (< i 8)
            (loop (add1 i)
                  (bitwise-ior (if (bitwise-bit-set? n i) 1 0) (arithmetic-shift acc 1)))
            acc)))
    #`(quote #,(apply bytes (for/list ([i (in-range 256)]) (revbyte i)))))
  (bytes-ref (quote-table) byte))

(define (sbv-prefix? a b) ;; Is a prefix of b?
  (and (<= (sbv-length a) (sbv-length b))
       (= (sbv-bits a) (sbv-bit-field b 0 (sbv-length a)))))

(define (sbv-split sbv n)
  (define len (sbv-length sbv))
  (define n* (min n len))
  (values (make-sbv (sbv-bit-field sbv 0 n*) n*)
          (make-sbv (sbv-bit-field sbv n* len) (- len n*))))

(define (sbv-map f sbv)
  (for/list ([i (in-range (sbv-length sbv))])
    (f (sbv-ref sbv i))))

(define (sbv->string sbv)
  (define s (make-string (sbv-length sbv) #\0))
  (for/list ([i (in-range (sbv-length sbv))])
    (when (sbv-bit-set? sbv i) (string-set! s i #\1)))
  s)

(define (string->sbv s)
  (define n (string->number s 2))
  (if n (make-be-sbv n (string-length s))
      (error 'string->sbv "expected string matching [01]*\n  given: ~e" s)))

;; ============================================================

(module+ main
  (define rand-sbvs
    (for/vector ([i #e1e5])
      (define len (add1 (random 16)))
      (add1 (random (expt 2 len)))))

  (printf "length\n")
  (time (for ([i (in-range 1000)])
          (for ([sbv (in-vector rand-sbvs)])
            (sbv-length sbv))))

  (printf "cdr\n")
  (time (for ([i (in-range 1000)])
          (for ([sbv (in-vector rand-sbvs)])
            (sbv-cdr sbv))))

  (printf "cons\n")
  (time (for ([i (in-range 1000)])
          (for ([sbv (in-vector rand-sbvs)])
            (sbv-cons 1 sbv))))

  (printf "ref 0\n")
  (time (for ([i (in-range 1000)])
          (for ([sbv (in-vector rand-sbvs)])
            (sbv-ref sbv 0))))

  (printf "reverse\n")
  (time (for ([i (in-range 1)])
          (for ([sbv (in-vector rand-sbvs)])
            (sbv-reverse sbv))))
  )
