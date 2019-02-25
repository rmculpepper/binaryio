#lang racket/base
(require rackunit
         racket/format
         racket/port
         binaryio/unchecked/fixup-port)
(provide (all-defined-out))

(define (call/fixup-output proc)
  (define fx (open-fixup-port))
  (proc fx)
  (with-output-to-bytes
    (lambda () (fixup-port-flush fx (current-output-port)))))

(define (number->bytes n) (string->bytes/latin-1 (number->string n)))

;; ----

(check-equal? (call/fixup-output
               (lambda (fx)
                 (push-fixup fx)
                 (pop-fixup fx number->bytes)))
              #"0")

(check-equal? (call/fixup-output
               (lambda (fx)
                 (push-fixup fx)
                 (pop-fixup fx number->bytes)
                 (push-fixup fx)
                 (pop-fixup fx number->bytes)))
              #"00")

(check-equal? (call/fixup-output
               (lambda (fx)
                 (push-fixup fx)
                 (push-fixup fx)
                 (pop-fixup fx number->bytes)
                 (pop-fixup fx number->bytes)))
              #"10")

(check-equal? (call/fixup-output
               (lambda (fx)
                 (push-fixup fx)
                 (write-string "abc" fx)
                 (pop-fixup fx number->bytes)))
              #"3abc")

(let ()
  (define (do-test size)
    (check-equal? (call/fixup-output
                   (lambda (fx)
                     (push-fixup fx)
                     (write-string "a" fx)
                     (push-fixup fx)
                     (write-string "b" fx)
                     (pop-fixup fx number->bytes)
                     (push-fixup fx)
                     (write-string "c" fx)
                     (pop-fixup fx number->bytes)
                     (pop-fixup fx number->bytes)))
                  #"5a1b1c"))
  (do-test #f)
  (do-test 1))

(let ()
  (define (do-test size1 size2)
    (check-equal? (call/fixup-output
                   (lambda (fx)
                     (write-string "abc" fx)
                     (push-fixup fx size1)
                     (write-string "def" fx)
                     (push-fixup fx size2)
                     (write-string "ghi" fx)
                     (pop-fixup fx number->bytes)
                     (pop-fixup fx number->bytes)))
                  #"abc7def3ghi"))
  ;; test unsized fixups
  (do-test #f #f)
  ;; test sized fixups
  (do-test 1 1)
  ;; test mixture
  (do-test 1 #f)
  (do-test #f 1))

;; ============================================================

(define (number->3bytes n)
  (string->bytes/latin-1 (format "~a:" (~r #:pad-string "0" #:min-width 2 n))))

(define (print-sexp v)
  (call/fixup-output
   (lambda (fx)
     (let loop ([v v])
       (push-fixup fx)
       (cond [(list? v)
              (write-string "(" fx)
              (for ([e (in-list v)] [i (in-naturals)])
                (unless (zero? i) (write-string " " fx))
                (loop e))
              (write-string ")" fx)]
             [else (fprintf fx "~s" v)])
       (pop-fixup fx number->3bytes)))))

(check-equal? (print-sexp '(a b (c ())))
              #"27:(01:a 01:b 12:(01:c 02:()))")

(define (print-sexp2 v)
  (call/fixup-output
   (lambda (fx)
     (let loop ([v v])
       (push-fixup fx 3)
       (cond [(list? v)
              (write-string "(" fx)
              (for ([e (in-list v)] [i (in-naturals)])
                (unless (zero? i) (write-string " " fx))
                (loop e))
              (write-string ")" fx)]
             [else (fprintf fx "~s" v)])
       (pop-fixup fx number->3bytes)))))

(check-equal? (print-sexp2 '(a b (c ())))
              #"27:(01:a 01:b 12:(01:c 02:()))")
