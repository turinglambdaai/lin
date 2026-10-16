#lang racket/base

;; LIN protected identifiers: the 6-bit frame ID with the two parity bits
;; (P0 = ID0^ID1^ID2^ID4, P1 = !(ID1^ID3^ID4^ID5)) in bits 6 and 7.

(require racket/contract)

(provide (contract-out
          [protected-id (-> (integer-in 0 63) (integer-in 0 255))]
          [frame-id (-> (integer-in 0 255) (integer-in 0 63))]
          [pid-valid? (-> (integer-in 0 255) boolean?)]))

;; Parity for a 6-bit ID: P0 = ID0^ID1^ID2^ID4 (even), P1 = !(ID1^ID3^ID4^ID5)
;; (odd).  Returns the PID byte.
(define (protected-id id)
  ;; arithmetic-shift with a positive argument shifts LEFT: extract bit n
  ;; by shifting RIGHT
  (define (bit n) (bitwise-and (arithmetic-shift id (- n)) 1))
  (define p0 (bitwise-xor (bit 0) (bit 1) (bit 2) (bit 4)))
  (define p1 (bitwise-xor 1 (bit 1) (bit 3) (bit 4) (bit 5)))
  (bitwise-ior id (arithmetic-shift p0 6) (arithmetic-shift p1 7)))

;; The frame ID carried by a PID (parity bits masked off).
(define (frame-id pid)
  (bitwise-and pid #x3F))

;; Do the parity bits of `pid` match its frame ID?
(define (pid-valid? pid)
  (= pid (protected-id (frame-id pid))))
