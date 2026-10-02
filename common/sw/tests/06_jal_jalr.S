# jal / jalr: adresy powrotu, offsety, zerowanie najmłodszego bitu, stos.
    li   sp, 0x10000        # stos na końcu 64 KiB RAM

    li   gp, 1              # jal zapisuje PC+4
    jal  ra, f1
r1:
    j    after1
f1:
    la   t2, r1
    bne  ra, t2, fail
    ret
after1:

    li   gp, 2              # jalr z niezerowym offsetem
    la   t0, tgt2 - 8
    jalr ra, 8(t0)
    j    fail
tgt2:

    li   gp, 3              # jalr zeruje bit 0 adresu docelowego
    la   t0, tgt3 + 1
    jalr zero, 0(t0)
    j    fail
tgt3:

    li   gp, 4              # rd == rs1: najpierw liczymy cel, potem zapisujemy rd
    la   a0, tgt4
    jalr a0, 0(a0)
r4:
    j    fail
tgt4:
    la   t2, r4
    bne  a0, t2, fail

    li   gp, 5              # jal zero, ... nie zmienia ra
    li   ra, 1234
    j    tgt5
    j    fail
tgt5:
    li   t2, 1234
    bne  ra, t2, fail

    li   gp, 6              # zagnieżdżone wywołania ze stosem
    li   a0, 5
    call outer
    li   t2, 12             # outer(5) = inner(5) + 1 = (5*2 + 1) + 1
    bne  a0, t2, fail
    li   t2, 0x10000
    bne  sp, t2, fail       # stos musi wrócić na miejsce

    j    pass

outer:
    addi sp, sp, -16
    sw   ra, 12(sp)
    call inner
    addi a0, a0, 1
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret
inner:
    add  a0, a0, a0
    addi a0, a0, 1
    ret
.include "test_end.S"
