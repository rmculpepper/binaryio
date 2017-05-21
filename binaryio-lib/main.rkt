#lang racket/base
(require "bytes.rkt"
         "integer.rkt"
         "float.rkt")
(provide (all-from-out "bytes.rkt")
         (all-from-out "integer.rkt")
         (all-from-out "float.rkt"))

;; TODO:
;; - limit parameter for variable-length data (eg, null-terminated string)
;; - call/exhaust-input raise error if port not empty when returns

;; Convention on argument order:
;; - VALUE is always first in write-X
;; - PORT is always first optional argument (for consistency w/ Racket)
;; - no keyword arguments unless extraordinary need
;; * unlike racket, boolean? enforced on boolean args, to prevent reordering mistakes
