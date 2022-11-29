;; Copyright 2019-2022 Ryan Culpepper
;; Dual-licensed under Apache 2.0 and MIT terms.

#lang racket/base
(require racket/match
         data/heap
         "bitvector.rkt")
(provide make-huffman-code)

;; A Tree is one of
;; - (leaf Real Any)
;; - (node Real Any Node Node)
(struct proto (w v) #:transparent)
(struct leaf proto () #:transparent)
(struct node proto (left right) #:transparent)

;; tree<=? : Tree Tree -> Boolean
(define (tree<=? t1 t2)
  (define w1 (proto-w t1))
  (define w2 (proto-w t2))
  (or (< w1 w2)
      (and (= w1 w2)
           ;; Note! Datum comparison reversed, so "larger" datum gets extracted
           ;; sooner, potentially gets longer code than "smaller" datum.
           (datum<=? (proto-v t2) (proto-v t1)))))

;; datum<=? : Datum Datum -> Boolean
;; order: ExactInteger < Char < Symbol < other (Not compatible with datum/order!)
(define (datum<=? a b)
  (define (isymbol? v) (and (symbol? v) (symbol-interned? v)))
  (define (symbol<=? a b) (or (eq? a b) (symbol<? a b)))
  (cond [(exact-integer? a) (if (exact-integer? b) (<= a b) #t)]
        [(char? a) (if (char? b) (char<=? a b) #t)]
        [(isymbol? a) (if (isymbol? b) (symbol<=? a b) #t)]
        [else (eqv? a b)]))

;; ----------------------------------------

;; An Alphabet is one of
;; - (Listof (cons Datum Real))
;; - (Hash Datum => Real)
;; - (Vectorof Real)
;; Zero-weight elements are still included in the code,
;; and negative weights are clipped to 0.

;; make-huffman-code : Alphabet -> EncodeTable
;; Note: options not currently allowed by main module's contract.
(define (make-huffman-code alphabet
                           #:canonical? [canonical? #t]
                           #:convert? [convert? #t])
  (define h (make-heap tree<=?))
  (define (add! v w) (heap-add! h (leaf (max w 0) v)))
  (cond [(hash? alphabet)
         (for ([(v w) (in-hash alphabet)])
           (add! v w))]
        [(vector? alphabet)
         (for ([w (in-vector alphabet)] [v (in-naturals)])
           (add! v w))]
        [else
         (for ([s (in-list alphabet)])
           (add! (car s) (cdr s)))])
  (define tree (heap->huffman-tree h))
  (define code
    (if canonical?
        (tree->canonical-code tree)
        (tree->direct-code tree)))
  (list->encode-table code
                      (cond [(not convert?) '(list)]
                            [(vector? alphabet) '(vector)]
                            [else '(hash)])))

;; heap->huffman-tree : Heap[Tree] -> Tree
;; consumes heap
(define (heap->huffman-tree h)
  (define t1 (heap-min h))
  (heap-remove-min! h)
  (cond [(zero? (heap-count h))
         t1]
        [else
         (define t2 (heap-min h))
         (heap-remove-min! h)
         (let ([w (+ (proto-w t1) (proto-w t2))]
               [v1 (proto-v t1)]
               [v2 (proto-v t2)])
           (heap-add! h
                      (if (datum<=? v1 v2)
                          (node w v1 t1 t2)
                          (node w v2 t2 t1))))
         (heap->huffman-tree h)]))

;; tree->direct-code : Tree -> (Listof (cons Datum SBV))
;; Encodes the tree directly.
(define (tree->direct-code t)
  (define (loop t rprefix)
    (match t
      [(leaf _ v)
       (list (cons v (sbv-reverse rprefix)))]
      [(node _ _ left right)
       (append (loop left (sbv-cons 0 rprefix))
               (loop right (sbv-cons 1 rprefix)))]))
  (match t
    [(leaf _ v) (list (cons v (make-sbv 0 1)))]
    [_ (loop t empty-sbv)]))

;; tree->canonical-code : Tree -> (Listof (cons Datum SBV))
(define (tree->canonical-code t)
  (define (loop ts len n)
    (if (null? ts) null (loop* ts len n)))
  (define (loop* ts len n)
    ;; len is the length of the code for a leaf in this iteration
    (define leafvs (for/list ([t (in-list ts)] #:when (leaf? t)) (proto-v t)))
    (define sorted-vs (sort leafvs datum<=?))
    (define next-ts (let loop ([ts ts])
                      (match ts
                        [(cons (node _ _ left right) ts)
                         (list* left right (loop ts))]
                        [(cons (? leaf?) ts)
                         (loop ts)]
                      ['() null])))
    (vloop sorted-vs next-ts len n))
  (define (vloop vs next-ts len n)
    (define-values (n* rvscode)
      (for/fold ([n n] [rvscode null]) ([v (in-list vs)])
        (values (add1 n) (cons (cons v (make-be-sbv n (max 1 len))) rvscode))))
    (append (reverse rvscode)
            (loop next-ts (add1 len) (arithmetic-shift n* 1))))
  (loop (list t) 0 0))

;; list->encode-table : (& List EncodeTable) (Listof Symbol) -> EncodeTable
(define (list->encode-table et types)
  (define (convert type)
    (case type
      [(hash) (for/fold ([h (hash)]) ([e (in-list et)])
                (hash-set h (car e) (cdr e)))]
      [(vector) (let ([vs (map car et)])
                  (cond [(andmap exact-nonnegative-integer? vs)
                         (define m (apply max vs))
                         (cond [(= (add1 m) (length vs))
                                (define vec (make-vector (add1 m) 0))
                                (for ([e (in-list et)])
                                  (vector-set! vec (car e) (cdr e)))
                                vec]
                               [else #f])]
                        [else #f]))]
      [(list) et]
      [else #f]))
  (or (ormap convert types) et))

(module+ private-for-testing
  (define (code->sexpr es)
    (define (entry v code) (list v (sbv->string code)))
    (cond [(hash? es)
           (cons 'hash
                 (for/list ([v (in-list (hash-keys es #t))])
                   (entry v (hash-ref es v))))]
          [(vector? es)
           (cons 'vector
                 (for/list ([code (in-vector es)] [v (in-naturals)])
                   (entry v code)))]
          [(list? es)
           (cons 'list
                 (for/list ([e (in-list es)])
                   (match-define (cons v code) e)
                   (entry v code)))]))
  (provide code->sexpr))
