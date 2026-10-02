/* ---------------------------------------------------------------------------
 * link.ld — gdzie linker ma położyć poszczególne sekcje programu.
 *
 * Nasz "komputer" (soc_tb / rv32sim) ma 64 KiB RAM od adresu 0 i zaczyna
 * wykonywanie od adresu 0, więc .text.init (crt0) musi być pierwsze.
 * Stos rośnie w dół od końca RAM.
 * ------------------------------------------------------------------------- */
OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
  RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 64K
}

SECTIONS
{
  .text : {
    *(.text.init)
    *(.text .text.*)
  } > RAM

  .rodata : ALIGN(4) {
    *(.rodata .rodata.* .srodata .srodata.*)
  } > RAM

  .data : ALIGN(4) {
    *(.data .data.* .sdata .sdata.*)
  } > RAM

  .bss (NOLOAD) : ALIGN(4) {
    __bss_start = .;
    *(.bss .bss.* .sbss .sbss.* COMMON)
    . = ALIGN(4);
    __bss_end = .;
  } > RAM

  _stack_top = ORIGIN(RAM) + LENGTH(RAM);

  /DISCARD/ : { *(.comment) *(.riscv.attributes) *(.note*) *(.eh_frame*) }
}
