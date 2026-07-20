        .section .text
        .globl _start
_start:
        addi x3,  x0, 42
        addi x10, x0, 0
        nop
        nop
        nop
        nop
        sw   x3,  0(x10)
        nop
        nop
        nop
        nop
        lw   x1,  0(x10)
        add  x2,  x1, x0
        nop
        nop
        nop
        nop
