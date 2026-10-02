# Skoki warunkowe: każdy w wersji "skacze" i "nie skacze".
    li   gp, 1              # beq
    li   a0, 3
    li   a1, 3
    beq  a0, a1, ok1
    j    fail
ok1:
    li   a1, 4
    beq  a0, a1, fail

    li   gp, 2              # bne
    bne  a0, a1, ok2
    j    fail
ok2:
    bne  a0, a0, fail

    li   gp, 3              # blt / bge (ze znakiem)
    li   a0, -1
    li   a1, 1
    blt  a0, a1, ok3
    j    fail
ok3:
    blt  a1, a0, fail
    blt  a0, a0, fail
    bge  a1, a0, ok3b
    j    fail
ok3b:
    bge  a0, a0, ok3c
    j    fail
ok3c:
    bge  a0, a1, fail

    li   gp, 4              # bltu / bgeu (bez znaku): 0xFFFFFFFF jest duże
    bltu a1, a0, ok4
    j    fail
ok4:
    bltu a0, a1, fail
    bgeu a0, a1, ok4b
    j    fail
ok4b:
    bgeu a1, a0, fail

    li   gp, 5              # instrukcje za wykonanym skokiem nie mogą się wykonać
    li   a2, 0
    beq  zero, zero, skip5
    li   a2, 1
    li   a2, 2
skip5:
    bnez a2, fail

    li   gp, 6              # pętla wstecz: suma 1..10 = 55
    li   a0, 10
    li   a1, 0
loop6:
    add  a1, a1, a0
    addi a0, a0, -1
    bnez a0, loop6
    li   t2, 55
    bne  a1, t2, fail

    j    far_tests

.include "test_end.S"

# Dalekie skoki są za etykietą fail, żeby wcześniejsze `bne ..., fail`
# mieściły się w zasięgu +-4 KiB skoku warunkowego.
far_tests:
    li   gp, 7              # dalekie skoki: offset > 2 KiB (bit 11 immediate'a)
    beq  zero, zero, far7
back7:
    j    after7
    .space 2400             # 2400 bajtów zer (gdyby się wykonały: nielegalne)
far7:
    li   gp, 8
    beq  zero, zero, back7  # daleko wstecz
after7:

    li   gp, 9              # daleki jal: offset > 4 KiB (bity 19:12 immediate'a)
    jal  ra, far9
    j    pass
    .space 5000
far9:
    ret
