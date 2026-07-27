# Embench IoT results

All 19 benchmarks at `GLOBAL_SCALE_FACTOR=1` and `WARMUP_HEAT=1`, measured in cycle-accurate simulation against the pipelined RV32IM core and the RV32I core of [riscv-single-cycle](https://github.com/drewbabel/riscv-single-cycle).

Cycle counts come from `mcycle` read around the timed region in `boardsupport.c`. Every benchmark returned its expected verification result on both cores.

| Benchmark | Single-cycle cycles | Pipelined cycles | Speedup |
|---|---|---|---|
| `aha-mont64` | 12,747,113 | 10,258,848 | 1.24 |
| `crc32` | 5,746,547 | 8,012,302 | 0.72 |
| `depthconv` | 54,305,013 | 8,513,186 | 6.38 |
| `edn` | 68,368,034 | 8,423,854 | 8.12 |
| `huffbench` | 2,381,259 | 5,224,182 | 0.46 |
| `matmult-int` | 24,655,071 | 7,781,946 | 3.17 |
| `md5sum` | 3,139,462 | 6,449,322 | 0.49 |
| `nettle-aes` | 4,402,665 | 10,017,204 | 0.44 |
| `nettle-sha256` | 4,991,165 | 10,355,678 | 0.48 |
| `nsichneu` | 2,242,269 | 15,417,712 | 0.15 |
| `picojpeg` | 3,346,409 | 6,549,516 | 0.51 |
| `qrduino` | 4,892,213 | 6,283,296 | 0.78 |
| `sglib-combined` | 2,799,761 | 6,180,216 | 0.45 |
| `slre` | 2,809,560 | 6,527,320 | 0.43 |
| `statemate` | 2,377,657 | 6,540,378 | 0.36 |
| `tarfind` | 6,101,114 | 5,148,026 | 1.19 |
| `ud` | 6,415,329 | 7,215,180 | 0.89 |
| `wikisort` | 7,497,378 | 7,383,034 | 1.02 |
| `xgboost` | 3,506,538 | 12,333,828 | 0.28 |

The speedup is single-cycle cycles divided by pipelined cycles, so a value above 1 means the pipelined core needed fewer cycles. The geometric mean across the suite is 0.78.

## Method

```
make -C sw/embench all                                              # RV32IM images
make vsim MOD=embench_boot PLUSARGS=+HEX=sw/embench/crc32.hex       # one benchmark
make -C sw/embench clean && make -C sw/embench ARCH=rv32i_zicsr all # RV32I images
```

The RV32I images run against the `riscv-single-cycle` RTL under Verilator with an equivalent testbench, since the two cores share a memory map, a 64 KB image, and a UART.

Both testbenches instantiate `board_top` at `DEPTH=16384` and `ClkDiv=4`, load the image through the memory backdoor, and read the reported cycle count off the serial line. Cycle counts are independent of `ClkDiv`. Run against the CoreMark image the same harness reports 1,610,380 ticks on the pipelined core and 718,010 on the single-cycle core, matching each README.

Every benchmark fits the 64 KB image. The largest is `xgboost` at 50,436 bytes, and none were excluded.

## Reading the table

The single-cycle core retires one instruction per clock against a zero-wait block RAM, fixing its CPI at 1. The pipelined core spends extra cycles on branch mispredictions, the load-use interlock, and cache misses served by the 20-cycle memory model, so a cycle comparison flatters the simpler design. Clock rate is the other half and the Performance section of each README carries the synthesized figures.

`depthconv`, `edn`, and `matmult-int` reach the libgcc soft multiply routine on RV32I where the pipelined core issues a single `mul`.

The instruction cache is 8 KB direct-mapped and the data cache is 8 KB four-way. `nsichneu` carries a 29 KB text section and misses 13.8 percent of its instruction fetches, which is where its 15.4 million cycles go. `xgboost` misses 22.3 percent of its data accesses against a working set larger than the data cache.
