# ---------------------------------------------------------------------------
# crt0.S — kod startowy: pierwsze instrukcje wykonywane po resecie (pc = 0).
#
# Zadania:
#   1. ustawić wskaźnik stosu,
#   2. wyzerować .bss (C gwarantuje, że zmienne globalne bez inicjalizatora = 0),
#   3. wywołać main(),
#   4. przekazać wynik main() do testbencha przez TOHOST
#      (0 -> PASS, inaczej FAIL z kodem = wartość zwrócona).
#
# .data nie trzeba kopiować: cały obraz programu (z .data) ląduje w RAM
# przez $readmemh, więc zmienne zainicjowane są już na swoich miejscach.
# ---------------------------------------------------------------------------
    .section .text.init, "ax"
    .globl _start
_start:
    la   sp, _stack_top

    la   t0, __bss_start
    la   t1, __bss_end
1:  bgeu t0, t1, 2f
    sw   zero, 0(t0)
    addi t0, t0, 4
    j    1b
2:
    call main

    li   t0, 0x10000000      # TOHOST
    li   t1, 1
    beqz a0, 3f
    slli t1, a0, 1
    ori  t1, t1, 1
3:  sw   t1, 0(t0)
4:  j    4b
