;; Copyright 2019 Ryan Culpepper
;; SPDX-License-Identifier: Apache-2.0 OR MIT

#lang racket/base
(require racket/match)
(provide fixup-port?
         open-fixup-port
         push-fixup
         pop-fixup
         fixup-port-flush)

(define UFIXLEN 4) ;; bytes reserved in outbuf for unsized fixup

;; A Fixup is (fixup Nat (U #f Nat) (U Nat Bytes))
;; When it is at the top of the stack:
;; - value is length of all fixups since this one
;; After popped (unsized, |value| <= UFIXLEN)
;; - value is Nat, length of value
;; After popped (unsized, |value| > UFIXLEN)
;; - value is Bytes
;; After popped (sized, value fits exactly)
;; - nothing left to do; fixup is discarded
(struct fixup (bufpos size [value #:mutable]))

;; A fixup-port support fixups in stack discipline.
(struct fixup-port
  (bufout               ;; BytesOutputPort
   [pending #:mutable]  ;; (Listof Fixup) -- stack, newest first
   [unsized #:mutable]  ;; (Listof Fixup) -- newest first, only unsized fixups
   )
  #:property prop:output-port (struct-field-index bufout))

(define (open-fixup-port)
  (fixup-port (open-output-bytes) null null))

(define (-bufpos fx)
  (file-position (fixup-port-bufout fx)))

(define (push-fixup fx [size #f])
  (define f (fixup (-bufpos fx) size 0))
  (set-fixup-port-pending! fx (cons f (fixup-port-pending fx)))
  (write-bytes (make-bytes (or size UFIXLEN) 0) fx)
  (unless size
    (set-fixup-port-unsized! fx (cons f (fixup-port-unsized fx)))))

(define (-patch bufout pos value len)
  (define saved-position (file-position bufout))
  (file-position bufout pos)
  (write-bytes value bufout 0 len)
  (file-position bufout saved-position))

(define (pop-fixup fx proc)
  (match (fixup-port-pending fx)
    ['() (error 'fixup-port-pop "empty fixup stack")]
    [(cons (and f (fixup f-bufpos f-size f-since)) pending)
     (set-fixup-port-pending! fx pending)
     (define bufpos (-bufpos fx))
     (define since (+ (- bufpos f-bufpos (or f-size UFIXLEN)) f-since))
     (define value (proc since))
     (define value-len (bytes-length value))
     (cond [f-size
            (unless (= value-len f-size)
              (error 'fixup-port-pop
                     "function returned wrong size\n  expected: ~s bytes\n  got: ~s bytes"
                     f-size value-len))
            (-patch (fixup-port-bufout fx) f-bufpos value f-size)]
           [(<= (bytes-length value) UFIXLEN)
            (-patch (fixup-port-bufout fx) f-bufpos value value-len)
            (set-fixup-value! f value-len)]
           [else
            (set-fixup-value! f value)])
     (when (pair? pending)
       (define prev (car pending))
       (set-fixup-value! prev (+ (fixup-value prev) f-since
                                 (if f-size 0 (- (bytes-length value) UFIXLEN)))))]))

(define (fixup-port-flush fx out)
  (when (pair? (fixup-port-pending fx))
    (error 'fixup-port-flush "fixup stack not empty"))
  (define buf (get-output-bytes (fixup-port-bufout fx) #t))
  (define buflen (bytes-length buf))
  (define (loop pos fixups)
    (cond [(null? fixups) (write-bytes buf out pos buflen)]
          [else (loop-fixup pos (car fixups) (cdr fixups))]))
  (define (loop-fixup pos f fixups)
    (match-define (fixup f-bufpos #f f-value) f)
    (cond [(bytes? f-value)
           (when (< pos f-bufpos) (write-bytes buf out pos f-bufpos))
           (write-bytes f-value out)]
          [else ;; f-value is Nat
           (write-bytes buf out pos (+ f-bufpos f-value))])
    (loop (+ f-bufpos UFIXLEN) fixups))
  (define fixups (reverse (fixup-port-unsized fx)))
  (set-fixup-port-unsized! fx null)
  (void (loop 0 fixups)))
