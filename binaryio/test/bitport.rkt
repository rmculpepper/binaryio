#lang racket/base
(require rackunit
         binaryio/bytes-bits
         binaryio/bitvector
         binaryio/bitport)

(define bvs
  (for/list ([i #e1e2])
    (define len (add1 (random 20)))
    (make-sbv (random (expt 2 len)) len)))

(for ([msf? '(#t #f)])
  (test-case (format "bitport, msf=~s" msf?)
    (define bp (open-output-bitport msf?))
    (define sp (open-output-string))
    (for ([bv (in-list bvs)])
      (output-bitport-write-sbv bp bv)
      (write-string (sbv->string bv) sp))

    (define-values (bs nbits) (output-bitport-get-output bp))
    (define s (get-output-string sp))
    (define slen (string-length s))
    (check-equal? nbits (apply + (map sbv-length bvs)))
    (check-equal? nbits slen)
    (check-equal? (bytes-bits->string bs 0 nbits msf?) s)))
