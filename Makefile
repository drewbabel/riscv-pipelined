#   make MOD=pc                  compile rtl/ + that tb, run; a test FAIL exits nonzero
#   make wave MOD=alu            same, then open the waveform in surfer (opens even on FAIL)
#   make view MOD=alu            open testbench waveform in surfer (no rerun); error if .vcd missing
#   make view-formal MOD=alu     open formal waveform; error if .vcd missing
#   make formal MOD=alu          run every SymbiYosys task in formal/$(MOD).sby; a FAIL exits nonzero
#   make hex PROG=program        assemble tests/$(PROG).s -> tests/$(PROG).hex for $readmemh
#   make dis PROG=program        disassemble the built elf (sanity-check the machine code)
#   make cosim PROG=cosim1       lockstep-compare tests/cosim1.s against Spike (needs spike installed)
#   make clean                   delete build artifacts (build/, *.vcd)

# packages must compile before any module that imports them
PKGS := rtl/alu_pkg.sv rtl/csr_pkg.sv rtl/opcode_pkg.sv
RTL := $(PKGS) $(filter-out $(PKGS),$(wildcard rtl/*.sv))
TB  := tb/$(MOD)_tb.sv
SIM := build/sim
VCD := $(MOD)_tb.vcd
WAVE_STATE := tb/$(MOD).ron
FORMAL := formal/$(MOD).sby

# program build: RISC-V assembly -> hex words for $readmemh
RVGCC   := riscv64-elf-gcc
RVCOPY  := riscv64-elf-objcopy
RVDUMP  := riscv64-elf-objdump
RVFLAGS := -march=rv32i_zicsr -mabi=ilp32 -nostdlib -nostartfiles -T tests/link.ld

run:
	@test -n "$(MOD)" || { echo "usage: make MOD=<module>  (e.g. MOD=alu)"; exit 1; }
	@mkdir -p build
	iverilog -g2012 -s $(MOD)_tb -o $(SIM) $(RTL) $(TB)
	vvp $(SIM)

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
	iverilog -g2012 -s $(MOD)_tb -o $(SIM) $(RTL) $(TB)
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

view-formal:
	@test -n "$(MOD)" || { echo "usage: make view-formal MOD=<module>  (e.g. MOD=alu)"; exit 1; }
	@test -f "formal/$(MOD).ron" || { echo "Error: formal/$(MOD).ron not found"; exit 1; }
	@test -f "$$(find formal/$(MOD) -name '*.vcd' 2>/dev/null | head -1)" || { echo "Error: no .vcd found in formal/$(MOD)/"; exit 1; }
	surfer $$(find formal/$(MOD) -name '*.vcd' 2>/dev/null | head -1) -s formal/$(MOD).ron &

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
.PHONY: run prog wave formal view view-formal hex dis cosim clean
