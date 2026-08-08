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

| Configuration | Core clock | Main memory | CoreMark/sec | CoreMark/MHz |
|---|---|---|---|---|
| Pipelined RV32IM, gshare, caches | 50.0 MHz | 512 MB DDR3-800 behind both caches | 76.70 | 1.53 |
| [Pipelined RV32IM, gshare branch predictor](https://github.com/drewbabel/riscv-pipelined/releases/tag/v2.1-gshare) | 33.3 MHz | single-cycle, uncached | 99.37 | 2.98 |
| [Pipelined RV32IM, hardware multiply and divide](https://github.com/drewbabel/riscv-pipelined/releases/tag/v2.0-rv32im) | 33.3 MHz | single-cycle, uncached | 83.36 | 2.50 |
| [Pipelined RV32I, software multiply and divide](https://github.com/drewbabel/riscv-pipelined/releases/tag/v2.0-rv32im) | 33.3 MHz | single-cycle, uncached | 32.09 | 0.96 |
| [Single-cycle RV32I baseline](https://github.com/drewbabel/riscv-single-cycle) | 25.0 MHz | single-cycle, uncached | 34.82 | 1.39 |

The uncached configurations take `instr` and `read_data` as plain inputs with no ready handshake, so they cannot wait on a slower memory and a single-cycle model is the only one they can be attached to. That makes their CoreMark/MHz incomparable to the top row, which pays for the cache hit path, a cycle in `IDLE` before `COMPARE` on every access, costing 1.94x the cycles per iteration the uncached gshare configuration needs at a matched 33.3 MHz clock.

Each clock is a ceiling. The cached configuration produces no valid run at divide-by-1, the uncached pipelined ones fail at divide-by-2, and the single-cycle baseline fails at divide-by-3.

### Embench

All 19 benchmarks run at `-O2` and `GLOBAL_SCALE_FACTOR=1`. The pipelined core runs RV32IM and the single-cycle core runs RV32I with the libgcc soft multiply.

| Benchmark | Single-cycle cycles | Pipelined cycles | Speedup | Explanation |
|---|---|---|---|---|
| `aha-mont64` | 12,747,113 | 10,258,848 | 1.24 | Hardware multiply outweighs the stall cycles |
| `crc32` | 5,746,547 | 8,012,302 | 0.72 | Load-use stalls with no multiplies to win back |
| `depthconv` | 54,305,013 | 8,513,186 | 6.38 | Each accumulate pays a soft-multiply call on RV32I |
| `edn` | 68,368,034 | 8,423,854 | 8.12 | Soft-multiply calls dominate the RV32I run |
| `huffbench` | 2,381,259 | 5,224,182 | 0.46 | Mispredicted data-dependent branches |
| `matmult-int` | 24,655,071 | 7,781,946 | 3.17 | Hardware multiply in the inner loop |
| `md5sum` | 3,139,462 | 6,449,322 | 0.49 | Serial shift and xor chains leave only stall cost |
| `nettle-aes` | 4,402,665 | 10,017,204 | 0.44 | Stalling table loads with nothing to win back |
| `nettle-sha256` | 4,991,165 | 10,355,678 | 0.48 | Rotate and xor rounds pay only stall cost |
| `nsichneu` | 2,242,269 | 15,417,712 | 0.15 | Code outgrows the icache, 13.8% of fetches miss |
| `picojpeg` | 3,346,409 | 6,549,516 | 0.51 | Bit-reading branches outweigh the multiply savings |
| `qrduino` | 4,892,213 | 6,283,296 | 0.78 | Multiply savings partly offset the mispredicts |
| `sglib-combined` | 2,799,761 | 6,180,216 | 0.45 | Pointer-chasing loads stall back to back |
| `slre` | 2,809,560 | 6,527,320 | 0.43 | A data-dependent branch per character |
| `statemate` | 2,377,657 | 6,540,378 | 0.36 | Dense unpredictable branches |
| `tarfind` | 6,101,114 | 5,148,026 | 1.19 | Hardware multiply in the benchmark loop |
| `ud` | 6,415,329 | 7,215,180 | 0.89 | Kernel divides nearly offset the stalls |
| `wikisort` | 7,497,378 | 7,383,034 | 1.02 | Hardware divide and remainder offset the stalls |
| `xgboost` | 3,506,538 | 12,333,828 | 0.28 | Data outgrows the dcache, 22.3% of accesses miss |

### Memory hierarchy

Main memory is 512 MB of DDR3-800 behind a Xilinx MIG controller, with `mem_arb` serialising both caches and the bootloader onto its native application interface. A CoreMark iteration issues 437,207 accesses, 361,447 of them instruction fetches, and misses 189 times. The instruction cache hits 99.95% of the time, the data cache 99.9997%.

Each miss costs 10.2 cycles against the same design on a single-cycle memory. A controller read takes ~20 cycles of the 100 MHz user clock and the core advances once every 2, so a line fill reaches the core as ~10. An uncached design would pay that on every access, ~5,110,000 cycles per iteration against the measured 651,929.

## Verification

| Method | Scope |
|--------|-------|
| riscv-formal under SymbiYosys | Every retired instruction against RV32I + M divides, machine-mode traps, Zicsr, misaligned access |
| SymbiYosys unit proofs | `muldiv` products + handshake, `csr` interrupt path by k-induction, `hazard_unit` forwarding + stall + flush, `mem_arb` against a free-latency model of the DDR3 controller |
| Spike lockstep co-simulation | Every retired instruction of a directed RV32IM program + a randomized regression |
| Reference-model testbenches | Every module, plus directed pipeline programs and FreeRTOS and CoreMark boots |
| FPGA | Full system integration on hardware, CoreMark CRCs against DDR3 + all 19 Embench cycle counts + a FreeRTOS boot |

A 32-bit multiplier is beyond in-core bounded model checking, and `insn_mul` is excluded from riscv-formal. `muldiv` proves its own products for every operand pair. The riscv-formal wrapper ties both interrupt lines low, and `formal/irq.sby` proves the trap logic separately. An interrupt is taken only when pending and enabled, a simultaneous exception outranks it, a simultaneous external and timer interrupt resolves to the external one, and `mret` restores `MIE` from `MPIE`.

## Implementation

Post-route utilization per instance from AMD Vivado 2026.1 on the Xilinx Artix-7 XC7A200T, reproducible with `vivado/impl_nexys_video.tcl`, which generates the memory controller from `vivado/mig/nexys_video_mig.prj` first. `alu` and `hazard_unit` dissolve into the datapath during optimization, so they carry no standalone row.

| Instance | Logic LUTs | LUTRAM | Flip-flops | Block RAMs (18 Kb each) | DSPs |
|----------|------------|--------|------------|-------------------------|------|
| `uart_ctrl` | 3 | 0 | 11 | 0 | 0 |
| `gpio` | 4 | 0 | 8 | 0 | 0 |
| `tick_gen` | 8 | 0 | 1 | 0 | 0 |
| `mem_arb` | 19 | 0 | 452 | 0 | 0 |
| `gshare` | 22 | 64 | 10 | 0 | 0 |
| `uart_rx` | 28 | 0 | 30 | 0 | 0 |
| `uart_tx` | 30 | 0 | 27 | 0 | 0 |
| `pmu` | 32 | 0 | 0 | 0 | 0 |
| `boot_loader` | 40 | 0 | 93 | 0 | 0 |
| `clint` | 64 | 0 | 128 | 0 | 0 |
| `btb` | 100 | 76 | 64 | 0 | 0 |
| `icache` | 176 | 0 | 255 | 19 | 0 |
| `csr` | 225 | 0 | 382 | 0 | 0 |
| `regfile` | 645 | 0 | 992 | 0 | 0 |
| `muldiv` | 1854 | 0 | 239 | 0 | 15 |
| `dcache` | 2020 | 1792 | 1156 | 0 | 0 |
| `riscv_pipelined` | 3244 | 140 | 2366 | 0 | 15 |
| `board_top` (total) | 9873 | 2382 | 8557 | 19 | 15 |

The total also carries the Xilinx MIG controller, 4204 logic LUTs and 4026 flip-flops of generated IP. A single `PLLE2_BASE` feeds it a 100 MHz system clock and a 200 MHz reference clock from the board oscillator, and everything above its application interface runs from its 100 MHz user clock.

### Timing

The 100 MHz clock comes from the memory controller and the core advances on a clock enable whose divisor sets the instruction rate. AMD Vivado 2026.1 routes `board_top` at a divide-by-2 enable with no failed nets, meeting every constraint with 0.678 ns of worst setup slack and 0.012 ns of worst hold slack.

Paths between enable-gated registers carry a multicycle exception matching the enable cadence and close with 0.966 ns to spare. It covers only those registers, excluding the controller, `mem_arb`, and the enable generator, which advance every cycle. Worst slack lands on the enable distribution network, single-cycle by construction and the one path class the exception cannot cover. Running `vivado/impl_nexys_video.tcl 2` reproduces these figures.

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
