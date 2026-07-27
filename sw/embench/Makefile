# Build Embench IoT hex images
# Embench cloned to embench-src

SRC     := ../embench-src
CC      := riscv64-elf-gcc
OBJCOPY := riscv64-elf-objcopy
OBJDUMP := riscv64-elf-objdump

ARCH ?= rv32im_zicsr
GSF  ?= 1
HEAT ?= 1

BENCHES := aha-mont64 crc32 depthconv edn huffbench matmult-int md5sum \
           nettle-aes nettle-sha256 nsichneu picojpeg qrduino sglib-combined \
           slre statemate tarfind ud wikisort xgboost

INCS := -I. -Ishim -I$(SRC)/support
DEFS := -DHAVE_BOARDSUPPORT_H -DGLOBAL_SCALE_FACTOR=$(GSF) -DWARMUP_HEAT=$(HEAT)
CFLAGS  := -march=$(ARCH) -mabi=ilp32 -O2 -std=gnu11 -ffreestanding -Wall $(INCS) $(DEFS)
LDFLAGS := -march=$(ARCH) -mabi=ilp32 -nostdlib -nostartfiles -T link.ld

SUPSRC  := $(SRC)/support/main.c $(SRC)/support/beebsc.c
PORTSRC := boardsupport.c libc.c
ASRC    := start.S
LIBGCC  := $(shell $(CC) $(CFLAGS) -print-libgcc-file-name)

HEXES := $(addsuffix .hex,$(BENCHES))

all: $(HEXES)

$(SRC):
	git clone --depth 1 https://github.com/embench/embench-iot.git $(SRC)

%.elf: $(PORTSRC) $(ASRC) link.ld | $(SRC)
	$(CC) $(CFLAGS) -DBENCH_NAME='"$*"' $(LDFLAGS) -o $@ \
		$(SRC)/src/$*/*.c $(SUPSRC) $(PORTSRC) $(ASRC) $(LIBGCC)

%.hex: %.elf
	$(OBJCOPY) -O verilog --verilog-data-width=4 $< $@
	@echo "$@ words: $$(grep -v '^@' $@ | wc -w)"

dis: $(BENCH).elf
	$(OBJDUMP) -d $<

clean:
	rm -f *.elf *.hex

.PRECIOUS: %.elf
.PHONY: all dis clean
