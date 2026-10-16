#lang racket/base

;; LIN diagnostic frames: ID 60 (0x3C, master request) and ID 61 (0x3D,
;; slave response).  Both always carry exactly 8 data bytes and always use
;; the classic checksum.  The first two data bytes are the NAD (node
;; address) and the PCI (protocol control information); a master request
;; carries the service ID (SID) in byte 2, a slave response the RSID
;; (SID + 0x40).  The PCI of a single-frame diagnostic is 0x0N where N is
;; the number of bytes after the PCI.

(require racket/contract
         "pid.rkt"
         "frame.rkt")

(provide (contract-out
          [diagnostic-request
           (-> (integer-in 0 255) (integer-in 0 255) bytes? lin-frame?)]
          [diagnostic-response
           (-> (integer-in 0 255) (integer-in 0 255) bytes? lin-frame?)]
          [diagnostic-parse
           (-> bytes? (listof exact-nonnegative-integer?))]))

;; The NAD, PCI and SID/RSID of an 8-byte diagnostic payload, followed by
;; the remaining data bytes.
(define (diagnostic-parse data)
  (unless (= 8 (bytes-length data))
    (error 'diagnostic-parse "diagnostic frames carry 8 data byte(s), got ~a"
           (bytes-length data)))
  (list* (bytes-ref data 0)
         (bytes-ref data 1)
         (bytes->list (subbytes data 2))))

(define (diagnostic-frame pid nad sid payload)
  (unless (<= 0 (bytes-length payload) 5)
    (error 'diagnostic-frame "payload after the SID must be 0-5 byte(s), got ~a"
           (bytes-length payload)))
  (define pci (+ 1 (bytes-length payload)))
  (define data
    (bytes-append (bytes nad pci sid)
                  payload
                  (make-bytes (- 6 1 (bytes-length payload)) #xFF)))
  (frame pid data))

;; A master request frame (ID 60): NAD, PCI, SID and up to 5 data bytes.
(define (diagnostic-request nad sid payload)
  (diagnostic-frame (protected-id 60) nad sid payload))

;; A slave response frame (ID 61): NAD, PCI, RSID and up to 5 data bytes.
(define (diagnostic-response nad rsid payload)
  (diagnostic-frame (protected-id 61) nad rsid payload))
