# pc_plus4 keep smoke check. A single jal returns and the store at pc+4 sends D.
# A miscompiled link would loop on the jal and the D after it would never run.
        .section .init
        .global _start
_start:
        li    t5, 0x04000000     # uart base
        jal   ra, sub
        li    a0, 0x44           # D, only if the return advanced to pc+4
        sw    a0, 0(t5)
spin:   j     spin
sub:
        li    a0, 0x43           # C
        sw    a0, 0(t5)
        ret
