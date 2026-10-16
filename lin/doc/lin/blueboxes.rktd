1169
((3) 0 () 2 ((q lib "lin/main.rkt") (q 721 . 6)) () (h ! (equal) ((c def c (c (? . 0) q lin-frame-checksum)) c (? . 1)) ((c def c (c (? . 0) q diagnostic-response)) q (1685 . 5)) ((c def c (c (? . 0) q protected-id)) q (0 . 3)) ((c def c (c (? . 0) q frame-bytes)) q (1222 . 3)) ((c def c (c (? . 0) q checksum-valid-classic?)) q (446 . 4)) ((c def c (c (? . 0) q checksum-valid-enhanced?)) q (564 . 5)) ((c def c (c (? . 0) q checksum-classic)) q (245 . 3)) ((c def c (c (? . 0) q frame)) q (904 . 9)) ((c def c (c (? . 0) q lin-frame-pid)) c (? . 1)) ((c def c (c (? . 0) q lin-frame-data)) c (? . 1)) ((c def c (c (? . 0) q lin-frame?)) c (? . 1)) ((c def c (c (? . 0) q lin-frame)) c (? . 1)) ((c def c (c (? . 0) q diagnostic-request)) q (1530 . 5)) ((c def c (c (? . 0) q parse-frame)) q (1282 . 4)) ((c def c (c (? . 0) q lin-frame-kind)) c (? . 1)) ((c def c (c (? . 0) q pid-valid?)) q (170 . 3)) ((c def c (c (? . 0) q frame-bits)) q (1415 . 3)) ((c def c (c (? . 0) q struct:lin-frame)) c (? . 1)) ((c def c (c (? . 0) q checksum-enhanced)) q (326 . 4)) ((c def c (c (? . 0) q frame-id)) q (86 . 3)) ((c def c (c (? . 0) q diagnostic-parse)) q (1843 . 6))))
procedure
(protected-id id) -> (integer-in 0 255)
  id : (integer-in 0 63)
procedure
(frame-id pid) -> (integer-in 0 63)
  pid : (integer-in 0 255)
procedure
(pid-valid? pid) -> boolean?
  pid : (integer-in 0 255)
procedure
(checksum-classic data) -> (integer-in 0 255)
  data : bytes?
procedure
(checksum-enhanced pid data) -> (integer-in 0 255)
  pid : (integer-in 0 255)
  data : bytes?
procedure
(checksum-valid-classic? cksum data) -> boolean?
  cksum : (integer-in 0 255)
  data : bytes?
procedure
(checksum-valid-enhanced? cksum pid data) -> boolean?
  cksum : (integer-in 0 255)
  pid : (integer-in 0 255)
  data : bytes?
struct
(struct lin-frame (pid data checksum kind))
  pid : (integer-in 0 255)
  data : bytes?
  checksum : (integer-in 0 255)
  kind : (or/c 'classic 'enhanced)
procedure
(frame pid                      
       data                     
       #:kind kind              
       #:checksum checksum) -> lin-frame?
  pid : (integer-in 0 255)
  data : bytes?
  kind : (or/c 'classic 'enhanced)
  checksum : (or/c (integer-in 0 255) #f)
procedure
(frame-bytes f) -> bytes?
  f : lin-frame?
procedure
(parse-frame bs [#:kind kind]) -> lin-frame?
  bs : bytes?
  kind : (or/c 'classic 'enhanced) = 'enhanced
procedure
(frame-bits data-length) -> exact-nonnegative-integer?
  data-length : exact-nonnegative-integer?
procedure
(diagnostic-request nad sid payload) -> lin-frame?
  nad : (integer-in 0 255)
  sid : (integer-in 0 255)
  payload : bytes?
procedure
(diagnostic-response nad rsid payload) -> lin-frame?
  nad : (integer-in 0 255)
  rsid : (integer-in 0 255)
  payload : bytes?
procedure
(diagnostic-parse data)
 -> (list* exact-nonnegative-integer?
           exact-nonnegative-integer?
           (listof exact-nonnegative-integer?))
  data : bytes?
