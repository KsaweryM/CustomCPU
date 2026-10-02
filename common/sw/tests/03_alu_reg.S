# Instrukcje ALU rejestr-rejestr (R-type).
    li   gp, 1              # add / sub z przepełnieniem
    li   a0, 0x7FFFFFFF
    li   a1, 1
    add  a2, a0, a1
    li   t2, 0x80000000
    bne  a2, t2, fail
    sub  a2, zero, a1
    li   t2, -1
    bne  a2, t2, fail
    li   a0, 0x80000000
    sub  a2, a0, a1
    li   t2, 0x7FFFFFFF
    bne  a2, t2, fail

    li   gp, 2              # sll / srl / sra: liczy się tylko 5 bitów rs2
    li   a0, 0x80000001
    li   a1, 33             # 33 & 31 = 1
    sll  a2, a0, a1
    li   t2, 2
    bne  a2, t2, fail
    srl  a2, a0, a1
    li   t2, 0x40000000
    bne  a2, t2, fail
    sra  a2, a0, a1
    li   t2, 0xC0000000
    bne  a2, t2, fail
    li   a1, 31
    sra  a2, a0, a1
    li   t2, -1
    bne  a2, t2, fail

    li   gp, 3              # slt / sltu
    li   a0, -1
    li   a1, 1
    slt  a2, a0, a1         # -1 < 1
    li   t2, 1
    bne  a2, t2, fail
    sltu a2, a0, a1         # 0xFFFFFFFF < 1 ? nie
    bnez a2, fail
    slt  a2, a1, a0
    bnez a2, fail
    sltu a2, a1, a0
    li   t2, 1
    bne  a2, t2, fail
    slt  a2, a0, a0
    bnez a2, fail

    li   gp, 4              # xor / or / and
    li   a0, 0xFF00FF00
    li   a1, 0x0FF00FF0
    xor  a2, a0, a1
    li   t2, 0xF0F0F0F0
    bne  a2, t2, fail
    or   a2, a0, a1
    li   t2, 0xFFF0FFF0
    bne  a2, t2, fail
    and  a2, a0, a1
    li   t2, 0x0F000F00
    bne  a2, t2, fail

    li   gp, 5              # rd == rs1 == rs2
    li   a0, 21
    add  a0, a0, a0
    li   t2, 42
    bne  a0, t2, fail

    j    pass
.include "test_end.S"
