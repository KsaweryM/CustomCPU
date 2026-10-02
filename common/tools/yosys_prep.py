#!/usr/bin/env python3
"""yosys_prep — obejście ograniczenia Yosysa 0.33 dla `make synth`.

Yosys 0.33 nie rozumie `module foo import rv32i_pkg::*; (...)`.
Ten skrypt skleja pliki w jeden, usuwając import z nagłówka i wklejając
zawartość pakietu (same localparam) na początek ciała modułu.
Semantycznie to to samo, a Ty możesz pisać normalny SystemVerilog.
Twoich plików nie zmienia.

Użycie:  yosys_prep.py -o out.sv rv32i_pkg.sv plik1.sv plik2.sv ...
"""
import re
import sys


def match_paren(s, i):
    depth = 0
    for k in range(i, len(s)):
        if s[k] == "(":
            depth += 1
        elif s[k] == ")":
            depth -= 1
            if depth == 0:
                return k
    raise SystemExit("yosys_prep: niesparowany nawias")


def main():
    args = sys.argv[1:]
    if "-o" not in args:
        raise SystemExit(__doc__)
    i = args.index("-o")
    out = args[i + 1]
    files = args[:i] + args[i + 2:]
    pkgs, srcs = {}, []
    for f in files:
        text = open(f).read()
        m = re.search(r"\bpackage\s+(\w+)\s*;(.*?)\bendpackage\b", text, re.S)
        if m:
            pkgs[m.group(1)] = m.group(2)
        else:
            srcs.append((f, text))
    hdr = re.compile(r"\bmodule\s+(\w+)\s+import\s+(\w+)::\*\s*;\s*")
    result = []
    for f, text in srcs:
        while True:
            m = hdr.search(text)
            if not m:
                break
            name, pkg = m.group(1), m.group(2)
            j = m.end()
            if text[j] == "#":
                j = match_paren(text, text.index("(", j)) + 1
            k = match_paren(text, text.index("(", j))
            semi = text.index(";", k)
            text = (text[:m.start()] + f"module {name} " + text[m.end():semi + 1]
                    + f"\n  // --- wklejone z pakietu {pkg} ---{pkgs[pkg]}\n" + text[semi + 1:])
        result.append(f"// ===== {f} =====\n{text}\n")
    with open(out, "w") as fo:
        fo.write("".join(result))


if __name__ == "__main__":
    main()
