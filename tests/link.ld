ENTRY(_start)
SECTIONS {
  . = 0x0;
  .text : { *(.text*) }
  .rodata : { *(.rodata*) }
  .data : { *(.data*) *(.sdata*) }
  .bss : { *(.bss*) *(COMMON) }
}
