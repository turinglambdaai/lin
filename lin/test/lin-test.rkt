#lang racket/base

;; Tests for the lin package.  The 64-entry protected-ID table is frozen
;; from the public stm8-lin-checksum implementation (basilhussain, MIT);
;; the checksum vectors include the LIN specification 2.2A §2.8.3 example
;; calculation (data 4A 55 93 E5 -> classic 0xE6, enhanced with PID 0xBF
;; -> 0x27).

(require rackunit
         racket/file
         racket/list
         racket/runtime-path
         racket/string
         lin/pid
         lin/checksum
         lin/frame
         lin/diagnostic)

(define-runtime-path pid-table-file "data/pid-table.txt")

(define expected-protected-ids
  (map (lambda (s) (string->number s 16))
       (string-split (string-trim (file->string pid-table-file)) " ")))

;; ---------------------------------------------------------------------------
;; protected IDs

(test-case "all 64 protected IDs match the frozen table"
  (for ([id (in-range 64)]
        [pid (in-list expected-protected-ids)])
    (check-equal? (protected-id id) pid
                  (format "ID #x~a -> PID #x~a" id pid))))

(test-case "parity round trip and validation"
  (for ([id (in-range 64)])
    (define pid (protected-id id))
    (check-true (pid-valid? pid))
    (check-equal? (frame-id pid) id))
  ;; corrupting either parity bit is detected
  (for ([pid (in-list '(#xC1 #x80 #x42 #xFE))])
    (check-false (pid-valid? (bitwise-xor pid #x40)))
    (check-false (pid-valid? (bitwise-xor pid #x80)))))

(test-case "known PID values"
  (check-equal? (protected-id #x01) #xC1)
  (check-equal? (protected-id #x3C) #x3C)   ; master request: no parity bits
  (check-equal? (protected-id #x3D) #x7D))  ; slave response

;; ---------------------------------------------------------------------------
;; checksums

(test-case "classic checksum vectors (stm8-lin-checksum test suite)"
  (check-equal? (checksum-classic #"") #xFF)
  (check-equal? (checksum-classic (make-bytes 8 0)) #xFF)
  (check-equal? (checksum-classic (make-bytes 8 #xFF)) #x00)
  (check-equal? (checksum-classic (bytes #x91 #xFA)) #x73)
  ;; LIN spec 2.2A §2.8.3 example
  (check-equal? (checksum-classic (bytes #x4A #x55 #x93 #xE5)) #xE6)
  (check-equal? (checksum-classic (bytes #xA9 #xD3 #x76 #x3D #x4F #xD9 #xD3 #x5B))
                #x76))

(test-case "enhanced checksum vectors (PID 0xBF = ID 63)"
  (check-equal? (checksum-enhanced #xBF #"") #x40)
  (check-equal? (checksum-enhanced #xBF (make-bytes 8 0)) #x40)
  (check-equal? (checksum-enhanced #xBF (make-bytes 8 #xFF)) #x40)
  (check-equal? (checksum-enhanced #xBF (bytes #x91 #xFA)) #xB3)
  ;; LIN spec 2.2A §2.8.3 example
  (check-equal? (checksum-enhanced #xBF (bytes #x4A #x55 #x93 #xE5)) #x27)
  (check-equal? (checksum-enhanced #xBF (bytes #xA9 #xD3 #x76 #x3D #x4F #xD9 #xD3 #x5B))
                #xB6))

(test-case "carry folding matters"
  ;; 0x4A + 0x55 = 0x9F; + 0x93 overflows -> fold; the folded result must
  ;; differ from a plain truncated sum
  (check-not-equal? (checksum-classic (bytes #x4A #x55 #x93))
                    (bitwise-xor (remainder (+ #x4A #x55 #x93) 256) #xFF)))

;; ---------------------------------------------------------------------------
;; frames

(test-case "frame construction and byte layout"
  (define f (frame (protected-id #x11) (bytes #x4A #x55 #x93 #xE5)))
  (check-equal? (lin-frame-pid f) #x11)
  (check-equal? (lin-frame-kind f) 'enhanced)
  ;; enhanced over PID 0x11: 0x5B, B0, fold 0x143->0x44, fold 0x129->0x2A; ~0x2A
  (check-equal? (lin-frame-checksum f) #xD5)
  (check-equal? (frame-bytes f) (bytes #x55 #x11 #x4A #x55 #x93 #xE5 #xD5)))

(test-case "frame parse round trip"
  (define f (frame (protected-id #x11) (bytes #x4A #x55 #x93 #xE5)))
  (define g (parse-frame (frame-bytes f)))
  (check-equal? g f)
  ;; classic kind round trip too
  (define c (frame (protected-id #x11) (bytes #x4A #x55 #x93 #xE5) #:kind 'classic))
  (check-equal? (parse-frame (frame-bytes c) #:kind 'classic) c))

(test-case "explicit checksum overrides the computed one"
  (define f (frame (protected-id #x01) (bytes 1 2 3)
                   #:kind 'classic #:checksum #x00))
  (check-equal? (lin-frame-checksum f) 0)
  ;; parsing it back fails (the stored checksum is wrong)
  (check-exn exn:fail? (lambda () (parse-frame (frame-bytes f) #:kind 'classic))))

(test-case "parse validation"
  ;; bad sync byte
  (check-exn exn:fail?
             (lambda () (parse-frame (bytes #x54 #x11 #x4A #x55 #x93 #xE5 #xD5))))
  ;; bad parity
  (check-exn exn:fail?
             (lambda () (parse-frame (bytes #x55 #x51 #x4A #x55 #x93 #xE5 #xD5))))
  ;; wrong checksum
  (check-exn exn:fail?
             (lambda () (parse-frame (bytes #x55 #x11 #x4A #x55 #x93 #xE5 #xD4))))
  ;; too short
  (check-exn exn:fail? (lambda () (parse-frame (bytes #x55 #x11))))
  ;; empty data frames are legal (0 data bytes)
  (check-equal? (lin-frame-data (parse-frame (frame-bytes (frame (protected-id #x12) #""))))
                #""))

(test-case "diagnostic frames force the classic checksum"
  ;; enhanced checksum would differ; the frame kind is forced
  (define f (frame (protected-id #x3C) (make-bytes 8 0) #:kind 'enhanced))
  (check-equal? (lin-frame-kind f) 'classic)
  (check-equal? (frame (protected-id #x3C) (make-bytes 8 0)) f))

(test-case "frame length validation"
  (check-exn exn:fail? (lambda () (frame (protected-id #x01) (make-bytes 9))))
  (check-exn exn:fail? (lambda () (frame #x00 #""))))  ; bad parity

(test-case "frame bit counts"
  ;; break(14) + 10 bits per byte: 0 data = 3 header/checksum bytes -> 44
  (check-equal? (frame-bits 0) 44)
  (check-equal? (frame-bits 8) 124))

;; ---------------------------------------------------------------------------
;; diagnostic frames

(test-case "master request (ID 60) round trip"
  (define f (diagnostic-request #x01 #xB4 (bytes #x07 #x01)))
  (check-equal? (lin-frame-pid f) #x3C)
  (check-equal? (lin-frame-kind f) 'classic)
  (check-equal? (bytes-length (lin-frame-data f)) 8)
  (check-equal? (lin-frame-data f)
                (bytes #x01 #x03 #xB4 #x07 #x01 #xFF #xFF #xFF))
  (define g (parse-frame (frame-bytes f)))
  (check-equal? g f)
  (check-equal? (diagnostic-parse (lin-frame-data g))
                (list* 1 3 (list #xB4 #x07 #x01 #xFF #xFF #xFF))))

(test-case "slave response (ID 61) round trip"
  (define f (diagnostic-response #x01 #xF4 (bytes #x31)))
  (check-equal? (lin-frame-pid f) #x7D)
  (check-equal? (lin-frame-kind f) 'classic)
  (check-equal? (lin-frame-data f)
                (bytes #x01 #x02 #xF4 #x31 #xFF #xFF #xFF #xFF))
  (check-equal? (diagnostic-parse (lin-frame-data f))
                (list* 1 2 (list #xF4 #x31 #xFF #xFF #xFF #xFF))))

(test-case "diagnostic payload length validation"
  (check-exn exn:fail? (lambda () (diagnostic-request #x01 #xB0 (make-bytes 6)))))
