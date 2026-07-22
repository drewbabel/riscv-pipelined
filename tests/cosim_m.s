        .section .text
        .globl _start
_start:
        lui   x3, 0x80008        # data base 0x80008000, clear of code in Spike
        li    x1, -1619104863     # a large negative operand
        li    x2, 32870           # a positive operand
        li    x4, 7
        li    x5, -3
        li    x6, 0               # zero divisor
        lui   x7, 0x80000         # INT_MIN
        li    x8, -1

        mul   x10, x1, x2         # low product
        mulh  x11, x1, x2         # high signed
        mulhsu x12, x1, x2        # high signed-unsigned
        mulhu x13, x1, x2         # high unsigned
        mul   x14, x4, x5         # -21

        div   x15, x1, x2         # signed quotient
        rem   x16, x1, x2         # signed remainder
        divu  x17, x1, x2         # unsigned quotient
        remu  x18, x1, x2         # unsigned remainder
        div   x19, x4, x5         # -2
        rem   x20, x4, x5         # 1

        div   x21, x4, x6         # divide by zero, all ones
        rem   x22, x4, x6         # divide by zero, dividend
        divu  x23, x4, x6         # divide by zero, all ones
        div   x24, x7, x8         # overflow INT_MIN / -1
        rem   x25, x7, x8         # overflow remainder 0

        mul   x26, x1, x2         # dependent chain feeds a store
        sw    x26, 0(x3)
        add   x27, x15, x16
        sw    x27, 4(x3)
        lw    x28, 0(x3)

done:   beq   x0, x0, done
