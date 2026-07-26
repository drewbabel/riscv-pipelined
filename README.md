# riscv-pipelined

[![CI](https://github.com/drewbabel/riscv-pipelined/actions/workflows/ci.yml/badge.svg)](https://github.com/drewbabel/riscv-pipelined/actions/workflows/ci.yml)

A five-stage pipelined RV32IM processor in SystemVerilog that runs CoreMark on a Digilent Basys 3, with:

- Operands forwarded from MEM and WB, with a one-cycle interlock on the load-use hazard.
- A gshare predictor and branch target buffer that redirect fetch ahead of resolution in EX.
- Multiply on a DSP block and divide on an iterative shift-subtract unit.
- A direct-mapped instruction cache and a four-way set-associative write-back data cache with tree pseudo-LRU replacement, both with four-word lines fronting main memory.
- Machine mode covering traps, `mtvec` dispatch, the CLINT timer interrupt, and the Zicsr instructions.
- A UART bootloader that streams programs to the board, alongside memory-mapped peripherals.

![Pipelined core block diagram](docs/pipeline_block.svg)

## Performance

### CoreMark

| Configuration | Clock | CoreMark/sec | CoreMark/MHz |
|---------------|-------|--------------|--------------|
| Pipelined RV32IM, caches, 20-cycle memory model | 25.0 MHz | 15.61 | 0.62 |
| [Pipelined RV32IM, gshare branch predictor](https://github.com/drewbabel/riscv-pipelined/releases/tag/v2.1-gshare) | 33.3 MHz | 99.37 | 2.98 |
| [Pipelined RV32IM, hardware multiply and divide](https://github.com/drewbabel/riscv-pipelined/releases/tag/v2.0-rv32im) | 33.3 MHz | 83.36 | 2.50 |
| [Pipelined RV32I, software multiply and divide](https://github.com/drewbabel/riscv-pipelined/releases/tag/v2.0-rv32im) | 33.3 MHz | 32.09 | 0.96 |
| [Single-cycle RV32I baseline](https://github.com/drewbabel/riscv-single-cycle) | 20.0 MHz | 27.85 | 1.39 |

### Memory hierarchy

The Basys 3 carries no DRAM. `mem_delay` stands in for one, a synthesizable main memory parameterized by latency and completing through a ready handshake. The cache rows below are measured on the board at a divide-by-4 core enable, with ticks and hit rates identical to simulation. A 200-iteration run validates the CRCs on hardware over 12.8 seconds.

| Configuration | Total ticks | Iterations/sec | Instruction cache | Data cache |
|---|---|---|---|---|
| No caches, single-cycle memory | 845,818 | 39.41 | | |
| Caches, 1-cycle memory | 1,597,690 | 20.86 | 99.8% hit | 99.6% hit |
| Caches, 20-cycle memory | 1,610,380 | 20.70 | 99.8% hit, 2.04 cycle AMAT | 99.6% hit, 2.08 cycle AMAT |

A 20x increase in memory latency costs 0.8%, against roughly 21 cycles for an uncached access. Hit latency accounts for the remaining gap to the uncached figure, since both controllers spend a cycle in `IDLE` before `COMPARE`.

## Verification

| Method | Scope |
|--------|-------|
| riscv-formal under SymbiYosys | Every retired instruction against RV32I + M divides, machine-mode traps, Zicsr, misaligned access |
| SymbiYosys unit proofs | `muldiv` products + handshake, `csr` interrupt path by k-induction, `hazard_unit` forwarding + stall + flush |
| Spike lockstep co-simulation | Every retired instruction of a directed RV32IM program + a randomized regression |
| Reference-model testbenches | Every module, plus directed pipeline programs and FreeRTOS and CoreMark boots |
| Basys 3 | Full system integration, CoreMark CRCs on hardware |

A 32-bit multiplier is beyond in-core bounded model checking, and `insn_mul` is excluded from riscv-formal. `muldiv` proves its own products for every operand pair. The riscv-formal wrapper ties the timer interrupt low, and `formal/irq.sby` proves the trap logic separately. An interrupt is taken only when pending and enabled, a simultaneous exception outranks it, and `mret` restores `MIE` from `MPIE`.

## Implementation

Synthesized for the Xilinx Artix-7 XC7A35T through sv2v, Yosys, and nextpnr-xilinx.

| Module | LUTs | Flip-flops | Block RAMs (18 Kb each) |
|--------|------|------------|-------------------------|
| `hazard_unit` | 23 | 0 | 0 |
| `gshare` | 46 | 10 | 0 |
| `btb` | 112 | 64 | 0 |
| `icache` \* | 216 | 256 | 19 |
| `alu` | 492 | 0 | 0 |
| `muldiv` | 567 | 240 | 0 |
| `mem_delay` \* | 155 | 148 | 32 |
| `csr` | 736 | 383 | 0 |
| `regfile` | 1050 | 992 | 0 |
| `dcache` \* | 5176 | 1284 | 0 |
| `riscv_pipelined` | 3778 | 2419 | 0 |

\* Block RAM has no asynchronous read port. Every tag and data array is registered and single-ported, with valid and dirty packed into the tag word and a reset walk clearing the tags before the cache accepts a request. Block-RAM arrays are split into byte lanes, since nextpnr-xilinx misconfigures 9-bit block-RAM ports and every parity bit reads zero ([openXC7/nextpnr-xilinx#95](https://github.com/openXC7/nextpnr-xilinx/pull/95)). The data cache's shallow arrays use distributed RAM, and replacement state stays in flops.

## Building and running

```
make MOD=alu                                # run a module's testbench
make vsim MOD=coremark_boot                 # fast two-state Verilator run of a long testbench
make wave MOD=board_top                     # run the testbench and open the waveform in Surfer
make formal MOD=hazard_unit                 # run a module's SymbiYosys proof
bash formal/rvfi/run.sh                     # run the full riscv-formal proof of the core
make cosim PROG=cosim_m                     # lockstep-compare an rv32im program against Spike
python3 tests/send_prog.py PORT prog.hex    # stream a program to the board over UART
./build_board.sh 4 flash                    # build the bitstream at divide-by-4 and flash
./synth_stats.sh riscv_pipelined            # report a module's synthesis cost
```

`build_board.sh` preserves the `pc_plus4` nets with `setattr -set keep 1 w:*pc_plus4*`, because the Yosys `xilinx_srl` pass otherwise drops the clock enable on the `pc_plus4` shift register ([YosysHQ/yosys#6059](https://github.com/YosysHQ/yosys/pull/6059)). `gate_check.sh` re-verifies the workaround after any toolchain change.

### Tool versions

Icarus Verilog 13.0, Verilator 5.050, Yosys 0.66, SymbiYosys 0.66 driving btormc and Yices 2, sv2v 0.0.13, nextpnr-xilinx 0.8.2, the RISC-V GNU toolchain (`riscv64-elf-gcc` 16.1.0), Python 3.11, and Surfer.
