        .section .text
        .globl _start
_start:
        addi x1,  x0, 6
        addi x2,  x0, 7
        nop
        nop
        nop
        nop
        mul  x3,  x1, x2
        nop
        nop
        nop
        nop
        addi x4,  x0, 20
        addi x5,  x0, 3
        nop
        nop
        nop
        nop
        divu x6,  x4, x5
        nop
        nop
        nop
        nop
        remu x7,  x4, x5
        nop
        nop
        nop
        nop
        addi x8,  x0, -20
        nop
        nop
        nop
        nop
        div  x9,  x8, x5
        nop
        nop
        nop
        nop
