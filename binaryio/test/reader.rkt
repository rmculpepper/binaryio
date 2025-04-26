#lang racket/base
(require rackunit
         binaryio/reader)

(test-case "b-read-nul-terminated-bytes advances the limit"
  (define br (make-binary-reader (open-input-bytes #"hello\0world") #:limit 6))
  (check-equal? (b-read-nul-terminated-bytes br) #"hello")
  (check-equal? (b-get-limit br) 0))

(test-case "b-read-nul-terminated-bytes errors if limit exceeded"
  (define br (make-binary-reader (open-input-bytes #"hello\0world") #:limit 5))
  (check-exn #rx"NUL terminator not found before current limit"
             (lambda () (b-read-nul-terminated-bytes br))))
