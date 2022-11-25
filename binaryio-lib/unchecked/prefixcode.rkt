;; Copyright 2019-2021 Ryan Culpepper
;; Dual-licensed under Apache 2.0 and MIT terms.

#lang racket/base
(require racket/match
         racket/list
         "bytes-bits.rkt"
         "bitvector.rkt"
         "bitport.rkt")
(provide prefixcode-encode
         prefixcode-encode!
         prefixcode-build-decode-tree
         prefixcode-decode
         prefixcode-decode-list
         prefixcode-decode!
         prefixcode-decode1)

;; ============================================================

;; A EncodeTable is one of
;; - Hash[Any => SBV]
;; - (Listof (cons Any SBV))
;; - (Vectorof SBV)

;; prefixcode-encode : EncodeTable Sequence -> (values Bytes Nat)
(define (prefixcode-encode ht src [msf? #t] #:pad [pad #x00])
  (define bp (open-output-bitport msf?))
  (prefixcode-encode! bp ht src)
  (output-bitport-get-output bp #:pad pad))

;; prefixcode-encode! : OutputBitPort EncodeTable Sequence -> Void
(define (prefixcode-encode! bp et src)
  (check-encode-table 'prefixcode-encode! et #f)
  (define (encode1 v)
    (define code (encode-table-lookup et v))
    (cond [(exact-nonnegative-integer? code) code]
          ;; Warning: This error can be wrong if table is mutated...
          [else (error 'prefixcode-encode! "no code for value\n  value: ~e" v)]))
  (cond [(bytes? src)
         (for ([b (in-bytes src)])
           (output-bitport-write-sbv bp (encode1 b)))]
        [(string? src)
         (for ([c (in-string src)])
           (output-bitport-write-sbv bp (encode1 c)))]
        [else
         (for ([v src])
           (output-bitport-write-sbv bp (encode1 v)))]))

;; encode-table-lookup : EncodeTable Any -> (U SBV #f)
(define (encode-table-lookup et v)
  (cond [(vector? et) (and (exact-nonnegative-integer? v)
                           (< v (vector-length et))
                           (vector-ref et v))]
        [(hash? et) (hash-ref et v #f)]
        [else (cond [(assoc v et) => cdr] [else #f])]))

(define (check-encode-table who ht convert-to-list?)
  (define (bad) (error who "bad encoding table\n  given: ~e" ht))
  (define (check v code)
    (unless (exact-nonnegative-integer? code) (bad)))
  (cond [(hash? ht) (for ([(v code) (in-hash ht)]) (check v code))]
        [(vector? ht) (for ([code (in-vector ht)] [v (in-naturals)]) (check v code))]
        [(list? ht) (for ([e (in-list ht)]) (match e [(cons v code) (check v code)] [_ (bad)]))])
  (and convert-to-list?
       (cond [(hash? ht) (for/list ([(v code) (in-hash ht)]) (cons v code))]
             [(vector? ht) (for/list ([code (in-vector ht)] [v (in-naturals)]) (cons v code))]
             [(list? ht) ht])))

;; ============================================================

;; A DecodeTree is (vector { DecInstr DecInstr } ...)
;; where DecInstr is one of
;; - 0              -- means invalid
;; - EvenPosFixnum  -- index of next branch node
;; - OddNat         -- represents value (N >> 1)
;; - other          -- represents self

;; This representation was chosen so that if the values are
;; readable/quotable, the tree representation is readable/quotable.

;; prefixcode-build-decode-tree : EncodeTable -> DecodeTree
;; PRE: no duplicate codes, actually a prefix code
(define (prefixcode-build-decode-tree ht)
  (begin (define make-entry cons) (define entry-value car) (define entry-code cdr))
  (define next-index 0)
  (define (get-next-index) (begin0 next-index (set! next-index (+ 2 next-index))))
  (define h (make-hasheqv))
  (define (record! index value) (hash-set! h index value))
  ;; take-entries : (Listof Entry) Bit -> (Listof Entry)
  (define (take-entries entries bit)
    (for/list ([e (in-list entries)] #:when (= (sbv-car (entry-code e)) bit))
      (make-entry (entry-value e) (sbv-cdr (entry-code e)))))
  ;; worklist-loop : (Listof (cons Index (Listof Entry))) -> Void
  (define (worklist-loop worklist)
    (when (pair? worklist)
      (worklist-loop
       (append* (for/list ([index+entries (in-list worklist)])
                  (loop (car index+entries) (cdr index+entries)))))))
  ;; loop : Index (Listof Entry) -> (Listof (cons Index (Listof Entry)))
  (define (loop index entries)
    (cond [(null? entries) null] ;; Don't record BAD instructions.
          [(and (null? (cdr entries))
                (let ([e (car entries)])
                  (sbv-empty? (entry-code e))))
           (define value (entry-value (car entries)))
           (record! index (if (exact-positive-integer? value)
                              (add1 (arithmetic-shift value 1))
                              value))
           null]
          [else
           (define branch-index (get-next-index))
           (when index (record! index branch-index))
           (list (cons (+ branch-index 0) (take-entries entries 0))
                 (cons (+ branch-index 1) (take-entries entries 1)))]))
  (let ([entries (check-encode-table 'prefixcode-build-decode-tree ht #t)])
    (worklist-loop (list (cons #f entries))))
  (let ([vec (make-vector next-index 0)]) ;; Unrecorded instructions are BAD.
    (for ([(index value) (in-hash h)])
      (vector-set! vec index value))
    (vector->immutable-vector vec)))

(define (prefixcode-decode hdt bs
                           [start-biti 0]
                           [end-biti (bytes-bit-length bs)]
                           [msf? #t]
                           #:end [end-code #f]
                           #:handle-error [handle-error default-prefixcode-decode-error])
  (define out (open-output-bytes))
  (prefixcode-decode! out hdt bs start-biti end-biti
                      #:end end-code #:handle-error handle-error)
  (get-output-bytes out))

(define (prefixcode-decode-list hdt bs
                                [start-biti 0]
                                [end-biti (bytes-bit-length bs)]
                                [msf? #t]
                                #:end [end-code #f]
                                #:handle-error [handle-error default-prefixcode-decode-error])
  (define acc null)
  (define (add! v) (set! acc (cons v acc)))
  (prefixcode-decode! add! hdt bs start-biti end-biti msf?
                      #:end end-code #:handle-error handle-error)
  (reverse acc))

(define (prefixcode-decode! output hdt bs
                            [start-biti 0]
                            [end-biti (bytes-bit-length bs)]
                            [msf? #t]
                            #:end [end-code #f]
                            #:handle-error [handle-error default-prefixcode-decode-error])
  (define (loop biti)
    (cond [(< biti end-biti)
           (define-values (status new-biti value)
             (prefixcode-decode1 hdt bs biti end-biti msf? #:end end-code))
           (case status
             [(ok)
              (cond [(output-port? output)
                     (cond [(byte? value) (write-byte value output)]
                           [(char? value) (write-char value output)]
                           [(bytes? value) (write-bytes value output)]
                           [(string? value) (write-string value output)]
                           [else (error 'prefixcode-decode
                                        "cannot write value to output\n  value: ~e"
                                        value)])]
                    [else (output value)])
              (loop new-biti)]
             [(bad incomplete)
              (handle-error status biti new-biti value)]
             [(end) (void)])]
          [else (void)]))
  (loop start-biti))

(define (default-prefixcode-decode-error status from-biti to-biti code-sbv)
  (case status
    [(bad)
     (error 'prefixcode-decode "invalid code\n  start bit index: ~e" from-biti)]
    [(incomplete)
     (error 'prefixcode-decode "incomplete code\n  start bit index: ~e" from-biti)]))

(define (prefixcode-decode1 hdt bs
                            [start-biti 0]
                            [end-biti (bytes-bit-length bs)]
                            [msf? #t]
                            #:end [end-code #f])
  (define (branch-loop biti dtindex rprefix)
    (cond [(< biti end-biti)
           (if (bytes-bit-set? bs biti msf?)
               (loop (add1 biti) (+ dtindex 1) (sbv-cons 1 rprefix))
               (loop (add1 biti) (+ dtindex 0) (sbv-cons 0 rprefix)))]
          [(and end-code (sbv-prefix? (sbv-reverse rprefix) end-code))
           (values 'end biti (sbv-reverse rprefix))]
          [else (values 'incomplete biti (sbv-reverse rprefix))]))
  (define (loop biti dtindex rprefix)
    (define dtvalue (vector-ref hdt dtindex))
    (cond [(exact-nonnegative-integer? dtvalue)
           (cond [(zero? dtvalue)
                  (values 'bad biti (sbv-reverse rprefix))]
                 [(and (fixnum? dtvalue) (not (bitwise-bit-set? dtvalue 0)))
                  (branch-loop biti dtvalue rprefix)]
                 [else ;; (bitwise-bit-set? dtvalue 0)
                  (values 'ok biti (arithmetic-shift dtvalue -1))])]
          [else (values 'ok biti dtvalue)]))
  (branch-loop start-biti 0 empty-sbv))
