#!/usr/bin/env python3
"""rvgen — generator losowych programów testowych RV32I (moduł 06).

Użycie:  rvgen.py --seed 7 -n 300 -o rand7.S

Program ustawia rejestry na losowe wartości, a potem wykonuje -n losowych
instrukcji: ALU, load/store do bufora, skoki w przód, krótkie pętle, jal/jalr.
Zależności między instrukcjami są celowo częste (dobre dla potoku).
Program zawsze kończy się `j pass` — o poprawności decyduje porównanie
śladu z emulatorem (tracecmp.py), a nie sam program.

Rejestry zarezerwowane: s9 (adres dla jalr), s10 (licznik pętli),
s11 (adres bufora danych).
"""
import argparse
import random

POOL = [f"x{i}" for i in range(1, 25)] + [f"x{i}" for i in range(28, 32)]
R_OPS = ["add", "sub", "sll", "slt", "sltu", "xor", "srl", "sra", "or", "and"]
I_OPS = ["addi", "slti", "sltiu", "xori", "ori", "andi"]
SH_OPS = ["slli", "srli", "srai"]
BR_OPS = ["beq", "bne", "blt", "bge", "bltu", "bgeu"]
LOADS = [("lw", 4), ("lh", 2), ("lhu", 2), ("lb", 1), ("lbu", 1)]
STORES = [("sw", 4), ("sh", 2), ("sb", 1)]
BUF = 256


class Gen:
    def __init__(self, rnd, mext=False):
        self.r = rnd
        self.lines = []
        self.recent = []
        self.label_n = 0
        self.mext = mext

    def label(self):
        self.label_n += 1
        return f"L{self.label_n}"

    def src(self):
        if self.recent and self.r.random() < 0.5:
            return self.r.choice(self.recent[-3:])
        return self.r.choice(POOL + ["zero"])

    def dst(self):
        d = "zero" if self.r.random() < 0.03 else self.r.choice(POOL)
        self.recent.append(d)
        return d

    def emit(self, s):
        self.lines.append("    " + s)

    def imm12(self):
        return self.r.choice([0, 1, -1, 2047, -2048, self.r.randint(-2048, 2047)])

    def simple(self):
        """Instrukcja bez skoków."""
        k = self.r.random()
        if k < 0.30:
            ops = R_OPS + (["mul", "mulh", "mulhsu", "mulhu", "div", "divu", "rem", "remu"] if self.mext else [])
            self.emit(f"{self.r.choice(ops)} {self.dst()}, {self.src()}, {self.src()}")
        elif k < 0.50:
            self.emit(f"{self.r.choice(I_OPS)} {self.dst()}, {self.src()}, {self.imm12()}")
        elif k < 0.58:
            self.emit(f"{self.r.choice(SH_OPS)} {self.dst()}, {self.src()}, {self.r.randint(0, 31)}")
        elif k < 0.63:
            self.emit(f"{self.r.choice(['lui', 'auipc'])} {self.dst()}, {self.r.randint(0, 0xFFFFF)}")
        elif k < 0.82:
            op, w = self.r.choice(LOADS)
            self.emit(f"{op} {self.dst()}, {self.r.randrange(0, BUF, w)}(s11)")
        else:
            op, w = self.r.choice(STORES)
            self.emit(f"{op} {self.src()}, {self.r.randrange(0, BUF, w)}(s11)")

    def gen(self, n):
        for reg in POOL:
            self.emit(f"li {reg}, {self.r.randint(0, 0xFFFFFFFF)}")
        self.emit("la s11, buf")
        i = 0
        while i < n:
            k = self.r.random()
            if k < 0.08:      # skok warunkowy w przód
                l = self.label()
                self.emit(f"{self.r.choice(BR_OPS)} {self.src()}, {self.src()}, {l}")
                for _ in range(self.r.randint(0, 3)):
                    self.simple()
                self.lines.append(f"{l}:")
            elif k < 0.11:    # jal w przód, czasem z linkiem
                l = self.label()
                self.emit(f"jal {self.dst() if self.r.random() < 0.5 else 'zero'}, {l}")
                for _ in range(self.r.randint(0, 2)):
                    self.simple()
                self.lines.append(f"{l}:")
            elif k < 0.13:    # jalr przez rejestr
                l = self.label()
                self.emit(f"la s9, {l}")
                self.emit(f"jalr {self.dst()}, 0(s9)")
                self.simple()
                self.lines.append(f"{l}:")
            elif k < 0.16:    # krótka pętla
                l = self.label()
                self.emit(f"li s10, {self.r.randint(1, 5)}")
                self.lines.append(f"{l}:")
                for _ in range(self.r.randint(1, 5)):
                    self.simple()
                self.emit("addi s10, s10, -1")
                self.emit(f"bnez s10, {l}")
            else:
                self.simple()
            i += 1
        self.emit("j pass")
        self.lines.append('.include "test_end.S"')
        self.lines.append(".align 2")
        self.lines.append("buf:")
        for _ in range(BUF // 4):
            self.emit(f".word 0x{self.r.randint(0, 0xFFFFFFFF):08x}")
        return "\n".join(self.lines) + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("-n", type=int, default=300, help="liczba losowych instrukcji")
    ap.add_argument("-o", "--output", required=True)
    ap.add_argument("--mext", action="store_true", help="używaj też instrukcji rozszerzenia M")
    a = ap.parse_args()
    with open(a.output, "w") as f:
        f.write(f"# wygenerowane: rvgen.py --seed {a.seed} -n {a.n}\n")
        f.write(Gen(random.Random(a.seed), a.mext).gen(a.n))


if __name__ == "__main__":
    main()
