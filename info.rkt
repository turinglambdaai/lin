#lang info

(define version "0.1")
;; Multi-collection package shape: the collection is the `lin/` subdirectory.
(define collection 'multi)
;; rackunit-lib is a run-time dependency because the package ships its test
;; suite and the catalog's dependency check scans shipped modules in run mode.
(define deps '("base" "rackunit-lib"))
(define build-deps '("base" "scribble-lib" "racket-doc" "rackunit-lib"))
(define pkg-desc "Pure-Racket LIN (Local Interconnect Network, ISO 17987) frames: protected-ID parity, classic and enhanced checksums, frame codec and diagnostic frames 60/61")
(define pkg-authors '("turinglambdaai"))
(define license 'MIT)
;; Documentation is declared in lin/info.rkt (collection level) — `raco
;; setup` only discovers scribblings from a collection's own info.rkt for
;; `collection 'multi` packages.
(define test-omit-paths '("lin/scribblings"))
