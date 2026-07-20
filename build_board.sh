#!/usr/bin/env bash
# Basys 3 bitstream, open flow sv2v yosys nextpnr fasm
# keep pc_plus4 else silicon jal writes pc not pc+4
# RTL correct in sim and formal, synth workaround
# pinned yosys 0.66 nextpnr-xilinx 0.8.2 sv2v 0.0.13, a bump may move the mis-opt off pc_plus4
# after any synth or toolchain change run gate_check.sh, probe2 must print CD
# usage build_board.sh [clkdiv=3] [flash]
set -euo pipefail
CLKDIV="${1:-3}"
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
mkdir -p build

CHIPDB="$HOME/Documents/code/nextpnr-xilinx/xilinx/xc7a35t.bin"
DBROOT="$HOME/Documents/code/nextpnr-xilinx/xilinx/external/prjxray-db/artix7"
PARTYAML="$DBROOT/xc7a35tcpg236-1/part.yaml"
PART=xc7a35tcpg236-1

PKGS="rtl/alu_pkg.sv rtl/csr_pkg.sv rtl/opcode_pkg.sv"
REST=$(ls rtl/*.sv | grep -vE 'alu_pkg|csr_pkg|opcode_pkg|board_top')
PATCHED="build/board_top_div${CLKDIV}.sv"
sed -E "s/parameter int ClkDiv = [0-9]+/parameter int ClkDiv = ${CLKDIV}/" rtl/board_top.sv > "$PATCHED"

echo "sv2v"
sv2v $PKGS $REST "$PATCHED" > build/design.v
echo "synth (ClkDiv=${CLKDIV}, keep pc_plus4)"
yosys -q -p "read_verilog build/design.v; hierarchy -top board_top; setattr -set keep 1 w:*pc_plus4*; synth_xilinx -top board_top -flatten -nolutram; write_json build/design.json"
echo "pnr"
nextpnr-xilinx --chipdb "$CHIPDB" --xdc constraints/basys3.xdc \
  --json build/design.json --fasm build/design.fasm --router router2 2>&1 | grep -iE "Max frequency for clock"
echo "bitstream"
fasm2frames --db-root "$DBROOT" --part "$PART" build/design.fasm build/design.frames 2>/dev/null
xc7frames2bit --part_file "$PARTYAML" --part_name "$PART" --frm_file build/design.frames --output_file build/design.bit 2>/dev/null
echo "wrote build/design.bit"

if [ "${2:-}" = "flash" ]; then
  echo "flash"
  openFPGALoader -b basys3 build/design.bit
fi
