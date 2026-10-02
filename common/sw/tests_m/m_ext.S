# Rozszerzenie M (opcjonalne, moduł 09): mnożenie i dzielenie.
    li   gp, 1              # mul
    li   a0, 1234
    li   a1, 5678
    mul  a2, a0, a1
    li   t2, 7006652
    bne  a2, t2, fail
    li   a0, -3
    li   a1, 7
    mul  a2, a0, a1
    li   t2, -21
    bne  a2, t2, fail

    li   gp, 2              # mulh / mulhu / mulhsu
    li   a0, 0x80000000
    li   a1, 0x80000000
    mulh a2, a0, a1         # (-2^31)^2 = 2^62 -> górne słowo 0x40000000
    li   t2, 0x40000000
    bne  a2, t2, fail
    mulhu a2, a0, a1        # (2^31)^2 = 2^62
    bne  a2, t2, fail
    li   a0, -1
    li   a1, 0xFFFFFFFF
    mulhsu a2, a0, a1       # -1 * (2^32-1) = -(2^32-1) -> górne = 0xFFFFFFFF
    li   t2, -1
    bne  a2, t2, fail
    mulhu a2, a0, a1        # (2^32-1)^2 -> górne = 0xFFFFFFFE
    li   t2, 0xFFFFFFFE
    bne  a2, t2, fail

    li   gp, 3              # div / rem (zaokrąglanie do zera)
    li   a0, -7
    li   a1, 2
    div  a2, a0, a1
    li   t2, -3
    bne  a2, t2, fail
    rem  a2, a0, a1
    li   t2, -1
    bne  a2, t2, fail
    divu a2, a0, a1         # 0xFFFFFFF9 / 2
    li   t2, 0x7FFFFFFC
    bne  a2, t2, fail
    remu a2, a0, a1
    li   t2, 1
    bne  a2, t2, fail

    li   gp, 4              # dzielenie przez zero
    li   a0, 123
    div  a2, a0, zero
    li   t2, -1
    bne  a2, t2, fail
    divu a2, a0, zero
    bne  a2, t2, fail
    rem  a2, a0, zero
    bne  a2, a0, fail
    remu a2, a0, zero
    bne  a2, a0, fail

    li   gp, 5              # przepełnienie: -2^31 / -1
    li   a0, 0x80000000
    li   a1, -1
    div  a2, a0, a1
    bne  a2, a0, fail
    rem  a2, a0, a1
    bnez a2, fail

    j    pass
.include "test_end.S"
