        .section .text
        .globl _start
_start:
        addi x1,  x0, 10
        addi x2,  x0, 3
        addi x5,  x0, 1
        nop
        nop
        nop
        nop
        add  x3,  x1, x2
        sub  x4,  x3, x5
        add  x6,  x1, x2
        nop
        sub  x7,  x6, x5
        add  x8,  x1, x2
        nop
        nop
        sub  x9,  x8, x5
        add  x20, x1, x2
        sw   x20, 0(x0)
        nop
        nop
        nop
        nop
        lw   x21, 0(x0)
        nop
        nop
        nop
        nop
