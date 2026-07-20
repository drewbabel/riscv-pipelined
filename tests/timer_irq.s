        .section .text
        .globl _start
# Take a machine timer interrupt, then print over serial
_start:
        la   t0, handler
        csrw mtvec, t0

        li   t2, 0x02004000        # CLINT mtimecmp low
        li   t1, 200
        sw   t1, 0(t2)             # fire once mtime reaches 200
        li   t2, 0x02004004
        sw   x0, 0(t2)             # mtimecmp high = 0

        li   t0, 0x80              # mie.MTIE
        csrw mie, t0
        li   t0, 0x8               # mstatus.MIE
        csrs mstatus, t0
wait:
        j    wait                  # spin until the timer fires

        .balign 4
handler:
        li   t2, 0x02004004        # disarm the timer first
        li   t1, -1
        sw   t1, 0(t2)
        li   s0, 0x04000000        # UART base
        la   s1, msg
ploop:
        lbu  a0, 0(s1)
        beq  a0, x0, done
poll:
        lw   t0, 4(s0)
        andi t0, t0, 1
        beq  t0, x0, poll
        sw   a0, 0(s0)
        addi s1, s1, 1
        j    ploop
done:
        li   x28, 1
park:
        j    park

        .balign 4
msg:
        .asciz "IT\n"
