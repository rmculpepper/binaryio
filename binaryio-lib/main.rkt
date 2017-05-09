#lang racket/base
(require "private/common.rkt"
         "integer.rkt"
         "float.rkt")
(provide (all-from-out "integer.rkt")
         (all-from-out "float.rkt")
         )

;; TODO:
;; - limit parameter for variable-length data (eg, null-terminated string)
;; - call/exhaust-input raise error if port not empty when returns

;; null-terminated-{string,bytes}
;; {string,bytes}-to-eof


;; Convention on argument order:
;; - VALUE is always first in write-X
;; - PORT is always first optional argument (for consistency w/ Racket)
;; - no keyword arguments unless extraordinary need
