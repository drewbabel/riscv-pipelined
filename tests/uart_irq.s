        .section .text
        .globl _start
# Echo received byte
_start:
        la   t0, handler
        csrw mtvec, t0

        li   s0, 0x04000000        # UART base
        li   t0, 1
        sw   t0, 12(s0)            # enable receive interrupt

        li   t0, 0x800             # mie.MEIE
        csrw mie, t0
        li   t0, 0x8               # mstatus.MIE
        csrs mstatus, t0
wait:
        j    wait                  # wait for byte

        .balign 4
handler:
        li   s0, 0x04000000
        lw   a0, 8(s0)             # read clears flag
poll:
        lw   t0, 4(s0)
        andi t0, t0, 1
        beq  t0, x0, poll
        sw   a0, 0(s0)             # echo back
done:
        li   x28, 1
park:
        j    park
