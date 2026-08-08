#!/usr/bin/env bash
# Usage build_board.sh [clkdiv] [flash]
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
CLKDIV=""
FLASH=""
for arg in "$@"; do
  case "$arg" in
    flash) FLASH=flash ;;
    *) CLKDIV="$arg" ;;
  esac
done
CLKDIV="${CLKDIV:-$(sed -n 's/^CLKDIV *?*= *\([0-9]*\).*/\1/p' config.mk)}"
mkdir -p build

CHIPDB="$HOME/Documents/code/nextpnr-xilinx/xilinx/xc7a35t.bin"
DBROOT="$HOME/Documents/code/nextpnr-xilinx/xilinx/external/prjxray-db/artix7"
PARTYAML="$DBROOT/xc7a35tcpg236-1/part.yaml"
PART=xc7a35tcpg236-1

PKGS="rtl/alu_pkg.sv rtl/csr_pkg.sv rtl/opcode_pkg.sv"
REST=$(ls rtl/*.sv | grep -vE 'alu_pkg|csr_pkg|opcode_pkg')
PATCHED="build/board_top_div${CLKDIV}.sv"
sed -E "s/parameter int ClkDiv = [0-9]+/parameter int ClkDiv = ${CLKDIV}/" \
  rtl/boards/basys3/board_top.sv > "$PATCHED"

echo "sv2v"
sv2v $PKGS $REST "$PATCHED" > build/design.v
echo "synth (ClkDiv=${CLKDIV}, keep pc_plus4)"
# Keep pc_plus4 nets
yosys -q -p "read_verilog build/design.v; hierarchy -top board_top; setattr -set keep 1 w:*pc_plus4*; synth_xilinx -top board_top -flatten; write_json build/design.json"
echo "pnr"
nextpnr-xilinx --chipdb "$CHIPDB" --xdc constraints/basys3.xdc \
  --json build/design.json --fasm build/design.fasm --router router2 2>&1 | grep -iE "Max frequency for clock"
echo "bitstream"
fasm2frames --db-root "$DBROOT" --part "$PART" build/design.fasm build/design.frames 2>/dev/null
xc7frames2bit --part_file "$PARTYAML" --part_name "$PART" --frm_file build/design.frames --output_file build/design.bit 2>/dev/null
echo "wrote build/design.bit"

if [ "$FLASH" = "flash" ]; then
  echo "flash"
  openFPGALoader -b basys3 build/design.bit
fi
