#lang racket/base

;; LIN frame construction and parsing.  A frame on the wire is the
;; SYNC byte (0x55), the protected ID, 0-8 data bytes and the checksum;
;; the BREAK field precedes the sync byte and is handled by the UART
;; transport, so it is not part of these byte sequences.

(require racket/contract
         "pid.rkt"
         "checksum.rkt")

(provide (contract-out
          (struct lin-frame ((pid (integer-in 0 255))
                             (data bytes?)
                             (checksum (integer-in 0 255))
                             (kind (or/c 'classic 'enhanced))))
          [frame (->* ((integer-in 0 255) bytes?)
                      (#:kind (or/c 'classic 'enhanced)
                       #:checksum (or/c (integer-in 0 255) #f))
                      lin-frame?)]
          [frame-bytes (-> lin-frame? bytes?)]
          [parse-frame (->* (bytes?)
                            (#:kind (or/c 'classic 'enhanced))
                            lin-frame?)]
          [diagnostic-frame? (-> (integer-in 0 255) boolean?)]
          [frame-bits (-> exact-nonnegative-integer? exact-nonnegative-integer?)]))

(struct lin-frame (pid data checksum kind) #:transparent)

;; Diagnostic frame IDs: 60 (master request) and 61 (slave response) always
;; carry 8 data bytes and always use the classic checksum.
(define (diagnostic-frame? pid)
  (memq (frame-id pid) '(60 61)))

;; Build a frame.  The checksum defaults to the computed value for the
;; kind; diagnostic frames (IDs 60/61) always use the classic kind, per
;; the LIN 2.x specification, regardless of any explicit kind.
(define (frame pid data
               #:kind [kind #f]
               #:checksum [checksum #f])
  (unless (<= 0 (bytes-length data) 8)
    (error 'frame "a LIN frame carries 0-8 data byte(s), got ~a" (bytes-length data)))
  (unless (pid-valid? pid)
    (error 'frame "protected ID #x~a has invalid parity" (number->string pid 16)))
  (define effective-kind
    (if (diagnostic-frame? pid)
        'classic
        (or kind 'enhanced)))
  (define computed
    (case effective-kind
      [(classic) (checksum-classic data)]
      [else (checksum-enhanced pid data)]))
  (lin-frame pid data (or checksum computed) effective-kind))

;; The on-wire byte sequence (sync, PID, data, checksum) without BREAK.
(define (frame-bytes f)
  (bytes-append (bytes #x55 (lin-frame-pid f))
                (lin-frame-data f)
                (bytes (lin-frame-checksum f))))

;; Parse a frame byte sequence.  Validates the sync byte, the PID parity
;; and the checksum.  Diagnostic frames are always checked with the
;; classic form; other frames use `kind`.
(define (parse-frame bs #:kind [kind 'enhanced])
  (define n (bytes-length bs))
  (unless (>= n 3)
    (error 'parse-frame "frame too short: ~a byte(s)" n))
  (unless (= (bytes-ref bs 0) #x55)
    (error 'parse-frame "sync byte is #x~a, wants 0x55"
           (number->string (bytes-ref bs 0) 16)))
  (define pid (bytes-ref bs 1))
  (unless (pid-valid? pid)
    (error 'parse-frame "protected ID #x~a has invalid parity"
           (number->string pid 16)))
  (define data (subbytes bs 2 (- n 1)))
  (define checksum (bytes-ref bs (sub1 n)))
  (define effective-kind
    (if (diagnostic-frame? pid) 'classic kind))
  (define ok
    (case effective-kind
      [(classic) (checksum-valid-classic? checksum data)]
      [else (checksum-valid-enhanced? checksum pid data)]))
  (unless ok
    (error 'parse-frame "checksum mismatch (~a)" effective-kind))
  (lin-frame pid data checksum effective-kind))

;; The bit count of a complete frame at the UART level: 13-bit break plus
;; the delimiter, then 10 bits (start + 8 + stop) per byte of sync, PID,
;; data and checksum.  `data-length` is the number of data bytes.
(define (frame-bits data-length)
  (+ 14                       ; break + delimiter
     (* 10 (+ 2 data-length 1)))) ; sync, PID, data bytes, checksum
