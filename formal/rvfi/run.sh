#!/usr/bin/env bash
# Build and run the riscv-formal suite against the core
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
CORE=rv32i_pipe
RVF="${RISCV_FORMAL_DIR:-$HOME/Documents/code/riscv-formal}"

if [ ! -d "$RVF" ]; then
  git clone https://github.com/YosysHQ/riscv-formal.git "$RVF"
fi

DST="$RVF/cores/$CORE"
mkdir -p "$DST"
cp "$HERE/wrapper.sv" "$DST/wrapper.sv"
cp "$HERE/checks.cfg" "$DST/checks.cfg"

# every module in rtl
sv2v -D RISCV_FORMAL "$ROOT"/rtl/*.sv > "$DST/$CORE.v"

cd "$DST"
python3 "$RVF/checks/genchecks.py" >&2
ls checks/*.sby | grep -v cover.sby | xargs perl -i -pe 's/smtbmc yices/btor btormc/'

if [ "${1:-}" = "--list" ]; then
  ls checks/*.sby | xargs -n1 basename | sed 's/\.sby$//'
elif [ "$#" -gt 0 ]; then
  for c in "$@"; do sby -f "checks/$c.sby" || true; done
else
  make -j"$(getconf _NPROCESSORS_ONLN)" -C checks
fi
