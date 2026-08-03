# Single source of truth for the core clock.
# ClkDiv sets how many 100 MHz board clocks pass per core cycle, so the core
# runs at CORE_CLK_HZ. build_board.sh patches rtl/board_top.sv from CLKDIV, and
# the software builds take their timing constants from CORE_CLK_HZ, which keeps
# the bitstream and every image that runs on it in agreement.
# Change CLKDIV here and nowhere else, then rebuild the bitstream and the images.

CLKDIV      ?= 2
BOARD_CLK_HZ ?= 100000000
CORE_CLK_HZ := $(shell expr $(BOARD_CLK_HZ) / $(CLKDIV))
