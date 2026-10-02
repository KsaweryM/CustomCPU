# Instrukcje ALU z argumentem natychmiastowym (I-type).
    li   gp, 1
    li   a0, 5
    addi a1, a0, -7
    li   t2, -2
    bne  a1, t2, fail

    li   gp, 2
    addi a1, zero, 2047
    li   t2, 2047
    bne  a1, t2, fail
    addi a1, zero, -2048
    li   t2, 0xFFFFF800
    bne  a1, t2, fail

    li   gp, 3              # slti / sltiu
    slti a1, a0, 6
    li   t2, 1
    bne  a1, t2, fail
    slti a1, a0, 5
    bnez a1, fail
    li   a0, -1
    slti a1, a0, 0          # -1 < 0 (ze znakiem)
    li   t2, 1
    bne  a1, t2, fail
    sltiu a1, a0, 1         # 0xFFFFFFFF < 1 (bez znaku) -> 0
    bnez a1, fail
    sltiu a1, zero, -1      # 0 < 0xFFFFFFFF -> 1
    li   t2, 1
    bne  a1, t2, fail

    li   gp, 4              # xori / ori / andi
    li   a0, 0x0F0F
    xori a1, a0, 0x0FF
    li   t2, 0x0FF0
    bne  a1, t2, fail
    xori a1, a0, -1         # not
    li   t2, 0xFFFFF0F0
    bne  a1, t2, fail
    ori  a1, a0, 0x0F0
    li   t2, 0x0FFF
    bne  a1, t2, fail
    andi a1, a0, 0x0FF
    li   t2, 0x0F
    bne  a1, t2, fail
    andi a1, a0, -16        # imm rozszerzony znakiem: 0xFFFFFFF0
    li   t2, 0x0F00
    bne  a1, t2, fail

    li   gp, 5              # przesunięcia
    li   a0, 1
    slli a1, a0, 31
    li   t2, 0x80000000
    bne  a1, t2, fail
    li   a0, 0x80000000
    srli a1, a0, 31
    li   t2, 1
    bne  a1, t2, fail
    srai a1, a0, 31
    li   t2, -1
    bne  a1, t2, fail
    srai a1, a0, 4
    li   t2, 0xF8000000
    bne  a1, t2, fail
    srli a1, a0, 4
    li   t2, 0x08000000
    bne  a1, t2, fail
    slli a1, a0, 0
    bne  a1, a0, fail

    li   gp, 6              # x0 zawsze ma wartość 0
    addi zero, zero, 5
    bnez zero, fail

    j    pass
.include "test_end.S"
