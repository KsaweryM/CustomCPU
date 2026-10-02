# Sekwencje "złośliwe" dla procesora potokowego (moduł 08).
# Na procesorze jednocyklowym przechodzą od razu, ale pipeline bez
# forwardingu / stalli / flushy wyłoży się tutaj na pewno.
    la   s0, buf

    li   gp, 1              # łańcuch zależności: EX -> EX
    addi a0, zero, 1
    addi a0, a0, 1
    addi a0, a0, 1
    addi a0, a0, 1
    li   t2, 4
    bne  a0, t2, fail

    li   gp, 2              # zależność w odległości 2 i 3 instrukcji
    addi a1, zero, 5
    nop
    add  a2, a1, a1
    li   t2, 10
    bne  a2, t2, fail
    addi a1, zero, 7
    nop
    nop
    add  a2, a1, a1
    li   t2, 14
    bne  a2, t2, fail

    li   gp, 3              # oba operandy z różnych etapów
    addi a0, zero, 3
    addi a1, zero, 4
    add  a2, a0, a1
    li   t2, 7
    bne  a2, t2, fail

    li   gp, 4              # najnowsza wartość wygrywa (podwójny zapis)
    addi a0, zero, 1
    addi a0, zero, 2
    add  a1, a0, zero
    li   t2, 2
    bne  a1, t2, fail

    li   gp, 5              # load-use
    li   a0, 41
    sw   a0, 0(s0)
    lw   a1, 0(s0)
    addi a1, a1, 1
    li   t2, 42
    bne  a1, t2, fail
    lw   a1, 0(s0)
    add  a2, a1, a1
    li   t2, 82
    bne  a2, t2, fail

    li   gp, 6              # load -> store (dana do zapisu prosto z load)
    lw   a0, 0(s0)
    sw   a0, 4(s0)
    lw   a1, 4(s0)
    li   t2, 41
    bne  a1, t2, fail

    li   gp, 7              # load -> branch
    lw   a0, 0(s0)
    li   t2, 41
    beq  a0, t2, ok7
    j    fail
ok7:

    li   gp, 8              # zapis do x0 nie może być forwardowany
    addi zero, zero, 5
    add  a0, zero, zero
    bnez a0, fail

    li   gp, 9              # jal -> natychmiastowe użycie ra
    jal  ra, next9
next9:
    mv   a0, ra
    la   t2, next9
    bne  a0, t2, fail

    li   gp, 10             # skok wykonany: kolejne instrukcje muszą zostać anulowane
    li   a0, 0
    beq  zero, zero, tgt10
    addi a0, a0, 1
    addi a0, a0, 1
    addi a0, a0, 1
tgt10:
    bnez a0, fail

    li   gp, 11             # jalr do adresu policzonego tuż przed
    la   t0, tgt11
    jalr zero, 0(t0)
    j    fail
    j    fail
tgt11:

    li   gp, 12             # adres dla load policzony tuż przed
    addi s1, s0, 4
    lw   a0, 0(s1)
    li   t2, 41
    bne  a0, t2, fail

    li   gp, 13             # dana do store policzona tuż przed
    addi a0, zero, 99
    sw   a0, 8(s0)
    lw   a1, 8(s0)
    li   t2, 99
    bne  a1, t2, fail

    li   gp, 14             # load -> load (adres z poprzedniego load)
    sw   s0, 12(s0)         # buf[3] = &buf[0]
    lw   a0, 12(s0)
    lw   a1, 0(a0)
    li   t2, 41
    bne  a1, t2, fail

    li   gp, 15             # branch od razu po ALU
    addi a0, zero, 3
    addi a1, zero, 3
    bne  a0, a1, fail

    li   gp, 16             # pętla z load-use i branchem wstecz
    li   t0, 4              # licznik
    li   a1, 0
    sw   zero, 16(s0)
loop16:
    lw   a0, 16(s0)
    addi a0, a0, 5
    sw   a0, 16(s0)
    addi t0, t0, -1
    bnez t0, loop16
    lw   a0, 16(s0)
    li   t2, 20
    bne  a0, t2, fail

    j    pass
.include "test_end.S"

.align 2
buf:
    .space 32
