# riscv-pipelined

[![CI](https://github.com/drewbabel/riscv-pipelined/actions/workflows/ci.yml/badge.svg)](https://github.com/drewbabel/riscv-pipelined/actions/workflows/ci.yml)

A five-stage pipelined RV32IM processor in SystemVerilog that runs CoreMark on a Digilent Nexys Video, with:

- Operands forwarded from MEM and WB, with a one-cycle interlock on the load-use hazard.
- A gshare predictor and branch target buffer that redirect fetch ahead of resolution in EX.
- Multiply on a DSP block and divide on an iterative shift-subtract unit.
- A direct-mapped instruction cache and a four-way set-associative write-back data cache with tree pseudo-LRU replacement, both with four-word lines fronting main memory.
- An arbiter that serialises both caches and the bootloader onto the DDR3 controller's application interface, proved to keep at most one transaction outstanding and to complete every request it accepts.
- Machine mode covering traps, `mtvec` dispatch, the CLINT timer interrupt, an external interrupt line the UART receiver raises, and the Zicsr instructions.
- A UART bootloader that streams programs to the board, alongside memory-mapped peripherals.

![Pipelined core block diagram](docs/pipeline_block.svg)

## Performance

### CoreMark

Compiled at `-O2` and measured on hardware at each configuration's highest clock that completes a run with validated CRCs. Scores are computed from the `mcycle` tick count, which keeps a build's clock constant out of the result.

| Configuration | Core clock | CoreMark/sec | CoreMark/MHz |
|---|---|---|---|
| Pipelined RV32IM, gshare, caches | 50.0 MHz | 76.69 | 1.53 |
| Pipelined RV32IM, gshare, uncached | 50.0 MHz | 7.91 | 0.16 |
| Pipelined RV32IM, uncached, no branch predictor | 50.0 MHz | 7.35 | 0.15 |
| Pipelined RV32I, soft multiply and divide, uncached | 50.0 MHz | 3.28 | 0.07 |
| [Single-cycle RV32I, uncached](https://github.com/drewbabel/riscv-single-cycle) | 20.0 MHz | 3.98 | 0.20 |

Every row runs against the same 512 MB of DDR3-800 behind `mem_arb`, which makes the cached score a controlled 9.7x over the uncached one at a matched clock and ISA. An uncached access is a full DDR3 transaction through `mem_word_if`, a drop-in stand-in for both caches that never reuses a line, and the core steps one instruction at a time across the memory latency. Speculative fetches flushed on a mispredicted branch each spend a whole round trip, which is why the uncached pipelined RV32I row scores below the single-cycle baseline per MHz, and caches are what make pipelining pay. The single-cycle core clocks at 20.0 MHz because one instruction is one combinational path from fetch through writeback, and its RTL is the `riscv-single-cycle` repo's core imported behind the same memory system.

### Embench

All 19 benchmarks run at `-O2` and `GLOBAL_SCALE_FACTOR=1`, measured on hardware as `mcycle` deltas against one shared 512 MB of DDR3-800, which isolates the architecture.

| Benchmark | Cached RV32IM | Uncached gshare RV32IM | Uncached no-gshare RV32IM | Uncached RV32I soft multiply and divide | Single-cycle RV32I |
|---|---|---|---|---|---|
| `aha-mont64` | 10,258,826 | 78,730,314 | 83,355,528 | 221,046,469 | 207,143,924 |
| `crc32` | 8,012,280 | 72,498,321 | 80,544,520 | 110,029,611 | 99,760,902 |
| `depthconv` | 8,513,162 | 75,198,703 | 79,898,104 | 1,021,229,835 | 900,547,379 |
| `edn` | 8,423,838 | 75,585,827 | 80,159,308 | 1,341,938,137 | 1,115,544,551 |
| `huffbench` | 5,159,358 | 54,559,722 | 59,494,658 | 59,496,508 | 45,988,144 |
| `matmult-int` | 7,781,577 | 80,600,000 | 87,183,004 | 506,032,854 | 412,929,351 |
| `md5sum` | 6,449,313 | 60,814,300 | 65,886,232 | 65,983,985 | 56,144,284 |
| `nettle-aes` | 9,730,331 | 86,808,341 | 87,267,601 | 93,332,058 | 84,163,880 |
| `nettle-sha256` | 10,355,661 | 93,990,069 | 96,173,515 | 96,277,883 | 88,583,284 |
| `nsichneu` | 12,581,532 | 76,277,828 | 76,353,859 | 76,353,875 | 56,980,471 |
| `picojpeg` | 6,538,247 | 63,179,860 | 66,933,880 | 75,602,611 | 62,799,090 |
| `qrduino` | 6,272,395 | 60,868,620 | 63,034,818 | 103,923,520 | 87,864,743 |
| `sglib-combined` | 6,178,982 | 66,998,523 | 70,783,267 | 74,201,314 | 57,397,381 |
| `slre` | 6,527,291 | 65,369,969 | 68,072,394 | 68,072,134 | 55,281,350 |
| `statemate` | 6,540,365 | 73,575,144 | 78,239,465 | 78,239,030 | 52,276,838 |
| `tarfind` | 4,886,240 | 45,420,756 | 53,449,260 | 128,277,373 | 101,686,821 |
| `ud` | 7,215,169 | 57,460,757 | 60,542,764 | 138,035,289 | 114,391,180 |
| `wikisort` | 7,366,814 | 63,944,281 | 68,970,356 | 163,844,649 | 132,099,720 |
| `xgboost` | 10,952,199 | 82,412,354 | 85,126,304 | 85,124,825 | 71,258,320 |

Both uncached RV32IM columns stay inside a narrow ~45M to ~96M band, because a full DDR3 round trip per fetch outweighs the work between fetches. The soft multiply and single-cycle columns spread wide again, since multiply-heavy workloads (`edn`, `depthconv`, `matmult-int`) pay thousands of extra instructions, each with a round trip of its own. The gshare column beats the no-gshare column on all 19 benchmarks, widest on branchy workloads like `tarfind`.

The cached column tracks the retired simulation model within tens of cycles on most benchmarks. Hardware runs measurably faster on the icache-miss-heavy ones (`nsichneu`, `xgboost`, `tarfind`, `nettle-aes`, `huffbench`), because the real controller completes a read in fewer cycles than the model's 20-cycle charge.

### Memory hierarchy

Main memory is 512 MB of DDR3-800 behind a Xilinx MIG controller, with `mem_arb` serialising both caches and the bootloader onto its native application interface. A CoreMark iteration issues 437,221 accesses, 361,461 of them instruction fetches, and misses 189 times. The instruction cache hits 99.95% of the time, the data cache 99.9997%.

Each miss costs ~10 core cycles over the same design on a single-cycle memory, measured at a divide-by-2 enable across the 189 misses an iteration incurs.

## Verification

| Method | Scope |
|--------|-------|
| riscv-formal under SymbiYosys | Every retired instruction against RV32I + M divides, machine-mode traps, Zicsr, misaligned access |
| SymbiYosys unit proofs | `muldiv` products + handshake, `csr` interrupt path by k-induction, `hazard_unit` forwarding + stall + flush, `mem_arb` against a free-latency model of the DDR3 controller |
| Spike lockstep co-simulation | Every retired instruction of a directed RV32IM program + a randomized regression |
| Reference-model testbenches | Every module, plus directed pipeline programs and FreeRTOS and CoreMark boots |
| FPGA | Full system integration on hardware, CoreMark CRCs against DDR3 + all 19 Embench cycle counts + a FreeRTOS boot |

A 32-bit multiplier is beyond in-core bounded model checking, and `insn_mul` is excluded from riscv-formal. `muldiv` proves its own products for every operand pair. The riscv-formal wrapper ties both interrupt lines low, and `formal/irq.sby` proves the trap logic separately. An interrupt is taken only when pending and enabled, a simultaneous exception outranks it, a simultaneous external and timer interrupt resolves to the external one, and `mret` restores `MIE` from `MPIE`. On the board, FreeRTOS boots and runs its tasks entirely out of DDR3, re-verified on hardware.

## Implementation

Post-route utilization per instance from AMD Vivado 2026.1 on the Xilinx Artix-7 XC7A200T, reproducible with `vivado/impl_nexys_video.tcl`, which generates the memory controller from `vivado/mig/nexys_video_mig.prj` first. `alu` and `hazard_unit` dissolve into the datapath during optimization, so they carry no standalone row.

| Instance | Logic LUTs | LUTRAM | Flip-flops | Block RAMs (18 Kb each) | DSPs |
|----------|------------|--------|------------|-------------------------|------|
| `uart_ctrl` | 3 | 0 | 11 | 0 | 0 |
| `gpio` | 4 | 0 | 8 | 0 | 0 |
| `tick_gen` | 8 | 0 | 1 | 0 | 0 |
| `mem_arb` | 19 | 0 | 452 | 0 | 0 |
| `gshare` | 20 | 64 | 10 | 0 | 0 |
| `uart_rx` | 28 | 0 | 30 | 0 | 0 |
| `uart_tx` | 30 | 0 | 27 | 0 | 0 |
| `pmu` | 32 | 0 | 0 | 0 | 0 |
| `boot_loader` | 40 | 0 | 93 | 0 | 0 |
| `clint` | 64 | 0 | 128 | 0 | 0 |
| `btb` | 100 | 76 | 64 | 0 | 0 |
| `icache` | 178 | 0 | 255 | 19 | 0 |
| `csr` | 225 | 0 | 382 | 0 | 0 |
| `regfile` | 645 | 0 | 992 | 0 | 0 |
| `muldiv` | 1856 | 0 | 239 | 0 | 15 |
| `dcache` | 2019 | 1792 | 1156 | 0 | 0 |
| `riscv_pipelined` | 3245 | 140 | 2366 | 0 | 15 |
| `board_top` (total) | 9875 | 2382 | 8557 | 19 | 15 |

The total also carries the Xilinx MIG controller, 4207 logic LUTs and 4026 flip-flops of generated IP. A single `PLLE2_BASE` feeds it a 100 MHz system clock and a 200 MHz reference clock from the board oscillator, and everything above its application interface runs from its 100 MHz user clock.

### Timing

The 100 MHz clock comes from the memory controller and the core advances on a clock enable whose divisor sets the instruction rate. AMD Vivado 2026.1 routes `board_top` at a divide-by-2 enable with no failed nets, meeting every constraint with 0.630 ns of worst setup slack and 0.049 ns of worst hold slack.

Paths between enable-gated registers carry a multicycle exception matching the enable cadence, and the worst setup path in the routed design is one of those paths. The exception covers only those registers, excluding the controller, `mem_arb`, and the enable generator, which advance every cycle. Running `vivado/impl_nexys_video.tcl 2` reproduces these figures.

## Building and running

```
make MOD=alu                                # run a module's testbench
make vsim MOD=coremark_boot                 # fast two-state Verilator run of a long testbench
make wave MOD=board_top                     # run the testbench and open the waveform in Surfer
make formal MOD=hazard_unit                 # run a module's SymbiYosys proof
make trace MOD=hazard_unit                  # print a formal counterexample as text
make view-formal MOD=hazard_unit            # open a formal waveform in Surfer
bash formal/rvfi/run.sh                     # run the full riscv-formal proof of the core
make cosim PROG=cosim_m                     # lockstep-compare an rv32im program against Spike
python3 tests/send_prog.py PORT prog.hex    # stream a program to the board over UART
vivado -mode batch -source vivado/impl_nexys_video.tcl -tclargs 2   # build the bitstream
openFPGALoader -b nexysVideo vivado/build/nv/board_top.bit          # flash it
```

The build needs Vivado for the DDR3 controller, and only the controller's project file is checked in, since generated output embeds absolute paths from the machine that produced it.

### Tool versions

Icarus Verilog 13.0, Verilator 5.050, Yosys 0.66, SymbiYosys 0.66 driving btormc and Yices 2, sv2v 0.0.13, AMD Vivado 2026.1, openFPGALoader 1.1.1, the RISC-V GNU toolchain (`riscv64-elf-gcc` 16.1.0), Python 3.11, and Surfer.
