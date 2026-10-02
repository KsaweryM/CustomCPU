# Rekurencja i mnożenie programowe (RV32I nie ma instrukcji mul).
    li   sp, 0x10000

    li   gp, 1              # mul(1234, 5678) = 7006652
    li   a0, 1234
    li   a1, 5678
    call mul
    li   t2, 7006652
    bne  a0, t2, fail

    li   gp, 2              # mul z liczbą ujemną (mod 2^32)
    li   a0, -3
    li   a1, 7
    call mul
    li   t2, -21
    bne  a0, t2, fail

    li   gp, 3              # fib(15) = 610, naiwna rekurencja
    li   a0, 15
    call fib
    li   t2, 610
    bne  a0, t2, fail

    li   gp, 4              # fact(10) = 3628800 (rekurencja + mul)
    li   a0, 10
    call fact
    li   t2, 3628800
    bne  a0, t2, fail

    li   gp, 5
    li   t2, 0x10000
    bne  sp, t2, fail

    j    pass

# a0 = a0 * a1 (shift-and-add)
mul:
    li   t0, 0
mul_loop:
    andi t1, a1, 1
    beqz t1, mul_skip
    add  t0, t0, a0
mul_skip:
    slli a0, a0, 1
    srli a1, a1, 1
    bnez a1, mul_loop
    mv   a0, t0
    ret

# a0 = fib(a0)
fib:
    li   t0, 2
    blt  a0, t0, fib_base
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   s0, 8(sp)
    sw   s1, 4(sp)
    mv   s0, a0
    addi a0, s0, -1
    call fib
    mv   s1, a0
    addi a0, s0, -2
    call fib
    add  a0, a0, s1
    lw   s1, 4(sp)
    lw   s0, 8(sp)
    lw   ra, 12(sp)
    addi sp, sp, 16
fib_base:
    ret

# a0 = a0!
fact:
    li   t0, 1
    ble  a0, t0, fact_base
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   s0, 8(sp)
    mv   s0, a0
    addi a0, a0, -1
    call fact
    mv   a1, s0
    call mul
    lw   s0, 8(sp)
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret
fact_base:
    li   a0, 1
    ret
.include "test_end.S"
