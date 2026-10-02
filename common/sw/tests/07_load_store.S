# Load / store wszystkich szerokości, rozszerzanie znakiem i zerami.
    la   s0, data           # data: 01 80 7F FF  -> słowo 0xFF7F8001

    li   gp, 1              # lw
    lw   a0, 0(s0)
    li   t2, 0xFF7F8001
    bne  a0, t2, fail
    addi s1, s0, 4
    lw   a0, -4(s1)         # ujemny offset
    bne  a0, t2, fail

    li   gp, 2              # lb / lbu
    lb   a0, 0(s0)
    li   t2, 0x01
    bne  a0, t2, fail
    lb   a0, 1(s0)
    li   t2, 0xFFFFFF80
    bne  a0, t2, fail
    lbu  a0, 1(s0)
    li   t2, 0x80
    bne  a0, t2, fail
    lb   a0, 2(s0)
    li   t2, 0x7F
    bne  a0, t2, fail
    lb   a0, 3(s0)
    li   t2, -1
    bne  a0, t2, fail
    lbu  a0, 3(s0)
    li   t2, 0xFF
    bne  a0, t2, fail

    li   gp, 3              # lh / lhu
    lh   a0, 0(s0)
    li   t2, 0xFFFF8001
    bne  a0, t2, fail
    lhu  a0, 0(s0)
    li   t2, 0x8001
    bne  a0, t2, fail
    lh   a0, 2(s0)
    li   t2, 0xFFFFFF7F
    bne  a0, t2, fail
    lhu  a0, 2(s0)
    li   t2, 0xFF7F
    bne  a0, t2, fail

    li   gp, 4              # sw / sb / sh
    la   s1, buf
    li   a0, 0x11223344
    sw   a0, 0(s1)
    li   a0, 0xAA
    sb   a0, 1(s1)          # -> 0x1122AA44
    lw   a1, 0(s1)
    li   t2, 0x1122AA44
    bne  a1, t2, fail
    li   a0, 0x1234BEEF     # sh zapisuje tylko młodsze 16 bitów
    sh   a0, 2(s1)          # -> 0xBEEFAA44
    lw   a1, 0(s1)
    li   t2, 0xBEEFAA44
    bne  a1, t2, fail
    li   a0, 0x155          # sb zapisuje tylko młodsze 8 bitów
    sb   a0, 0(s1)          # -> 0xBEEFAA55
    lw   a1, 0(s1)
    li   t2, 0xBEEFAA55
    bne  a1, t2, fail
    lbu  a1, 3(s1)
    li   t2, 0xBE
    bne  a1, t2, fail
    lh   a1, 2(s1)
    li   t2, 0xFFFFBEEF
    bne  a1, t2, fail

    li   gp, 5              # zapis do sąsiedniego słowa nie psuje tego
    li   a0, -1
    sw   a0, 4(s1)
    sb   a0, 8(s1)
    lw   a1, 0(s1)
    li   t2, 0xBEEFAA55
    bne  a1, t2, fail
    lw   a1, 8(s1)
    li   t2, 0x000000FF
    bne  a1, t2, fail

    j    pass
.include "test_end.S"

.align 2
data:
    .byte 0x01, 0x80, 0x7F, 0xFF
buf:
    .word 0, 0, 0
