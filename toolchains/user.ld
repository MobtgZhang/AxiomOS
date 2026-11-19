ENTRY(user_entry)
PHDRS { text PT_LOAD FLAGS(5); ro PT_LOAD FLAGS(4); data PT_LOAD FLAGS(6); }
SECTIONS {
  . = 0x400000;
  .text : { *(.text .text.*) } :text
  . = ALIGN(4096);
  .rodata : { *(.rodata .rodata.*) *(.srodata .srodata.*) } :ro
  . = ALIGN(4096);
  .data : { *(.data .data.*) *(.sdata .sdata.*) *(.got .got.*) } :data
  .bss : { *(.bss .bss.*) *(.sbss .sbss.*) *(COMMON) } :data
  /DISCARD/ : { *(.eh_frame*) *(.gcc_except_table*) *(.comment) *(.note*) }
}
