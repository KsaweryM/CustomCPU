# Urządzenia w testbenchu: PUTCHAR i licznik cykli.
.equ PUTCHAR, 0x10000004
.equ CYCLES,  0x10000008

    li   gp, 1              # wypisz napis znak po znaku
    la   s0, msg
    li   s1, PUTCHAR
print:
    lbu  a0, 0(s0)
    beqz a0, printed
    sw   a0, 0(s1)
    addi s0, s0, 1
    j    print
printed:

    li   gp, 2              # licznik cykli rośnie
    li   s1, CYCLES
    lw   a0, 0(s1)
    nop
    nop
    lw   a1, 0(s1)
    bleu a1, a0, fail

    j    pass
.include "test_end.S"

msg:
    .asciz "Witaj z procesora RV32I!\n"
