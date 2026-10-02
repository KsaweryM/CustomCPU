# lui i auipc.
    li   gp, 1
    lui  a0, 0x12345
    li   t2, 0x12345000
    bne  a0, t2, fail
    lui  a0, 0xFFFFF
    li   t2, 0xFFFFF000
    bne  a0, t2, fail

    li   gp, 2
    # __PAD = liczba nop-ów wstawianych przez `rvtool --pad-nops` przed każdą
    # instrukcją (moduł 08); normalnie 0. Etykieta wskazuje na pierwszy nop.
here1:
    auipc a0, 0             # a0 = adres here1
    la   t2, here1 + 4*__PAD
    bne  a0, t2, fail
here2:
    auipc a0, 1             # a0 = here2 + 0x1000
    la   t2, here2 + 4*__PAD + 0x1000
    bne  a0, t2, fail

    j    pass
.include "test_end.S"
