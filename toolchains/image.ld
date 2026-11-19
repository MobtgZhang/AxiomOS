PHDRS
{
  text PT_LOAD FLAGS(5);
  ro PT_LOAD FLAGS(4);
  data PT_LOAD FLAGS(6);
  dynamic PT_DYNAMIC FLAGS(6);
}
SECTIONS
{
  . = 0x1000;
  __text_start = .;
  .text : { *(.text .text.*) } :text
  . = ALIGN(4096);
  __text_end = .;
  __ro_start = .;
  .rodata : { *(.rodata .rodata.*) *(.srodata .srodata.*) } :ro
  .dynsym : { *(.dynsym) } :ro
  .dynstr : { *(.dynstr) } :ro
  .hash : { *(.hash) } :ro
  .gnu.hash : { *(.gnu.hash) } :ro
  .rela.dyn : { *(.rela .rela.*) } :ro
  . = ALIGN(4096);
  __ro_end = .;
  __data_start = .;
  .data : { *(.data .data.*) *(.sdata .sdata.*) *(.data.rel.ro*) } :data
  .dynamic : { *(.dynamic) } :data :dynamic
  .got : { *(.got .got.*) } :data
  .bss : { *(.bss .bss.*) *(.sbss .sbss.*) *(COMMON) } :data
  . = ALIGN(4096);
  __data_end = .;
  /DISCARD/ : { *(.eh_frame*) *(.gcc_except_table*) *(.comment) *(.note*) }
}
