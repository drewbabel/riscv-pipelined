# Build CoreMark hex images
# EEMBC core cloned to coremark-src

SRC     := ../coremark-src
CC      := riscv64-elf-gcc
OBJCOPY := riscv64-elf-objcopy
OBJDUMP := riscv64-elf-objdump

CORE_CLK_HZ := 33333333

INCS := -I. -I$(SRC)
DEFS := -DHAS_FLOAT=1 -DHAS_TIME_H=0 -DUSE_CLOCK=0 -DHAS_STDIO=0 -DHAS_PRINTF=0 \
        -DMEM_METHOD=MEM_STATIC -DMAIN_HAS_NOARGC=1 -DCORE_CLK_HZ=$(CORE_CLK_HZ) \
        -DFLAGS_STR='"-O2 -march=rv32i_zicsr"'
CFLAGS  := -march=rv32i_zicsr -mabi=ilp32 -O2 -ffreestanding -Wall $(INCS) $(DEFS)
LDFLAGS := -march=rv32i_zicsr -mabi=ilp32 -nostdlib -nostartfiles -T link.ld

CORESRC := $(SRC)/core_main.c $(SRC)/core_list_join.c $(SRC)/core_matrix.c \
           $(SRC)/core_state.c $(SRC)/core_util.c
PORTSRC := core_portme.c ee_printf.c cvt.c libc.c
ASRC    := start.S
LIBGCC  := $(shell $(CC) $(CFLAGS) -print-libgcc-file-name)

# Hardware build, reportable score
coremark.elf: $(CORESRC) $(PORTSRC) $(ASRC) link.ld
	$(CC) $(CFLAGS) -DITERATIONS=0 $(LDFLAGS) -o $@ $(CORESRC) $(PORTSRC) $(ASRC) $(LIBGCC)

# Sim build, one iteration
coremark_sim.elf: $(CORESRC) $(PORTSRC) $(ASRC) link.ld
	$(CC) $(CFLAGS) -DITERATIONS=1 $(LDFLAGS) -o $@ $(CORESRC) $(PORTSRC) $(ASRC) $(LIBGCC)

all: coremark.hex coremark_sim.hex

$(SRC):
	git clone --depth 1 https://github.com/eembc/coremark.git $(SRC)

$(CORESRC): | $(SRC)

%.hex: %.elf
	$(OBJCOPY) -O verilog --verilog-data-width=4 $< $@
	@echo "$@ words: $$(grep -v '^@' $@ | wc -w)"

dis: coremark.elf
	$(OBJDUMP) -d $<

clean:
	rm -f coremark.elf coremark_sim.elf coremark.hex coremark_sim.hex

.PHONY: all dis clean
