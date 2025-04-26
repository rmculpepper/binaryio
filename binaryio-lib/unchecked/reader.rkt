;; Copyright 2019-2021 Ryan Culpepper
;; SPDX-License-Identifier: Apache-2.0 OR MIT

#lang racket/base
(require "integer.rkt")
(provide (all-defined-out))

(struct binary-reader
  (in                    ;; InputPort
   [got #:mutable]       ;; Nat
   [limit #:mutable]     ;; #f or Nat
   [limstack #:mutable]  ;; (list Nat ... Nat/#f)
   err))                 ;; (U BinaryReaderErrorHandler #f)

(struct errhandler
  (error                 ;; #f or (BinaryReader Symbol FormatString Any ... -> escapes)
   show-data?            ;; #f or (BinaryReader Symbol -> Boolean)
   long-read             ;; #f or (BinaryReader Symbol Nat -> escapes)
   short-read            ;; #f or (BinaryReader Symbol Nat Nat Bytes/#f -> escapes)
   ) #:reflection-name 'binary-reader-error-handler)

(define (make-binary-reader in #:limit [limit #f] #:error-handler [err #f])
  (let ([err (if (procedure? err) (errhandler err #f #f #f) err)])
    (binary-reader in 0 limit null err)))

(define (make-binary-reader-error-handler
         #:error [error #f]
         #:show-data? [show-data? #f]
         #:long-read [long-read #f]
         #:short-read [short-read #f])
  (errhandler error show-data? long-read short-read))

(define binary-reader-error-handler? errhandler?)
(define default-errhandler (make-binary-reader-error-handler))

;; ----------------------------------------
;; Errors

(define (-error br who fmt . args)
  (define err (-get-err br))
  (cond [(errhandler-error err)
         => (lambda (cb)
              (apply cb br who fmt args)
              (-no-escape who "error handler"))]
        [else (apply error who fmt args)]))

(define (-long-read br who wanted)
  (define err (-get-err br))
  (cond [(errhandler-long-read err)
         => (lambda (cb)
              (cb br who wanted)
              (-no-escape who "long read handler"))]
        [else (-default-long-read br who wanted)]))

(define (-default-long-read br who wanted)
  (-error br who
          (string-append "requested read longer than current limit"
                         "\n  tried to read: ~s bytes"
                         "\n  limit: ~s bytes")
          wanted (b-get-limit br)))

(define (-short-read br who wanted buf start end)
  (define err (-get-err br))
  (let ([buf (and buf (-show-data? err br who) (subbytes buf start end))]
        [got (- end start)])
    (cond [(errhandler-short-read err)
           => (lambda (cb)
                (cb br who wanted got buf)
                (-no-escape who "short read handler"))]
          [else (-default-short-read br who wanted got buf)])))

(define (-default-short-read br who wanted got buf)
  (-error br who "unexpected end of input\n  tried to read: ~s bytes\n  available: ~s bytes~a"
          wanted got (if buf (format "\n  received: ~e" buf) "")))

(define (-no-escape who what)
  (error who "~a did not raise an exception" what))

(define (-get-err br)
  (or (binary-reader-err br) default-errhandler))

(define (-show-data? err br who)
  (cond [(errhandler-show-data? err) => (lambda (show?) (show? br who))]
        [else #t]))

;; ----------------------------------------
;; Limits

;; Externally, a limit is get/set as a number of bytes relative to
;; the current read position. Internally, limits are stored as
;; absolute positions.

(define (b-get-limit br)
  (cond [(binary-reader-limit br)
         => (lambda (limit) (- limit (binary-reader-got br)))]
        [else #f]))

(define (b-at-limit? br)
  (eqv? (binary-reader-got br) (binary-reader-limit br)))

(define (b-at-limit/eof? br)
  (or (b-at-limit? br) (eof-object? (peek-byte (binary-reader-in br)))))

(define (b-push-limit br rel-limit)
  (define new-limit (+ rel-limit (binary-reader-got br)))
  (define old-limit (binary-reader-limit br))
  (when (and old-limit (> new-limit old-limit))
    (error 'b-push-limit "new limit is beyond existing limit\n  new: ~s\n  old: ~s"
           rel-limit (b-get-limit br)))
  (set-binary-reader-limstack! br (cons old-limit (binary-reader-limstack br)))
  (set-binary-reader-limit! br new-limit))

(define (b-pop-limit br)
  (define limstack (binary-reader-limstack br))
  (unless (pair? limstack)
    (error 'b-pop-limit "empty limit stack"))
  (set-binary-reader-limit! br (car limstack))
  (set-binary-reader-limstack! br (cdr limstack)))

(define (b-call/save-limit br proc)
  ;; Useful for restoring whole limit stack, eg on exception.
  (define saved-limit (binary-reader-limit br))
  (define saved-limstack (binary-reader-limstack br))
  (call-with-continuation-barrier
   (lambda ()
     (dynamic-wind void
                   proc
                   (lambda ()
                     (set-binary-reader-limit! br saved-limit)
                     (set-binary-reader-limstack! br saved-limstack))))))

;; -limit{<,<=}? : Nat Nat/#f -> Boolean
(define (-limit<? a b) (if b (< a b) #t))
(define (-limit<=? a b) (if b (<= a b) #t))

(define (-check-read-len br who len)
  (unless (-limit<=? (+ (binary-reader-got br) len) (binary-reader-limit br))
    (-long-read br who len)))

(define (-advance br len)
  (set-binary-reader-got! br (+ (binary-reader-got br) len)))

;; ----------------------------------------
;; Exhaustion checking

(define (b-check-exhausted br what #:who [who 'b-check-exhausted])
  (unless (b-at-limit/eof? br)
    (define in (binary-reader-in br))
    (define-values (line col pos) (port-next-location in))
    (-error br who "bytes left over~a\n  at: ~a:~a:~a:~a"
            (if what (format " after reading ~a" what) "")
            (object-name in) (or line "") (or col "") (or pos ""))))

;; ----------------------------------------
;; Reading w/ exact length required

(define (-read-bytes! br who buf start end)
  (-check-read-len br who (- end start))
  (define r (read-bytes! buf (binary-reader-in br) start end))
  (cond [(eof-object? r) 0]
        [else (begin (-advance br r) r)]))

(define (b-read-bytes! br buf [start 0] [end (bytes-length buf)] #:who [who 'b-read-bytes!])
  (define r (-read-bytes! br who buf start end))
  (cond [(< r (- end start))
         (-short-read br who (- end start) buf start (+ start r))]
        [else r]))

(define (b-read-bytes br len #:who [who 'b-read-bytes!])
  (define buf (make-bytes len))
  (b-read-bytes! br buf 0 len #:who who)
  buf)

(define (b-read-byte br #:who [who 'b-read-byte])
  (-check-read-len br who 1)
  (define b (read-byte (binary-reader-in br)))
  (cond [(eof-object? b) (-short-read br who 1 #"" 0 0)]
        [else (begin (-advance br 1) b)]))

(define (b-read-integer br size signed? [big-endian? #t] #:who [who 'b-read-integer])
  (bytes->integer (b-read-bytes br size #:who who) signed? big-endian?))

(define (b-read-be-int br size)  (b-read-integer br size #t #t #:who 'b-read-be-int))
(define (b-read-be-uint br size) (b-read-integer br size #f #t #:who 'b-read-be-uint))
(define (b-read-le-int br size)  (b-read-integer br size #t #f #:who 'b-read-le-int))
(define (b-read-le-uint br size) (b-read-integer br size #f #f #:who 'b-read-le-uint))

(define (b-read-float br size [big-endian? #t] #:who [who 'b-read-float])
  (floating-point-bytes->real (b-read-bytes br size #:who who) big-endian?))

;; ----------------------------------------
;; Peeking

;; b-peek-bytes-avail! : ... -> Nat
;; Returns zero only if (= start end). Raises error on EOF or concurrent read.
(define (b-peek-bytes-avail! br buf skip [start 0] [end (bytes-length buf)]
                             #:progress [progress #f]
                             #:who [who 'b-peek-bytes-avail!])
  (-check-read-len br who (+ skip (- end start)))
  (cond [(= start end) 0]
        [else
         (define in (binary-reader-in br))
         (define r (peek-bytes-avail! buf skip progress in start end))
         (cond [(eqv? r 0) (-error br who "peek failed due to concurrent read")]
               [(exact-integer? r) r]
               [(eof-object? r) (-error br who "unexpected end of input")]
               [else (-error br who "internal error: unexpected result from peek: ~e" r)])]))

;; b-peek-bytes! : ... -> Nat
(define (b-peek-bytes! br buf skip [start 0] [end (bytes-length buf)]
                       #:progress [progress #f]
                       #:who [who 'b-peek-bytes!])
  (-check-read-len br who (+ skip (- end start)))
  (define in (binary-reader-in br))
  (let loop ([skip skip] [start start])
    (when (< start end)
      (define r (peek-bytes-avail! buf skip progress in start end))
      (loop (+ skip r) (+ start r))))
  (- end start))

;; ----------------------------------------
;; Reading w/o length

(define (b-read-nul-terminated-bytes br #:who [who 'b-read-nul-terminated-bytes])
  (if (port-provides-progress-evts? (binary-reader-in br))
      (-read-nul-terminated-bytes/commit-once br #:who who)
      (-read-nul-terminated-bytes/naive br #:who who)))

(define (-read-nul-terminated-bytes/naive br #:who who)
  (define out (open-output-bytes))
  (let loop ()
    (define b (b-read-byte br #:who who))
    (unless (zero? b) (write-byte b out) (loop)))
  (get-output-bytes out #t))

(define (-read-nul-terminated-bytes/commit-once br #:who who)
  (define PEEKLEN 50)
  (define (find-nul buf len) ;; -> Nat/#f
    (for/first ([b (in-bytes buf 0 len)] [i (in-naturals)] #:when (zero? b)) i))
  (define (concurrent-read-error)
    (-error br who "commit peeked failed due to concurrent read"))
  (define in (binary-reader-in br))
  (define peekbuf (make-bytes PEEKLEN))
  (define progress (port-progress-evt in))
  (define limit (b-get-limit br))
  (define len-before-terminator
    (let loop ([skip 0]) ;; INV: skip <= limit, no NUL found in first skip bytes
      (cond [(-limit<? skip limit)
             (define peeklen (if (-limit<=? (+ skip PEEKLEN) limit) PEEKLEN (- limit skip)))
             (define r (b-peek-bytes-avail! br peekbuf skip 0 peeklen #:progress progress #:who who))
             (cond [(zero? r) (concurrent-read-error)]
                   [(find-nul peekbuf r) => (lambda (nul-pos) (+ skip nul-pos))]
                   [else (loop (+ skip r))])]
            [else (-error br who "NUL terminator not found before current limit")])))
  (define buf (make-bytes len-before-terminator))
  (b-peek-bytes! br buf 0 #:progress progress)
  (define len (add1 len-before-terminator))
  (unless (port-commit-peeked len progress always-evt in)
    (concurrent-read-error))
  (-advance br len)
  buf)

;; Note: unlike read-bytes-line, fails if EOF encountered before EOL
(define (b-read-bytes-line br eol-mode #:who [who 'b-read-bytes-line+eol])
  (let-values ([(bs eol) (b-read-bytes-line+eol br eol-mode #:who who)]) bs))

(define (b-read-bytes-line+eol br eol-mode #:who [who 'b-read-bytes-line+eol])
  (define out (open-output-bytes))
  (define eol-rx
    (case eol-mode
      [(linefeed) #rx#"\n"]
      [(return) #rx#"\r"]
      [(return-linefeed) #rx#"\r\n"]
      [(any) #rx#"\r\n?|\n"]
      [(any-one) #rx#"\r|\n"]))
  (cond [(regexp-try-match eol-rx (binary-reader-in br) 0 (b-get-limit br) out)
         => (lambda (m) (values (get-output-bytes out) (car m)))]
        [else
         (-error br who "end of line not found before current limit")]))
