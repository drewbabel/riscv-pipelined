.section .text
.globl _start
_start:
    li   x1, 0xABCD         # value to round-trip
    li   x2, 0x400          # data address in mem
    sw   x1, 0(x2)          # mem[0x400] = value
    fence                   # legal no-op on this core
    lw   x3, 0(x2)          # load it back, the path under test
    li   x4, 0x03000000     # LED MMIO
    sw   x3, 0(x4)          # LED = loaded value
loop:
    j    loop
