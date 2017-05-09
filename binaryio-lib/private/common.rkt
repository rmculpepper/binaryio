#lang racket/base
(provide (all-defined-out))

(struct exn:fail:binaryio exn:fail (info) #:transparent)
(struct exn:fail:binaryio:eof exn:fail:binaryio (position wanted-bytes received-bytes) #:transparent)

;; FIXME: make custom exn struct
(define (error/insufficient who port len r)
  (define received-bytes (if (bytes? r) (bytes-length r) 0))
  (define message
    (format (string-append "unexpected end of input\n"
                           "  tried to read: ~s bytes\n"
                           "  available: ~s bytes\n"
                           "  received: ~e")
            len (if (bytes? r) (bytes-length r) 0) r))
  (define-values (_line _column position) (port-next-location port))
  (define start-position (- position received-bytes))
  (raise (exn:fail:binaryio:eof
          message
          (current-continuation-marks)
          `([start-position . ,start-position]
            [wanted-bytes . ,wanted-bytes]
            [received-bytes . ,received-bytes]
            [received . ,r])
          start-position wanted-bytes received-bytes)))

;; ----

;; -read-bytes : InputPort Nat -> Bytes
(define (-read-bytes who port len)
  (define r (read-bytes len port))
  (if (and (bytes? r) (= (bytes-length r) len))
      r
      (error/insufficient who port len r)))
