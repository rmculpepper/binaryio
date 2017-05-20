#lang racket/base
(require rackunit
         binaryio/bytes)

;; read-bytes*
;; - roundtrips
;; - errors on early eof

(define BYTES-VALUES
  `(#""
    #"abcde"
    ,(make-bytes #e1e5 65)))

(test-case "read-bytes* roundtrips"
  (for ([b BYTES-VALUES])
    (define-values (in out) (make-pipe))
    (write-bytes b out)
    (close-output-port out)
    (check-equal? (read-bytes* (bytes-length b) in) b)))

(test-case "read-bytes* errors on eof"
  (for ([b BYTES-VALUES])
    (define-values (in out) (make-pipe))
    (write-bytes b out)
    (close-output-port out)
    (check-exn #rx"unexpected end of input"
               (lambda () (read-bytes* (add1 (bytes-length b)) in)))))

;; {read,write}-null-terminated-bytes
;; - roundtrips
;; - errors on early eof

(test-case "null-terminated-bytes roundtrips"
  (for ([b BYTES-VALUES])
    (define-values (in out) (make-pipe))
    (write-null-terminated-bytes b out)
    (close-output-port out)
    (check-equal? (read-null-terminated-bytes in) b)))

(test-case "read-null-terminated-bytes errors on eof"
  (for ([b BYTES-VALUES])
    (define-values (in out) (make-pipe))
    (write-bytes b out) ;; NOT null-terminated
    (close-output-port out)
    (check-exn #rx"unexpected end of input"
               (lambda () (read-null-terminated-bytes in)))))
