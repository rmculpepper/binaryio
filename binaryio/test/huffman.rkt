#lang racket/base
(require rackunit
         racket/pretty
         binaryio/unchecked/bytes-bits
         binaryio/unchecked/bitvector
         binaryio/unchecked/huffman
         (submod binaryio/unchecked/huffman private-for-testing)
         binaryio/unchecked/prefixcode)

(test-case "huffman 1 round trip"
  (define alpha1
    '((a . 0.10)
      (b . 0.15)
      (c . 0.30)
      (d . 0.16)
      (e . 0.29)))
  (define h1 (make-huffman-code alpha1 #:convert? #f))
  (check-equal? (code->sexpr h1)
                '(list
                  (c "00")
                  (d "01")
                  (e "10")
                  (a "110")
                  (b "111")))
  (define h1d (prefixcode-build-decode-tree h1))
  (define msg '(a b c d e))
  (let-values ([(enc len) (prefixcode-encode h1 msg)])
    (check-equal? (prefixcode-decode-list h1d enc 0 len) msg)))

(test-case "huffman 2"
  (define alpha2
    '((0 . 0.4)
      (1 . 0.35)
      (2 . 0.2)
      (3 . 0.05)))
  (define h2 (make-huffman-code alpha2 #:convert? #f))
  (define h2d (prefixcode-build-decode-tree h2))
  (check-equal? (code->sexpr h2)
                '(list
                  (0 "0")
                  (1 "10")
                  (2 "110")
                  (3 "111"))))

(test-case "huffman 3"
  (define alpha3
    (vector #f 2 1 1 1 1))
  (define alpha3b
    '((1 . 2)
      (2 . 1)
      (3 . 1)
      (4 . 1)
      (5 . 1)))
  (define h3 (make-huffman-code alpha3 #:convert? #f))
  (check-equal? (make-huffman-code alpha3b #:convert? #f) h3)
  (define h3d (prefixcode-build-decode-tree h3))
  (check-equal? (code->sexpr h3)
                '(list
                  (1 "0")
                  (2 "100")
                  (3 "101")
                  (4 "110")
                  (5 "111"))))

(test-case "huffman 4"
  (define ex4
    '((#\c . 12)
      (#\e . 31)
      (#\f .  7)
      (#\l . 11)
      (#\s . 19)
      (#\u . 20)))
  (define h4 (make-huffman-code ex4 #:convert? #f))
  (check-equal? (code->sexpr h4)
                '(list
                  (#\e "00")
                  (#\s "01")
                  (#\u "10")
                  (#\c "110")
                  (#\f "1110")
                  (#\l "1111")))
  (let-values ([(enc len) (prefixcode-encode h4 "successful")])
    (check-equal? (bytes-bits->string enc 0 len)
                  "01101101100001011110101111"))
  (void))

(test-case "huffman 5 - singleton"
  (define h5 (make-huffman-code '((#\a . 1)) #:convert? #f))
  (check-equal? (length h5) 1)
  (check-equal? (cdar h5) (make-be-sbv 0 1))
  (void))
