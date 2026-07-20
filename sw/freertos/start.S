.section .init
.global _start
_start:
    .option push
    .option norelax
    la    gp, __global_pointer$
    .option pop
    la    sp, _stack_top

    /* set trap vector */
    la    t0, freertos_risc_v_trap_handler
    csrw  mtvec, t0

    /* zero bss */
    la    t0, _bss_start
    la    t1, _bss_end
1:  bge   t0, t1, 2f
    sw    zero, 0(t0)
    addi  t0, t0, 4
    j     1b
2:
    li    t0, 0x03000000
    li    t1, 0x0100
    sw    t1, 0(t0)            # startup done
    call  main
3:  j     3b
