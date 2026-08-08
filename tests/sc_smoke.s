.section .text
.globl _start
_start:
    csrr x5, mcycle         # Cycle before run
    li   x1, 0xABCD         # Round-trip value
    li   x2, 0x400          # Data address
    sw   x1, 0(x2)          # Word store
    lw   x3, 0(x2)          # Word load
    li   x6, 0x404
    sb   x1, 0(x6)          # Byte store
    lbu  x7, 0(x6)          # Byte load
    lh   x8, 0(x2)          # Sign-extended load
    li   x4, 0x03000000     # Same cycle ready
    sw   x3, 0(x4)          # Single strobe
    lw   x11, 0(x4)         # Read peripheral
    csrr x9, mcycle         # Cycle after run
    sub  x10, x9, x5        # Must exceed retired
    li   x28, 1             # Done flag
loop:
    j    loop
