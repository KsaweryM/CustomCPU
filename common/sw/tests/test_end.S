# ---------------------------------------------------------------------------
# Wspólne zakończenie testów (dołączane przez .include "test_end.S").
#
# Konwencja (jak w oficjalnych riscv-tests):
#   gp (x3) = numer aktualnego podtestu,
#   skok do `fail` -> zapis (gp << 1) | 1 do TOHOST,
#   skok do `pass` -> zapis 1 do TOHOST.
# Testbench kończy symulację przy pierwszym zapisie pod TOHOST.
# ---------------------------------------------------------------------------
.equ TOHOST, 0x10000000

fail:
    slli gp, gp, 1
    ori  gp, gp, 1
    li   t0, TOHOST
    sw   gp, 0(t0)
fail_loop:
    j    fail_loop

pass:
    li   t0, TOHOST
    li   t1, 1
    sw   t1, 0(t0)
pass_loop:
    j    pass_loop
