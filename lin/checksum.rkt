#lang racket/base

;; LIN checksums: the inverted 8-bit sum with carry folding, over the data
;; bytes only ("classic", LIN 1.x) or over the protected ID plus the data
;; bytes ("enhanced", LIN 2.x).  Diagnostic frames (60/61) always use the
;; classic form.

(require racket/contract)

(provide (contract-out
          [checksum-classic (-> bytes? (integer-in 0 255))]
          [checksum-enhanced (-> (integer-in 0 255) bytes? (integer-in 0 255))]
          [checksum-valid-classic? (-> (integer-in 0 255) bytes? boolean?)]
          [checksum-valid-enhanced? (-> (integer-in 0 255) (integer-in 0 255) bytes? boolean?)]))

;; Inverted 8-bit sum with carry folding: each overflow adds 1 back to the
;; low byte (the sum of s and b is folded as s+b-255), and the result is
;; finally inverted.  The initial value `init` is 0 for the classic form
;; and the protected ID for the enhanced form.
(define (folded-sum init data)
  (for/fold ([s init])
            ([b (in-bytes data)])
    (define t (+ s b))
    (if (> t 255) (- t 255) t)))

(define (checksum-classic data)
  (bitwise-xor (folded-sum 0 data) #xFF))

(define (checksum-enhanced pid data)
  (bitwise-xor (folded-sum pid data) #xFF))

(define (checksum-valid-classic? cksum data)
  (= cksum (checksum-classic data)))

(define (checksum-valid-enhanced? cksum pid data)
  (= cksum (checksum-enhanced pid data)))
