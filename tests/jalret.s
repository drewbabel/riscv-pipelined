.section .init
.global _start
_start:
  li   t5, 0x04000000
  li   a0, 0x43
  jal  ra, putc
  li   a0, 0x44
  jal  ra, putc
spin:
  j    spin
putc:
  lw   t6, 4(t5)
  andi t6, t6, 1
  beqz t6, putc
  sw   a0, 0(t5)
  ret
