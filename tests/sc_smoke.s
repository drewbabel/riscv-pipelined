.section .text
.globl _start
_start:
    csrr x5, mcycle         # cycle count before the run
    li   x1, 0xABCD         # value to round-trip
    li   x2, 0x400          # data address in mem
    sw   x1, 0(x2)          # word store
    lw   x3, 0(x2)          # word load, the path under test
    li   x6, 0x404
    sb   x1, 0(x6)          # byte store
    lbu  x7, 0(x6)          # byte load
    lh   x8, 0(x2)          # halfword load, sign extended
    li   x4, 0x03000000     # peripheral, ready the same cycle
    sw   x3, 0(x4)          # single strobe expected
    lw   x11, 0(x4)         # read the peripheral back
    csrr x9, mcycle         # cycle count after the run
    sub  x10, x9, x5        # must exceed the instructions retired
    li   x28, 1             # done flag
loop:
    j    loop
