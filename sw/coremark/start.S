.section .init
.global _start
_start:
    .option push
    .option norelax
    la    gp, __global_pointer$
    .option pop
    la    sp, _stack_top

    /* set trap vector */
    la    t0, trap_handler
    csrw  mtvec, t0

    /* zero bss */
    la    t0, _bss_start
    la    t1, _bss_end
1:  bge   t0, t1, 2f
    sw    zero, 0(t0)
    addi  t0, t0, 4
    j     1b
2:
    call  main
    li    t0, 0x03000000
    li    t1, 0xC0DE
    sw    t1, 0(t0)
3:  j     3b

    /* emit hex nibble */
    .balign 4
puthex:
    li    t5, 0x04000000
1:  lw    t6, 4(t5)
    andi  t6, t6, 1
    beqz  t6, 1b
    andi  a0, a0, 0xF
    li    t6, 9
    bgtu  a0, t6, 2f
    addi  a0, a0, 0x30
    j     3f
2:  addi  a0, a0, 0x37
3:  sw    a0, 0(t5)
    ret

    /* dump trap state */
    .balign 4
trap_handler:
    li    a0, 0x54
    li    t5, 0x04000000
1:  lw    t6, 4(t5)
    andi  t6, t6, 1
    beqz  t6, 1b
    sw    a0, 0(t5)
    csrr  s2, mcause
    mv    a0, s2
    jal   ra, puthex
    csrr  s3, mepc
    li    s4, 28
4:  srl   a0, s3, s4
    jal   ra, puthex
    addi  s4, s4, -4
    bgez  s4, 4b
5:  j     5b
