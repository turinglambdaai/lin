#lang scribble/manual
@(require (for-label racket/base
                     racket/contract
                     lin)
          scribble/example)

@(define lin-eval (make-base-eval #:lang 'racket/base '(require lin)))

@title[#:tag "lin"]{lin: Local Interconnect Network frames}
@author{turinglambdaai}

@defmodule[lin]

The @filepath{lin} package implements the frame layer of @deftech{LIN}
(Local Interconnect Network, ISO 17987) — the low-cost single-wire bus
that sits under CAN in every vehicle for window lifts, seats, mirrors and
other slave devices.

Everything is implemented in pure Racket.  The 64-entry protected-ID
table and the checksum vectors (including the LIN specification 2.2A
§2.8.3 example calculation) are frozen from the public
@hyperlink["https://github.com/basilhussain/stm8-lin-checksum"]{stm8-lin-checksum}
implementation as test fixtures.

@section{Quick start}

@examples[
#:eval lin-eval
(protected-id #x01)
(protected-id #x3C)
(checksum-classic (bytes #x4A #x55 #x93 #xE5))
(checksum-enhanced #xBF (bytes #x4A #x55 #x93 #xE5))
(define f (frame (protected-id #x11) (bytes #x4A #x55 #x93 #xE5)))
(frame-bytes f)
(parse-frame (frame-bytes f))
]

@section{Protected identifiers}

A LIN frame is addressed by a 6-bit ID; on the wire it carries two parity
bits in the high positions: @tt{P0 = ID0^ID1^ID2^ID4} (even) and
@tt{P1 = !(ID1^ID3^ID4^ID5)} (odd).

@defproc[(protected-id [id (integer-in 0 63)]) (integer-in 0 255)]{
 The protected ID for a frame ID.  Diagnostic IDs 60/61 keep their bare
 values (their parity bits are 0).
}

@defproc[(frame-id [pid (integer-in 0 255)]) (integer-in 0 63)]{
 The frame ID carried by a PID (parity bits masked off).
}

@defproc[(pid-valid? [pid (integer-in 0 255)]) boolean?]{
 Do the parity bits of @racket[pid] match its frame ID?
}

@section{Checksums}

The LIN checksum is an inverted 8-bit sum with carry folding: each
overflow adds 1 back to the low byte, and the final sum is inverted.
The @deftech{classic} form (LIN 1.x) covers the data bytes only; the
@deftech{enhanced} form (LIN 2.x) starts from the protected ID.
Diagnostic frames (IDs 60/61) always use the classic form.

@defproc[(checksum-classic [data bytes?]) (integer-in 0 255)]
@defproc[(checksum-enhanced [pid (integer-in 0 255)] [data bytes?]) (integer-in 0 255)]
@defproc[(checksum-valid-classic? [cksum (integer-in 0 255)] [data bytes?]) boolean?]
@defproc[(checksum-valid-enhanced? [cksum (integer-in 0 255)] [pid (integer-in 0 255)] [data bytes?]) boolean?]

@section{Frames}

@defstruct*[lin-frame ([pid (integer-in 0 255)]
                       [data bytes?]
                       [checksum (integer-in 0 255)]
                       [kind (or/c 'classic 'enhanced)])]{
 One frame: the protected ID, 0-8 data bytes, the checksum and its kind.
}

@defproc[(frame [pid (integer-in 0 255)] [data bytes?]
                [#:kind kind (or/c 'classic 'enhanced)]
                [#:checksum checksum (or/c (integer-in 0 255) #f)])
         lin-frame?]{
 Builds a frame; the checksum defaults to the computed value for the
 kind.  Diagnostic frames (IDs 60/61) are forced to the classic kind.
 Invalid parity, more than 8 data bytes — errors.
}

@defproc[(frame-bytes [f lin-frame?]) bytes?]{
 The on-wire byte sequence: sync (@tt{0x55}), PID, data, checksum.  The
 BREAK field is a UART-level artifact handled by the transport and is not
 part of these bytes.
}

@defproc[(parse-frame [bs bytes?]
                      [#:kind kind (or/c 'classic 'enhanced) 'enhanced])
         lin-frame?]{
 Parses and validates a frame byte sequence: the sync byte must be
 @tt{0x55}, the PID parity must hold, and the checksum must match
 (diagnostic frames are always checked as classic).  Violations raise
 @racket[exn:fail].
}

@defproc[(frame-bits [data-length exact-nonnegative-integer?])
         exact-nonnegative-integer?]{
 The on-wire bit count of a complete frame: the 13-bit break plus
 delimiter and 10 bits (start + 8 data + stop) per byte of sync, PID,
 data and checksum — for timing estimates at the 1-20 kbit/s LIN rates.
}

@section{Diagnostic frames}

IDs 60 (master request) and 61 (slave response) always carry 8 data
bytes: NAD, PCI, SID/RSID and payload; the PCI of a single-frame
diagnostic is @tt{0x0N} with N the number of bytes after the PCI.

@defproc[(diagnostic-request [nad (integer-in 0 255)]
                             [sid (integer-in 0 255)]
                             [payload bytes?])
         lin-frame?]{
 A master request frame (ID 60): NAD, PCI, SID and up to 5 data bytes.
}

@defproc[(diagnostic-response [nad (integer-in 0 255)]
                              [rsid (integer-in 0 255)]
                              [payload bytes?])
         lin-frame?]{
 A slave response frame (ID 61): NAD, PCI, RSID and up to 5 data bytes.
}

@defproc[(diagnostic-parse [data bytes?])
         (list* exact-nonnegative-integer?
                exact-nonnegative-integer?
                (listof exact-nonnegative-integer?))]{
 The NAD, PCI and remaining bytes of an 8-byte diagnostic payload.
}

@section{License}

MIT.  Test fixtures derive from stm8-lin-checksum (MIT).
