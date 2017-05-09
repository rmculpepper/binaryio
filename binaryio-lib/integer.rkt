#lang racket/base
(require racket/contract/base
         "private/integer.rkt")

;; FIXME: contract for integer->bytes

(provide int1?  int2?  int3?  int4?  int8?  make-intN?
         uint1? uint2? uint3? uint4? uint8? make-uintN?
         (contract-out
          [integer->bytes
           (->* [exact-integer? (or/c exact-nonnegative-integer? #f) any/c any/c] []
                bytes?)]
          [bytes->integer
           (->* [bytes? any/c any/c] []
                exact-integer?)]

          [write-int1 (->* [int1?] [output-port?] any)]
          [write-int2 (->* [int2?] [output-port?] any)]
          [write-int3 (->* [int3?] [output-port?] any)]
          [write-int4 (->* [int4?] [output-port?] any)]
          [write-int8 (->* [int8?] [output-port?] any)]
          [write-intN (->i ([size exact-nonnegative-integer?]
                            [val (size) (make-intN? size)])
                           ([p output-port?])
                           any)]

          [write-uint1 (->* [uint1?] [output-port?] any)]
          [write-uint2 (->* [uint2?] [output-port?] any)]
          [write-uint3 (->* [uint3?] [output-port?] any)]
          [write-uint4 (->* [uint4?] [output-port?] any)]
          [write-uint8 (->* [uint8?] [output-port?] any)]
          [write-uintN (->i ([size exact-nonnegative-integer?]
                             [val (size) (make-uintN? size)])
                            ([p output-port?])
                            any)]

          [read-int1 (->* [] [input-port?] any)]
          [read-int2 (->* [] [input-port?] any)]
          [read-int3 (->* [] [input-port?] any)]
          [read-int4 (->* [] [input-port?] any)]
          [read-int8 (->* [] [input-port?] any)]
          [read-intN (->* [exact-nonnegative-integer?] [input-port?] any)]

          [read-uint1 (->* [] [input-port?] any)]
          [read-uint2 (->* [] [input-port?] any)]
          [read-uint3 (->* [] [input-port?] any)]
          [read-uint4 (->* [] [input-port?] any)]
          [read-uint8 (->* [] [input-port?] any)]
          [read-uintN (->* [exact-nonnegative-integer?] [input-port?] any)]

          [write-le-int1 (->* [int1?] [output-port?] any)]
          [write-le-int2 (->* [int2?] [output-port?] any)]
          [write-le-int3 (->* [int3?] [output-port?] any)]
          [write-le-int4 (->* [int4?] [output-port?] any)]
          [write-le-int8 (->* [int8?] [output-port?] any)]
          [write-le-intN (->i ([size exact-nonnegative-integer?]
                               [val (size) (make-intN? size)])
                              ([p output-port?])
                              any)]

          [write-le-uint1 (->* [uint1?] [output-port?] any)]
          [write-le-uint2 (->* [uint2?] [output-port?] any)]
          [write-le-uint3 (->* [uint3?] [output-port?] any)]
          [write-le-uint4 (->* [uint4?] [output-port?] any)]
          [write-le-uint8 (->* [uint8?] [output-port?] any)]
          [write-le-uintN (->i ([size exact-nonnegative-integer?]
                                [val (size) (make-uintN? size)])
                               ([p output-port?])
                               any)]

          [read-le-int1 (->* [] [input-port?] any)]
          [read-le-int2 (->* [] [input-port?] any)]
          [read-le-int3 (->* [] [input-port?] any)]
          [read-le-int4 (->* [] [input-port?] any)]
          [read-le-int8 (->* [] [input-port?] any)]
          [read-le-intN (->* [exact-nonnegative-integer?] [input-port?] any)]

          [read-le-uint1 (->* [] [input-port?] any)]
          [read-le-uint2 (->* [] [input-port?] any)]
          [read-le-uint3 (->* [] [input-port?] any)]
          [read-le-uint4 (->* [] [input-port?] any)]
          [read-le-uint8 (->* [] [input-port?] any)]
          [read-le-uintN (->* [exact-nonnegative-integer?] [input-port?] any)]
          ))
