# Build the FreeRTOS demo into a hex image for the core

KDIR   := ../FreeRTOS-Kernel
PORT   := $(KDIR)/portable/GCC/RISC-V
CHIP   := $(PORT)/chip_specific_extensions/RV32I_CLINT_no_extensions

CC     := riscv64-elf-gcc
OBJCOPY := riscv64-elf-objcopy
OBJDUMP := riscv64-elf-objdump

INCS := -I. -Ishim -I$(KDIR)/include -I$(PORT) -I$(CHIP)
CFLAGS := -march=rv32i_zicsr -mabi=ilp32 -O2 -ffreestanding -Wall $(INCS)
LDFLAGS := -march=rv32i_zicsr -mabi=ilp32 -nostdlib -nostartfiles -T link.ld

CSRC := main.c libc.c \
        $(KDIR)/tasks.c $(KDIR)/list.c $(KDIR)/queue.c \
        $(PORT)/port.c $(KDIR)/portable/MemMang/heap_4.c
ASRC := start.S $(PORT)/portASM.S

LIBGCC := $(shell $(CC) $(CFLAGS) -print-libgcc-file-name)

all: freertos.hex freertos_sim.hex

freertos.elf: $(CSRC) $(ASRC) link.ld FreeRTOSConfig.h
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(CSRC) $(ASRC) $(LIBGCC)

# Sim build: fast polling so the queue moves within a few ticks
freertos_sim.elf: $(CSRC) $(ASRC) link.ld FreeRTOSConfig.h
	$(CC) $(CFLAGS) -DREAD_DELAY=2 $(LDFLAGS) -o $@ $(CSRC) $(ASRC) $(LIBGCC)

%.hex: %.elf
	$(OBJCOPY) -O verilog --verilog-data-width=4 $< $@
	@echo "$@ words: $$(grep -v '^@' $@ | wc -w)"

dis: freertos.elf
	$(OBJDUMP) -d $<

clean:
	rm -f freertos.elf freertos.hex

.PHONY: all dis clean
