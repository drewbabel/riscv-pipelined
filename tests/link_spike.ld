ENTRY(_start)
MEMORY { ram (rwx) : ORIGIN = 0x80000000, LENGTH = 0x10000 }
SECTIONS {
    .text : { *(.text*) } > ram
    .data : { *(.data*) } > ram
}
