        .section .text
        .globl _start
_start:
        addi x1,  x0, 5
        addi x2,  x0, 3
        addi x11, x0, 15
        addi x12, x0, 1
        addi x13, x0, 0
        nop
        nop
        nop
        nop
        add  x3,  x1, x2
        sub  x4,  x1, x2
        xor  x6,  x1, x2
        or   x7,  x1, x2
        and  x8,  x1, x11
        sll  x9,  x1, x12
        nop
        nop
        nop
        nop
        sw   x3,  0(x13)
        nop
        nop
        nop
        nop
        lw   x5,  0(x13)
        nop
        nop
        nop
        nop
