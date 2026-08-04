# Core clock source
CLKDIV      ?= 2
BOARD_CLK_HZ ?= 100000000
CORE_CLK_HZ := $(shell expr $(BOARD_CLK_HZ) / $(CLKDIV))
