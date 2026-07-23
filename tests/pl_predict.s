        .section .text
        .globl _start
_start:
        addi x1, x0, 0          # sum
        addi x2, x0, 0          # i
        addi x3, x0, 20         # trip count
loop:
        add  x1, x1, x2         # sum += i
        addi x2, x2, 1          # i++
        blt  x2, x3, loop       # backward branch, taken 19x then not-taken
        addi x28, x0, 1         # PASS sentinel, x1 == 190
