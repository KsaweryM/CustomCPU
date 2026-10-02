# Test "dymny": jeśli ten nie przechodzi, nic innego nie przejdzie.
# Używa tylko lui, addi i sw. Nie ma skoków, więc działa nawet na
# procesorze, który nie obsługuje jeszcze branchy.
    lui  t0, 0x10000        # t0 = 0x1000_0000 (TOHOST)
    addi t1, zero, 1        # t1 = 1 -> PASS
    sw   t1, 0(t0)
loop:
    jal  zero, loop
