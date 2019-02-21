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

    (define/public (get-limit)
      (- limit got))

    (define/public (at-limit/eof?)
      (or (zero? (get-limit)) (eof-object? (peek-byte in))))

    (define/public (push-limit! rel-limit)
      (define new-limit (+ rel-limit got))
      (unless (<= new-limit limit)
        (error 'push-limit! "new limit is beyond existing limit\n  new: ~s\n  old: ~s"
               rel-limit (get-limit)))
      (set! limstack (cons limit limstack))
      (set! limit new-limit))

    (define/public (pop-limit!)
      (unless (pair? limstack)
        (error 'pop-limit! "empty limit stack"))
      (set! limit (car limstack))
      (set! limstack (cdr limstack)))

    (define/private (check-read-len len #:who who)
      (unless (<= (+ got len) limit)
        (long-read who len)))

    ;; call-with-limit : (U Nat #f) (-> X) -> X
    (define/public (call-with-limit rel-limit proc)
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

    (define/public (check-exhausted what #:who [who 'check-exhausted])
      (unless (at-limit/eof?)
        (define-values (line col pos) (port-next-location in))
        (error who "bytes left over~a\n  at: ~a:~a:~a:~a"
               (if what (format " after reading ~a" what) "")
               (object-name in) (or line "") (or col "") (or pos ""))))

    ;; ----------------------------------------
    ;; Reading w/ exact length required

    (define/public (base-read-bytes! buf start end #:who who)
      (check-read-len (- end start) #:who who)
      (define r (r:read-bytes! buf in start end))
      (cond [(eof-object? r) 0]
            [else (set! got (+ got r)) r]))

    (define/public (read-bytes! buf [start 0] [end (bytes-length buf)] #:who [who 'read-bytes!])
      (define r (base-read-bytes! buf start end #:who who))
      (cond [(< r (- end start)) (short-read who (- end start) buf start (+ start r))]
            [else r]))

    (define/public (read-bytes len #:who [who 'read-bytes])
      (define buf (make-bytes len))
      (define r (base-read-bytes! buf 0 len #:who who))
      (cond [(< r len) (short-read who len buf 0 r)]
            [else buf]))

    (define/public (read-byte #:who [who 'read-byte])
      (check-read-len 1 #:who who)
      (define b (r:read-byte in))
      (cond [(eof-object? b) (short-read who #"" 0 0)]
            [else (set! got (add1 got)) b]))

    (define/public (read-integer size signed? [big-endian? #t] #:who [who 'read-integer])
      (bytes->integer (read-bytes size #:who who) signed? big-endian?))

    (define/public (read-float size [big-endian? #t] #:who [who 'read-float])
      (floating-point-bytes->real (read-bytes size #:who who) big-endian?))

    ))
