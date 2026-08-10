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
        $(KDIR)/portable/MemMang/heap_4.c
ASRC := start.S $(PORT)/portASM.S

# The port's tick increment is a build-time constant, rename it out of the way
# so main.c can define the real one from the core clock register.
PORTDEF := -DuxTimerIncrementsForOneTick=uxPortBuildTickIncrement

LIBGCC := $(shell $(CC) $(CFLAGS) -print-libgcc-file-name)

all: freertos.hex freertos_sim.hex

port.o: $(PORT)/port.c FreeRTOSConfig.h
	$(CC) $(CFLAGS) $(PORTDEF) -c -o $@ $<

freertos.elf: $(CSRC) $(ASRC) port.o link.ld FreeRTOSConfig.h
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(CSRC) $(ASRC) port.o $(LIBGCC)

freertos_sim.elf: $(CSRC) $(ASRC) port.o link.ld FreeRTOSConfig.h
	$(CC) $(CFLAGS) -DREAD_DELAY=2 $(LDFLAGS) -o $@ $(CSRC) $(ASRC) port.o $(LIBGCC)

%.hex: %.elf
	$(OBJCOPY) -O verilog --verilog-data-width=4 $< $@
	@echo "$@ words: $$(grep -v '^@' $@ | wc -w)"

dis: freertos.elf
	$(OBJDUMP) -d $<

clean:
	rm -f freertos.elf freertos.hex port.o

.PHONY: all dis clean
