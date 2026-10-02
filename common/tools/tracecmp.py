#!/usr/bin/env python3
"""tracecmp — porównuje ślad wykonania z modelu referencyjnego i z RTL.

Użycie:  tracecmp.py ref.trace dut.trace

Format linii śladu (z rv32sim i z soc_tb):
    <pc> <instr> x<rd>=<wartość>     instrukcja zapisała rejestr
    <pc> <instr> -                   instrukcja nie zapisała rejestru

Ślad referencyjny kończy się na zapisie do TOHOST. Ślad z RTL może być
o kilka linii dłuższy (testbench dociąga potok po końcu testu), więc
porównujemy całą długość śladu referencyjnego.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rvtool import dis  # noqa: E402


def load(path):
    with open(path) as f:
        return [l.split() for l in f if l.strip()]


def fmt(t):
    pc, ins = int(t[0], 16), int(t[1], 16)
    eff = t[2] if len(t) > 2 else "?"
    return f"{t[0]}: {t[1]}  {dis(ins, pc):32} {eff}"


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(2)
    ref, dut = load(sys.argv[1]), load(sys.argv[2])
    for i, r in enumerate(ref):
        if i >= len(dut):
            print(f"RÓŻNICA: ślad RTL kończy się po {len(dut)} instrukcjach, referencja ma {len(ref)}.")
            ctx(ref, i)
            print(f"  następna oczekiwana: {fmt(r)}")
            sys.exit(1)
        if r != dut[i]:
            print(f"RÓŻNICA w instrukcji nr {i + 1}:")
            ctx(ref, i)
            print(f"  oczekiwano (ref): {fmt(r)}")
            print(f"  jest       (RTL): {fmt(dut[i])}")
            if r[0] != dut[i][0]:
                print("  -> inny PC: błąd sterowania przepływem (skok/branch) w jednej z poprzednich instrukcji")
            elif r[1] != dut[i][1]:
                print("  -> ten sam PC, inna instrukcja: problem z pobraniem instrukcji / pamięcią")
            elif "x" in dut[i][2].split("=")[-1]:
                print("  -> wartość X: niezainicjowany sygnał/rejestr albo brak przypisania w którejś gałęzi")
            else:
                print("  -> ta sama instrukcja, inny efekt: błąd wykonania (ALU, LSU, forwarding...)")
            sys.exit(1)
    print(f"ZGODNE: {len(ref)} instrukcji")


def ctx(ref, i, n=5):
    if i:
        print("  ostatnie zgodne:")
        for t in ref[max(0, i - n):i]:
            print(f"    {fmt(t)}")


if __name__ == "__main__":
    main()
