# Sortowanie bąbelkowe 16 liczb ze znakiem, potem weryfikacja.
    la   s0, arr
    li   s1, 16             # n

    # suma kontrolna przed sortowaniem
    li   s2, 0
    li   t0, 0
cs1:
    slli t1, t0, 2
    add  t1, s0, t1
    lw   t2, 0(t1)
    add  s2, s2, t2
    addi t0, t0, 1
    blt  t0, s1, cs1

    # bubble sort
    addi s3, s1, -1         # i = n-1 .. 1
outer:
    li   t0, 0              # j
    mv   t1, s0             # &arr[j]
inner:
    lw   a0, 0(t1)
    lw   a1, 4(t1)
    ble  a0, a1, noswap
    sw   a1, 0(t1)
    sw   a0, 4(t1)
noswap:
    addi t0, t0, 1
    addi t1, t1, 4
    blt  t0, s3, inner
    addi s3, s3, -1
    bgtz s3, outer

    li   gp, 1              # posortowane rosnąco?
    li   t0, 1
    mv   t1, s0
chk:
    lw   a0, 0(t1)
    lw   a1, 4(t1)
    bgt  a0, a1, fail
    addi t0, t0, 1
    addi t1, t1, 4
    blt  t0, s1, chk

    li   gp, 2              # min i max na miejscu
    lw   a0, 0(s0)
    li   t2, -1000
    bne  a0, t2, fail
    lw   a0, 60(s0)
    li   t2, 0x7FFFFFFF
    bne  a0, t2, fail

    li   gp, 3              # suma kontrolna bez zmian
    li   s4, 0
    li   t0, 0
cs2:
    slli t1, t0, 2
    add  t1, s0, t1
    lw   t2, 0(t1)
    add  s4, s4, t2
    addi t0, t0, 1
    blt  t0, s1, cs2
    bne  s2, s4, fail

    j    pass
.include "test_end.S"

.align 2
arr:
    .word 42, -7, 0, 13, 0x7FFFFFFF, -1000, 5, 5
    .word 99, -1, 1, 77, -500, 3, 1000, 8
