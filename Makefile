#   make MOD=pc                  compile rtl/ + that tb, run (FAIL exits nonzero)
#   make vsim MOD=pc             fast 2-state Verilator run (perf sweeps + regression; not X-debug)
#   make wave MOD=alu            same, then open the waveform in surfer (opens even on FAIL)
#   make view MOD=alu            open testbench waveform in surfer (no rerun) (error if .vcd missing)
#   make formal MOD=alu          run every SymbiYosys task in formal/$(MOD).sby (FAIL exits nonzero)
#   make trace MOD=alu           print a formal counterexample as text
#   make view-formal MOD=alu     open a formal waveform in surfer; error if .vcd missing
#   make hex PROG=program        assemble tests/$(PROG).s -> tests/$(PROG).hex for $readmemh
#   make dis PROG=program        disassemble the built elf (sanity-check the machine code)
#   make cosim PROG=cosim1       lockstep-compare tests/cosim1.s against Spike (needs spike installed)
#   make clean                   delete build artifacts (build/, *.vcd)

# packages must compile before any module that imports them
PKGS := rtl/alu_pkg.sv rtl/csr_pkg.sv rtl/opcode_pkg.sv rtl/muldiv_pkg.sv rtl/bp_pkg.sv rtl/cache_pkg.sv
RTL := $(PKGS) $(filter-out $(PKGS),$(wildcard rtl/*.sv))
TB  := tb/$(MOD)_tb.sv
SIM := build/sim
VDIR := build/vobj_$(MOD)
VCD := $(MOD)_tb.vcd
WAVE_STATE := tb/$(MOD).ron
FORMAL := formal/$(MOD).sby

# program build: RISC-V assembly -> hex words for $readmemh
RVGCC   := riscv64-elf-gcc
RVCOPY  := riscv64-elf-objcopy
RVDUMP  := riscv64-elf-objdump
RVFLAGS := -march=rv32im_zicsr -mabi=ilp32 -nostdlib -nostartfiles -T tests/link.ld

run:
	@test -n "$(MOD)" || { echo "usage: make MOD=<module>  (e.g. MOD=alu)"; exit 1; }
	@mkdir -p build
	iverilog -g2012 -DSIM_BACKDOOR -s $(MOD)_tb -o $(SIM) $(RTL) $(TB)
	vvp $(SIM)

vsim:
	@test -n "$(MOD)" || { echo "usage: make vsim MOD=<module>  (fast 2-state Verilator run)"; exit 1; }
	@mkdir -p build
	verilator --binary --timing -O3 -j 4 -DSIM_BACKDOOR -Wno-fatal -Wno-WIDTH \
		--top-module $(MOD)_tb -Mdir $(VDIR) -o $(MOD)_vsim $(RTL) $(TB)
	$(VDIR)/$(MOD)_vsim $(PLUSARGS)

prog:
	@test -n "$(PROG)" || { echo "usage: make prog PROG=<name>  (tests/<name>.s, PASS = x28==1)"; exit 1; }
	@mkdir -p build
	$(RVGCC) $(RVFLAGS) -o build/$(PROG).elf tests/$(PROG).s
	$(RVCOPY) -O verilog --verilog-data-width=4 build/$(PROG).elf tests/$(PROG).hex
	iverilog -g2012 -s prog_tb -o $(SIM) $(RTL) tb/prog_tb.sv
	vvp $(SIM) +HEX=tests/$(PROG).hex

wave:
	@test -n "$(MOD)" || { echo "usage: make wave MOD=<module>"; exit 1; }
	@mkdir -p build
	iverilog -g2012 -DSIM_BACKDOOR -s $(MOD)_tb -o $(SIM) $(RTL) $(TB)
	-vvp $(SIM)
	surfer $(VCD) $$(test -f $(WAVE_STATE) && echo "-s $(WAVE_STATE)") &

formal:
	@test -n "$(MOD)" || { echo "usage: make formal MOD=<module>  (e.g. MOD=alu)"; exit 1; }
	@mkdir -p build
	sv2v -E Assert -D RISCV_FORMAL $(RTL) formal/$(MOD)_formal.sv > build/$(MOD)_formal.v
	sby -f $(FORMAL)

view:
	@test -n "$(MOD)" || { echo "usage: make view MOD=<module>"; exit 1; }
	@test -f "tb/$(MOD).ron" || { echo "Error: tb/$(MOD).ron not found"; exit 1; }
	@test -f "$(VCD)" || { echo "Error: $(VCD) not found (run make MOD=$(MOD) first)"; exit 1; }
	surfer $(VCD) -s tb/$(MOD).ron &

# Echoes MOD's run directory, prompting when the .sby split into several tasks
define pick_run
	test -n "$(MOD)" || { echo "usage: make $@ MOD=<module>  (e.g. MOD=alu)" >&2; exit 1; }; \
	runs=$$(for d in formal/$(MOD)/ formal/$(MOD)_*/; do [ -f "$$d/status" ] && echo "$${d%/}"; done); \
	[ -n "$$runs" ] || { echo "No runs for $(MOD), try: make formal MOD=$(MOD)" >&2; exit 1; }; \
	if [ $$(echo "$$runs" | wc -l) -eq 1 ]; then echo "$$runs"; else \
	  i=0; for d in $$runs; do i=$$((i+1)); \
	    printf '  %d) %-12s %-6s%s\n' $$i "$$(basename $$d | sed 's/^$(MOD)_//')" \
	      "$$(cut -d' ' -f1 $$d/status)" \
	      "$$(find $$d -name trace.yw 2>/dev/null | head -1 | sed 's/.*/counterexample/')" >&2; \
	  done; \
	  printf 'Select task: ' >&2; read n; \
	  sel=$$(echo "$$runs" | sed -n "$${n}p" 2>/dev/null); \
	  [ -d "$$sel" ] || { echo "No task $$n" >&2; exit 1; }; \
	  echo "$$sel"; fi
endef

trace:
	@dir=$$($(pick_run)); test -n "$$dir" || exit 1; \
	yw=$$(find $$dir -name 'trace.yw' 2>/dev/null | head -1); \
	test -n "$$yw" || { echo "Error: no trace.yw in $$dir/, that run has no counterexample"; exit 1; }; \
	yosys-witness display $$yw

view-formal:
	@dir=$$($(pick_run)); test -n "$$dir" || exit 1; \
	vcd=$$(find $$dir -name '*.vcd' 2>/dev/null | head -1); \
	test -n "$$vcd" || { echo "Error: no .vcd found in $$dir/"; exit 1; }; \
	echo "surfer $$vcd"; \
	surfer $$vcd $$(test -f $$dir.ron && echo "-s $$dir.ron") &

hex:
	@test -n "$(PROG)" || { echo "usage: make hex PROG=<name>  (tests/<name>.s -> tests/<name>.hex)"; exit 1; }
	@mkdir -p build
	$(RVGCC) $(RVFLAGS) -o build/$(PROG).elf tests/$(PROG).s
	$(RVCOPY) -O verilog --verilog-data-width=4 build/$(PROG).elf tests/$(PROG).hex
	@echo "built tests/$(PROG).hex"

dis:
	@test -n "$(PROG)" || { echo "usage: make dis PROG=<name>"; exit 1; }
	$(RVDUMP) -d build/$(PROG).elf

cosim:
	@test -n "$(PROG)" || { echo "usage: make cosim PROG=<name>  (lockstep tests/$(PROG).s vs Spike)"; exit 1; }
	python3 tests/cosim.py $(PROG)

clean:
	rm -rf build *.vcd sim_build results.xml

.DEFAULT_GOAL := run
.PHONY: run vsim prog wave formal view trace view-formal hex dis cosim clean
