#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
mkdir -p build
CELLS=$(find "$(dirname "$(command -v yosys)")/.." -name cells_sim.v -path '*xilinx*' 2>/dev/null | head -1)
PKGS="rtl/alu_pkg.sv rtl/csr_pkg.sv rtl/opcode_pkg.sv"
REST=$(ls rtl/*.sv | grep -vE 'alu_pkg|csr_pkg|opcode_pkg|board_top')

riscv64-elf-gcc -march=rv32i_zicsr -mabi=ilp32 -nostdlib -nostartfiles -T sw/coremark/link.ld \
  -o build/jalret.elf tests/jalret.s
riscv64-elf-objcopy -O verilog --verilog-data-width=4 -j .text build/jalret.elf build/jalret.hex

sv2v $PKGS $REST rtl/board_top.sv > build/check_design.v
yosys -q -p "read_verilog build/check_design.v; hierarchy -top riscv_pipelined; setattr -set keep 1 w:*pc_plus4*; synth_xilinx -top riscv_pipelined -flatten -nolutram; write_verilog -noattr build/core_gate.v"
sed "s/\.INIT(1'hx)/.INIT(1'h0)/g" build/core_gate.v > build/core_gate0.v
perl -0pe 's/riscv_pipelined #\(\s*\.XLEN\(XLEN\)\s*\)\s*riscv_pipelined_inst/riscv_pipelined riscv_pipelined_inst/s' rtl/board_top.sv > build/board_top_check.sv

iverilog -g2012 -s gate_check_tb -o build/check.sim $PKGS "$CELLS" build/core_gate0.v \
  build/board_top_check.sv rtl/mem.sv rtl/boot_loader.sv rtl/clint.sv rtl/uart_rx.sv rtl/uart_tx.sv \
  rtl/synchronizer.sv rtl/tick_gen.sv tb/gate_check_tb.sv 2>/dev/null

OUT=$(vvp build/check.sim +HEX=build/jalret.hex 2>/dev/null | LC_ALL=C tr -cd 'A-Za-z')
if echo "$OUT" | grep -q "CD"; then
  echo "GATE CHECK PASS, printed CD"
else
  echo "GATE CHECK FAIL, expected CD got '$OUT' (pc_plus4 keep not holding)"
  exit 1
fi
