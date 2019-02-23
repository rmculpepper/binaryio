#lang racket/base
(require (prefix-in r: racket/base)
         racket/class
         "integer.rkt")
(provide (all-defined-out))

(define binary-reader%
  (class object%
    (init-field in
                [limit +inf.0]
                [(long-read-callback long-read) #f]
                [(short-read-callback short-read) #f])
    (define got 0)
    (define limstack null)
    (super-new)

    ;; ----------------------------------------
    ;; Error hooks

    (define/public (long-read who wanted)
      ;; Requested read past limit
      (when long-read-callback (long-read-callback who wanted))
      (default-long-read who wanted))

    (define/public (default-long-read who wanted)
      (error who (string-append "requested read longer than current limit"
                                "\n  tried to read: ~s bytes"
                                "\n  limit: ~s bytes")
             wanted (get-limit)))

    (define/public (short-read who wanted buf start end)
      ;; Got EOF before requested length read.
      (when short-read-callback (short-read-callback who wanted buf start end))
      (default-short-read who wanted buf start end))

    (define/public (default-short-read who wanted buf start end)
      (error who (string-append "unexpected end of input"
                                "\n  tried to read: ~s bytes"
                                "\n  available: ~s bytes"
                                "~a")
             wanted (- end start)
             (if buf (format "\n  received: ~e" (subbytes buf start end)) "")))

    ;; ----------------------------------------
    ;; Limits

    ;; Externally, a limit is get/set as a number of bytes relative to
    ;; the current read position. Internally, limits are stored as
    ;; absolute positions.

    (define/public-final (get-limit)
      (- limit got))

    (define/public-final (at-limit/eof?)
      (or (zero? (get-limit)) (eof-object? (peek-byte in))))

    (define/public-final (push-limit! rel-limit)
      (define new-limit (+ rel-limit got))
      (unless (<= new-limit limit)
        (error 'push-limit! "new limit is beyond existing limit\n  new: ~s\n  old: ~s"
               rel-limit (get-limit)))
      (set! limstack (cons limit limstack))
      (set! limit new-limit))

    (define/public-final (pop-limit!)
      (unless (pair? limstack)
        (error 'pop-limit! "empty limit stack"))
      (set! limit (car limstack))
      (set! limstack (cdr limstack)))

    (define/private (check-read-len who len)
      (unless (<= (+ got len) limit)
        (long-read who len)))

    ;; call-with-limit : (U Nat #f) (-> X) -> X
    (define/public-final (call-with-limit rel-limit proc)
      ;; Useful for restoring whole limit stack, eg on exception.
      (push-limit! (or rel-limit (get-limit)))
      (define saved-limstack limstack)
      (call-with-continuation-barrier
       (lambda ()
         (dynamic-wind void
                       proc
                       (lambda () (set! limstack saved-limstack) (pop-limit!))))))

    ;; ----------------------------------------
    ;; Exhaustion checking

    (define/public-final (check-exhausted what #:who [who 'check-exhausted])
      (unless (at-limit/eof?)
        (define-values (line col pos) (port-next-location in))
        (error who "bytes left over~a\n  at: ~a:~a:~a:~a"
               (if what (format " after reading ~a" what) "")
               (object-name in) (or line "") (or col "") (or pos ""))))

    ;; ----------------------------------------
    ;; Reading w/ exact length required

    (define/private (-read-bytes! who buf start end)
      (check-read-len who (- end start))
      (define r (r:read-bytes! buf in start end))
      (cond [(eof-object? r) 0]
            [else (set! got (+ got r)) r]))

    (define/public-final (read-bytes! buf [start 0] [end (bytes-length buf)])
      (define r (-read-bytes! 'read-bytes! buf start end))
      (cond [(< r (- end start))
             (short-read 'read-bytes! (- end start) buf start (+ start r))]
            [else r]))

    (define/private (-read-bytes who len)
      (define buf (make-bytes len))
      (define r (-read-bytes! who buf 0 len))
      (cond [(< r len) (short-read who len buf 0 r)]
            [else buf]))

    (define/public-final (read-bytes len)
      (-read-bytes 'read-bytes len))

    (define/private (-read-byte who)
      (check-read-len who 1)
      (define b (r:read-byte in))
      (cond [(eof-object? b) (short-read who #"" 0 0)]
            [else (set! got (add1 got)) b]))

    (define/public-final (read-byte)
      (-read-byte 'read-byte))

    (define/private (-read-integer who size signed? big-endian?)
      (bytes->integer (-read-bytes who size) signed? big-endian?))

    (define/public-final (read-integer size signed? [big-endian? #t])
      (-read-integer 'read-integer size signed? big-endian?))

    (define/private (-read-float who size big-endian?)
      (floating-point-bytes->real (-read-bytes who size) big-endian?))

    (define/public-final (read-float size [big-endian? #t])
      (-read-float 'read-float size big-endian?))

    ))

(define-syntax-rule (define-generics (fun meth (arg ...) ...) ...)
  (begin
    (define fun
      (let ([gen (generic binary-reader% meth)])
        (case-lambda [(obj arg ...) (send-generic obj gen arg ...)] ...)))
    ...))

(define-generics
  (br-get-limit     get-limit     ())
  (br-at-limit/eof? at-limit/eof? ())
  (br-push-limit!   push-limit!   (limit))
  (br-pop-limit!    pop-limit!    ())
  (br-read-bytes    read-bytes    (len))
  (br-read-bytes!   read-bytes!   (buf) (buf start end))
  (br-read-byte     read-byte     ())
  (br-read-integer  read-integer  (size signed?) (size signed? big-endian?))
  (br-read-float    read-float    (size signed?))
  )

(define (make-binary-reader in #:limit [limit +inf.0])
  (new binary-reader% (in in) (limit limit)))
