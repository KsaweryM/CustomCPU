# Ciąg Fibonacciego w tablicy: fib[0..19], potem suma.
    la   s0, fib
    li   a0, 0
    li   a1, 1
    sw   a0, 0(s0)
    sw   a1, 4(s0)
    li   t0, 2              # i
    li   t1, 20             # n
loop:
    slli t3, t0, 2
    add  t3, s0, t3         # &fib[i]
    lw   a0, -8(t3)
    lw   a1, -4(t3)
    add  a2, a0, a1
    sw   a2, 0(t3)
    addi t0, t0, 1
    blt  t0, t1, loop

    li   gp, 1              # fib[19] = 4181
    lw   a0, 76(s0)
    li   t2, 4181
    bne  a0, t2, fail

    li   gp, 2              # suma fib[0..19] = fib[21] - 1 = 10945
    li   a1, 0
    li   t0, 0
sum:
    slli t3, t0, 2
    add  t3, s0, t3
    lw   a0, 0(t3)
    add  a1, a1, a0
    addi t0, t0, 1
    blt  t0, t1, sum
    li   t2, 10945
    bne  a1, t2, fail

    j    pass
.include "test_end.S"

.align 2
fib:
    .space 80
