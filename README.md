# lin — LIN (Local Interconnect Network) in pure Racket

**English** · [中文](README.zh-CN.md)

[![CI](https://github.com/turinglambdaai/lin/actions/workflows/ci.yml/badge.svg)](https://github.com/turinglambdaai/lin/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

`lin` implements the frame layer of **LIN** (Local Interconnect Network,
ISO 17987) — the low-cost single-wire bus that sits under CAN in every
vehicle for window lifts, seats, mirrors and other slave devices.

Everything is implemented in pure Racket.  The 64-entry protected-ID
table and the checksum vectors (including the LIN specification 2.2A
§2.8.3 example calculation) are frozen from the public
[stm8-lin-checksum](https://github.com/basilhussain/stm8-lin-checksum)
implementation (MIT) as test fixtures.

## Installation

```
raco pkg install lin
```

## Usage

```racket
(require lin)

;; frame IDs get two parity bits on the wire
(protected-id #x01)   ; => 193 (#xC1)
(protected-id #x3C)   ; => 60  (#x3C — diagnostic frames carry no parity bits)

;; checksums: inverted 8-bit sum with carry folding
(checksum-classic (bytes #x4A #x55 #x93 #xE5))          ; => 230 (#xE6)
(checksum-enhanced #xBF (bytes #x4A #x55 #x93 #xE5))    ; => 39  (#x27)
;; both values are the LIN 2.2A spec example calculation

;; build, serialize and parse frames
(define f (frame (protected-id #x11) (bytes #x4A #x55 #x93 #xE5)))
(frame-bytes f)   ; => #"\125\021\112\125\223\345\307"  (sync, PID, data, checksum)
(parse-frame (frame-bytes f))  ; => the same frame, all fields validated
```

### Frames

`lin-frame` is one frame: the protected ID, 0-8 data bytes, the checksum
and its kind (`'classic` = LIN 1.x, data only; `'enhanced` = LIN 2.x,
protected ID included).  `parse-frame` validates the sync byte (`0x55`),
the PID parity and the checksum; diagnostic frames (IDs 60/61) are always
validated as classic, per the specification.

### Diagnostic frames

IDs 60 (master request) and 61 (slave response) carry 8 data bytes: NAD,
PCI, SID/RSID and payload.

```racket
(define req (diagnostic-request #x01 #xB4 (bytes #x07 #x01)))
;; PID 0x3C, data = 01 03 B4 07 01 FF FF FF, classic checksum
(diagnostic-parse (lin-frame-data req))  ; => '(1 3 180 7 1 255 255 255)
```

### What is out of scope

The BREAK field is a UART-level artifact (13 dominant bits) handled by
the transport, not by these byte sequences; schedule tables and the LDF
description language are separate concerns.  `frame-bits` gives the
on-wire bit count (break included) for timing estimates at up to
20 kbit/s.

## License

[MIT](LICENSE).
