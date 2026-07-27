OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY {
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 64K
}

SECTIONS {
    .text : {
        *(.init)
        *(.text*)
    } > RAM

    .rodata : {
        *(.rodata*)
        *(.srodata*)
    } > RAM

    . = ALIGN(8);
    __global_pointer$ = . + 0x800;

    .data : {
        *(.data*)
        *(.sdata*)
    } > RAM

    .bss : {
        _bss_start = .;
        *(.bss*)
        *(.sbss*)
        *(COMMON)
        _bss_end = .;
    } > RAM

    . = ALIGN(16);
    _end = .;
    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
