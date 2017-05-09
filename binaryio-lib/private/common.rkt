#lang racket/base
(provide (all-defined-out))

(struct exn:fail:read:binaryio exn:fail:read (info) #:transparent)

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
  (define loc (srcloc (object-name port) #f #f start-position received-bytes))
  (raise (exn:fail:read:binaryio
          message
          (current-continuation-marks)
          (list loc)
          `([wanted-bytes . ,wanted-bytes]
            [received . ,r]))))

;; ----

;; -read-bytes : InputPort Nat -> Bytes
(define (-read-bytes who port len)
  (define r (read-bytes len port))
  (if (and (bytes? r) (= (bytes-length r) len))
      r
      (error/insufficient who port len r)))
