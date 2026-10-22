# lin — LIN (Local Interconnect Network) in pure Racket

[English](README.md) · **中文**

[![CI](https://github.com/turinglambdaai/lin/actions/workflows/ci.yml/badge.svg)](https://github.com/turinglambdaai/lin/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

`lin` 实现 **LIN**（Local Interconnect Network，ISO 17987）的帧层——这种低成本单线总线在每辆车内都位于 CAN 之下，服务于车窗、座椅、后视镜及其他从设备。

全部以纯 Racket 实现。64 项受保护 ID 表与校验和向量（包括 LIN 规范 2.2A §2.8.3 的示例计算）冻结自公开的 [stm8-lin-checksum](https://github.com/basilhussain/stm8-lin-checksum) 实现（MIT），作为测试基准数据。

## 安装

```
raco pkg install lin
```

## 用法

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

### 帧

`lin-frame` 表示一帧：受保护 ID、0–8 个数据字节、校验和及其类别（`'classic` = LIN 1.x，仅数据；`'enhanced` = LIN 2.x，包含受保护 ID）。`parse-frame` 校验同步字节（`0x55`）、PID 奇偶性与校验和；诊断帧（ID 60/61）按规范始终以 classic 方式校验。

### 诊断帧

ID 60（主请求）与 61（从响应）携带 8 个数据字节：NAD、PCI、SID/RSID 与负载。

```racket
(define req (diagnostic-request #x01 #xB4 (bytes #x07 #x01)))
;; PID 0x3C, data = 01 03 B4 07 01 FF FF FF, classic checksum
(diagnostic-parse (lin-frame-data req))  ; => '(1 3 180 7 1 255 255 255)
```

### 不在范围内的事项

BREAK 字段是 UART 层面的产物（13 个显性位），由传输层处理，而非这些字节序列；调度表与 LDF 描述语言是另立的关注点。`frame-bits` 给出线上位计数（含 break），供最高 20 kbit/s 下的时序估算使用。

## 许可证

[MIT](LICENSE)。
