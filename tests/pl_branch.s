        .section .text
        .globl _start
_start:
        addi x1,  x0, 5
        addi x2,  x0, 5
        nop
        nop
        nop
        nop
        beq  x1, x2, t1
        addi x10, x0, 1
        addi x11, x0, 1
t1:
        addi x5,  x0, 42
        nop
        nop
        nop
        nop
        bne  x1, x2, t2
        addi x12, x0, 7
t2:
        addi x13, x0, 8
        nop
        nop
        nop
        nop
