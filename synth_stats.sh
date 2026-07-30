#!/usr/bin/env bash
set -e
TOP="$1"
test -n "$TOP" || { echo "usage: ./synth_stats.sh <top_module>"; exit 1; }
mkdir -p build
echo "$TOP (synth_xilinx, 7-series):"
sv2v rtl/*.sv > build/synth_$TOP.v
yosys -p "read_verilog build/synth_$TOP.v; synth_xilinx -top $TOP -flatten; stat" 2>/dev/null \
| awk '
    /^=== /                                       { lut=0; ff=0; carry=0; dbits=0; b18=0; b36=0 }
    /^[[:space:]]+[0-9]+[[:space:]]+LUT/          { lut  += $1 }
    /^[[:space:]]+[0-9]+[[:space:]]+FD/           { ff   += $1 }
    /^[[:space:]]+[0-9]+[[:space:]]+CARRY/        { carry+= $1 }
    /^[[:space:]]+[0-9]+[[:space:]]+RAM32X1[SD]/  { dbits += $1*32 }
    /^[[:space:]]+[0-9]+[[:space:]]+RAM32M/       { dbits += $1*256 }
    /^[[:space:]]+[0-9]+[[:space:]]+RAM64X1[SD]/  { dbits += $1*64 }
    /^[[:space:]]+[0-9]+[[:space:]]+RAM64M/       { dbits += $1*256 }
    /^[[:space:]]+[0-9]+[[:space:]]+RAM128X1[SD]/ { dbits += $1*128 }
    /^[[:space:]]+[0-9]+[[:space:]]+RAM256X1S/    { dbits += $1*256 }
    /^[[:space:]]+[0-9]+[[:space:]]+RAMB18/       { b18  += $1 }
    /^[[:space:]]+[0-9]+[[:space:]]+RAMB36/       { b36  += $1 }
    END {
      printf "  LUTs:                    %d\n", lut+0
      printf "  Flip-flops:              %d\n", ff+0
      printf "  Carry cells:             %d\n", carry+0
      printf "  Distributed RAM (bits):  %d\n", dbits+0
      printf "  Block RAM (18Kb):        %d\n", b18+b36*2
    }'
