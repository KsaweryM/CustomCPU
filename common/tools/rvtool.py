#!/usr/bin/env python3
"""rvtool — minimalny asembler / disasembler RV32I (+M) na potrzeby kursu.

Użycie:
  rvtool.py asm  prog.S -o prog.hex [-l prog.lst] [-I katalog] [--pad-nops N]
  rvtool.py dis  prog.hex            # disasembluje cały plik .hex
  rvtool.py dis  0x00500093          # disasembluje jedno słowo
  rvtool.py bin2hex prog.bin -o prog.hex

Format .hex: jedno 32-bitowe słowo (little-endian) na linię, od adresu 0,
dokładnie tak, jak czyta je $readmemh do tablicy logic [31:0] mem[].

Obsługiwane:
  * wszystkie instrukcje RV32I i RV32M,
  * pseudoinstrukcje: nop li la mv not neg seqz snez sltz sgtz j jr ret call
    tail beqz bnez blez bgez bltz bgtz bgt ble bgtu bleu,
  * dyrektywy: .text .data .globl (ignorowane) .org .align .balign .word .half
    .byte .space .zero .ascii .asciz .string .equ .set .include,
  * wyrażenia stałe: + - * / << >> & | ^ ~ ( ), symbole, 'c', 0x.., 0b...

Ograniczenia (świadome): jedna sekcja zaczynająca się pod adresem 0,
brak makr, brak %hi/%lo (użyj li / la).

--pad-nops N wstawia N instrukcji nop przed każdą prawdziwą instrukcją.
Przydaje się w module 08: z N=4 potok nie ma żadnych hazardów danych.
Etykieta wskazuje na pierwszy z tych nop-ów (dzięki temu adres powrotu
jal nadal równa się etykiecie następnej instrukcji). Symbol __PAD ma
wartość N (0 bez tej opcji).
"""

import argparse
import ast
import os
import re
import sys

# --------------------------------------------------------------------------
# Rejestry
# --------------------------------------------------------------------------
ABI = ["zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
       "s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
       "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
       "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"]
REGS = {f"x{i}": i for i in range(32)}
REGS.update({n: i for i, n in enumerate(ABI)})
REGS["fp"] = 8

# --------------------------------------------------------------------------
# Tablice kodowania
# --------------------------------------------------------------------------
OP_LUI, OP_AUIPC, OP_JAL, OP_JALR = 0x37, 0x17, 0x6F, 0x67
OP_BRANCH, OP_LOAD, OP_STORE = 0x63, 0x03, 0x23
OP_IMM, OP_REG, OP_FENCE, OP_SYSTEM = 0x13, 0x33, 0x0F, 0x73

R_TYPE = {  # nazwa: (funct7, funct3)
    "add": (0x00, 0), "sub": (0x20, 0), "sll": (0x00, 1), "slt": (0x00, 2),
    "sltu": (0x00, 3), "xor": (0x00, 4), "srl": (0x00, 5), "sra": (0x20, 5),
    "or": (0x00, 6), "and": (0x00, 7),
    "mul": (0x01, 0), "mulh": (0x01, 1), "mulhsu": (0x01, 2), "mulhu": (0x01, 3),
    "div": (0x01, 4), "divu": (0x01, 5), "rem": (0x01, 6), "remu": (0x01, 7),
}
I_ALU = {"addi": 0, "slti": 2, "sltiu": 3, "xori": 4, "ori": 6, "andi": 7}
SHIFT_I = {"slli": (0x00, 1), "srli": (0x00, 5), "srai": (0x20, 5)}
LOADS = {"lb": 0, "lh": 1, "lw": 2, "lbu": 4, "lhu": 5}
STORES = {"sb": 0, "sh": 1, "sw": 2}
BRANCHES = {"beq": 0, "bne": 1, "blt": 4, "bge": 5, "bltu": 6, "bgeu": 7}


class AsmError(Exception):
    pass


def bits(v, hi, lo):
    return (v >> lo) & ((1 << (hi - lo + 1)) - 1)


def check_range(v, nbits, signed, what):
    if signed:
        lo, hi = -(1 << (nbits - 1)), (1 << (nbits - 1)) - 1
    else:
        lo, hi = 0, (1 << nbits) - 1
    if not lo <= v <= hi:
        raise AsmError(f"{what} = {v} poza zakresem [{lo}, {hi}]")


def enc_r(f7, rs2, rs1, f3, rd, op):
    return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def enc_i(imm, rs1, f3, rd, op):
    check_range(imm, 12, True, "immediate")
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def enc_s(imm, rs2, rs1, f3, op):
    check_range(imm, 12, True, "offset")
    imm &= 0xFFF
    return (bits(imm, 11, 5) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | \
        (bits(imm, 4, 0) << 7) | op


def enc_b(off, rs2, rs1, f3, op):
    check_range(off, 13, True, "offset skoku warunkowego")
    if off & 1:
        raise AsmError("offset skoku musi być parzysty")
    off &= 0x1FFF
    return (bits(off, 12, 12) << 31) | (bits(off, 10, 5) << 25) | (rs2 << 20) | \
        (rs1 << 15) | (f3 << 12) | (bits(off, 4, 1) << 8) | (bits(off, 11, 11) << 7) | op


def enc_u(imm20, rd, op):
    check_range(imm20, 20, False, "immediate (20 bitów)")
    return (imm20 << 12) | (rd << 7) | op


def enc_j(off, rd, op):
    check_range(off, 21, True, "offset jal")
    if off & 1:
        raise AsmError("offset skoku musi być parzysty")
    off &= 0x1FFFFF
    return (bits(off, 20, 20) << 31) | (bits(off, 10, 1) << 21) | \
        (bits(off, 11, 11) << 20) | (bits(off, 19, 12) << 12) | (rd << 7) | op


def split_li(v):
    """Rozbija 32-bitową stałą na (hi20, lo12) tak, że (hi20 << 12) + lo12 == v."""
    v &= 0xFFFFFFFF
    lo = ((v & 0xFFF) ^ 0x800) - 0x800      # 12 bitów ze znakiem
    hi = ((v - lo) >> 12) & 0xFFFFF
    return hi, lo


# --------------------------------------------------------------------------
# Wyrażenia
# --------------------------------------------------------------------------
_ALLOWED_BIN = {ast.Add: lambda a, b: a + b, ast.Sub: lambda a, b: a - b,
                ast.Mult: lambda a, b: a * b, ast.FloorDiv: lambda a, b: a // b,
                ast.Div: lambda a, b: int(a / b),
                ast.LShift: lambda a, b: a << b, ast.RShift: lambda a, b: a >> b,
                ast.BitAnd: lambda a, b: a & b, ast.BitOr: lambda a, b: a | b,
                ast.BitXor: lambda a, b: a ^ b, ast.Mod: lambda a, b: a % b}
_ALLOWED_UN = {ast.USub: lambda a: -a, ast.UAdd: lambda a: a, ast.Invert: lambda a: ~a}


class Undefined(Exception):
    pass


class _Missing:
    def __init__(self, name):
        self.name = name


def evaluate(expr, symbols):
    expr = expr.strip()
    expr = re.sub(r"'(\\?.)'", lambda m: str(ord(bytes(m.group(1), "utf-8").decode("unicode_escape"))), expr)
    expr = re.sub(r"\b0b([01_]+)\b", lambda m: str(int(m.group(1).replace("_", ""), 2)), expr)
    # Nazwy symboli mogą kolidować ze słowami kluczowymi Pythona (pass, and...)
    # albo zawierać '.' i '$' -> podmieniamy je na bezpieczne identyfikatory.
    names = {}

    def mangle(m):
        names.setdefault(f"_sym{len(names)}", m.group(0))
        key = next(k for k, v in names.items() if v == m.group(0))
        return key
    orig = expr
    expr = re.sub(r"(?<![\w.$])[A-Za-z_.$][\w.$]*", mangle, expr)
    try:
        tree = ast.parse(expr, mode="eval")
    except SyntaxError:
        raise AsmError(f"niepoprawne wyrażenie: {orig!r}")
    symbols = {k: symbols[v] for k, v in names.items() if v in symbols} | \
        {k: _Missing(v) for k, v in names.items() if v not in symbols}

    def ev(n):
        if isinstance(n, ast.Expression):
            return ev(n.body)
        if isinstance(n, ast.Constant) and isinstance(n.value, int):
            return n.value
        if isinstance(n, ast.Name):
            v = symbols[n.id]
            if isinstance(v, _Missing):
                raise Undefined(v.name)
            return v
        if isinstance(n, ast.BinOp) and type(n.op) in _ALLOWED_BIN:
            return _ALLOWED_BIN[type(n.op)](ev(n.left), ev(n.right))
        if isinstance(n, ast.UnaryOp) and type(n.op) in _ALLOWED_UN:
            return _ALLOWED_UN[type(n.op)](ev(n.operand))
        raise AsmError(f"nieobsługiwane wyrażenie: {expr!r}")
    return ev(tree)


# --------------------------------------------------------------------------
# Parser
# --------------------------------------------------------------------------
class Stmt:
    def __init__(self, kind, name, args, src, loc):
        self.kind, self.name, self.args, self.src, self.loc = kind, name, args, src, loc
        self.addr = 0
        self.size = 0
        self.ninstr = 0   # liczba prawdziwych instrukcji (dla --pad-nops)


def strip_comment(line):
    out, in_str, in_chr = [], False, False
    i = 0
    while i < len(line):
        c = line[i]
        if c == "\\" and (in_str or in_chr):
            out.append(line[i:i + 2])
            i += 2
            continue
        if c == '"' and not in_chr:
            in_str = not in_str
        elif c == "'" and not in_str:
            in_chr = not in_chr
        elif not in_str and not in_chr:
            if c == "#" or line.startswith("//", i) or c == ";":
                break
        out.append(c)
        i += 1
    return "".join(out)


def split_args(s):
    args, cur, depth, in_str = [], "", 0, False
    for c in s:
        if c == '"':
            in_str = not in_str
        if not in_str:
            if c == "(":
                depth += 1
            elif c == ")":
                depth -= 1
            elif c == "," and depth == 0:
                args.append(cur.strip())
                cur = ""
                continue
        cur += c
    if cur.strip():
        args.append(cur.strip())
    return args


def parse_file(path, incdirs, out, depth=0):
    if depth > 16:
        raise AsmError("zbyt głęboko zagnieżdżone .include")
    with open(path) as f:
        lines = f.readlines()
    for lineno, raw in enumerate(lines, 1):
        loc = f"{os.path.basename(path)}:{lineno}"
        line = strip_comment(raw).strip()
        while True:
            m = re.match(r"^([A-Za-z_.$][\w.$]*)\s*:(.*)$", line)
            if not m:
                break
            out.append(Stmt("label", m.group(1), [], raw.rstrip(), loc))
            line = m.group(2).strip()
        if not line:
            continue
        parts = line.split(None, 1)
        name = parts[0].lower()
        args = split_args(parts[1]) if len(parts) > 1 else []
        if name == ".include":
            fn = args[0].strip('"')
            cands = [os.path.join(os.path.dirname(path), fn)] + [os.path.join(d, fn) for d in incdirs]
            for c in cands:
                if os.path.exists(c):
                    parse_file(c, incdirs, out, depth + 1)
                    break
            else:
                raise AsmError(f"{loc}: nie znaleziono pliku {fn}")
            continue
        kind = "dir" if name.startswith(".") else "instr"
        out.append(Stmt(kind, name, args, raw.rstrip(), loc))


def parse_string(s):
    s = s.strip()
    if not (s.startswith('"') and s.endswith('"')):
        raise AsmError(f"oczekiwano napisu w cudzysłowie: {s}")
    return bytes(s[1:-1], "utf-8").decode("unicode_escape").encode("latin-1")


# --------------------------------------------------------------------------
# Asembler
# --------------------------------------------------------------------------
class Assembler:
    def __init__(self, pad_nops=0):
        self.symbols = {"__PAD": pad_nops}
        self.pad = pad_nops

    # ---- operandy ----
    def reg(self, s):
        s = s.strip().lower()
        if s not in REGS:
            raise AsmError(f"nieznany rejestr: {s}")
        return REGS[s]

    def val(self, s):
        return evaluate(s, self.symbols)

    def mem_operand(self, s):
        m = re.match(r"^(.*)\(\s*([\w]+)\s*\)$", s.strip())
        if not m:
            raise AsmError(f"oczekiwano offset(rejestr), jest: {s}")
        off = m.group(1).strip()
        return (self.val(off) if off else 0), self.reg(m.group(2))

    # ---- rozmiar pseudoinstrukcji w 1. przebiegu ----
    def instr_count(self, st):
        if st.name == "li":
            try:
                v = self.val(st.args[1]) & 0xFFFFFFFF
            except Undefined:
                return 2
            hi, lo = split_li(v)
            if hi == 0:
                return 1
            return 1 if lo == 0 else 2
        if st.name in ("la",):
            return 2
        return 1

    # ---- kodowanie jednej (pseudo)instrukcji -> lista słów ----
    def encode(self, st, pc):
        n, a = st.name, st.args

        def need(k):
            if len(a) != k:
                raise AsmError(f"{n}: oczekiwano {k} operandów, jest {len(a)}")

        if n in R_TYPE:
            need(3)
            f7, f3 = R_TYPE[n]
            return [enc_r(f7, self.reg(a[2]), self.reg(a[1]), f3, self.reg(a[0]), OP_REG)]
        if n in I_ALU:
            need(3)
            return [enc_i(self.val(a[2]), self.reg(a[1]), I_ALU[n], self.reg(a[0]), OP_IMM)]
        if n in SHIFT_I:
            need(3)
            f7, f3 = SHIFT_I[n]
            sh = self.val(a[2])
            check_range(sh, 5, False, "shamt")
            return [enc_r(f7, sh, self.reg(a[1]), f3, self.reg(a[0]), OP_IMM)]
        if n in LOADS:
            need(2)
            off, rs1 = self.mem_operand(a[1])
            return [enc_i(off, rs1, LOADS[n], self.reg(a[0]), OP_LOAD)]
        if n in STORES:
            need(2)
            off, rs1 = self.mem_operand(a[1])
            return [enc_s(off, self.reg(a[0]), rs1, STORES[n], OP_STORE)]
        if n in BRANCHES:
            need(3)
            return [enc_b(self.val(a[2]) - pc, self.reg(a[1]), self.reg(a[0]), BRANCHES[n], OP_BRANCH)]
        if n == "lui" or n == "auipc":
            need(2)
            v = self.val(a[1])
            if v < 0:
                v &= 0xFFFFF
            return [enc_u(v, self.reg(a[0]), OP_LUI if n == "lui" else OP_AUIPC)]
        if n == "jal":
            if len(a) == 1:
                a = ["ra", a[0]]
            need(2)
            return [enc_j(self.val(a[1]) - pc, self.reg(a[0]), OP_JAL)]
        if n == "jalr":
            if len(a) == 1:
                return [enc_i(0, self.reg(a[0]), 0, 1, OP_JALR)]
            if len(a) == 2:
                off, rs1 = self.mem_operand(a[1])
                return [enc_i(off, rs1, 0, self.reg(a[0]), OP_JALR)]
            need(3)
            return [enc_i(self.val(a[2]), self.reg(a[1]), 0, self.reg(a[0]), OP_JALR)]
        if n == "fence":
            return [0x0FF0000F]
        if n == "ecall":
            return [0x00000073]
        if n == "ebreak":
            return [0x00100073]

        # ---- pseudoinstrukcje ----
        if n == "nop":
            return [enc_i(0, 0, 0, 0, OP_IMM)]
        if n == "li":
            need(2)
            rd = self.reg(a[0])
            v = self.val(a[1]) & 0xFFFFFFFF
            hi, lo = split_li(v)
            if st.ninstr == 1:
                if hi == 0:
                    return [enc_i(lo, 0, 0, rd, OP_IMM)]
                return [enc_u(hi, rd, OP_LUI)]
            return [enc_u(hi, rd, OP_LUI), enc_i(lo, rd, 0, rd, OP_IMM)]
        if n == "la":
            need(2)
            rd = self.reg(a[0])
            hi, lo = split_li(self.val(a[1]))
            return [enc_u(hi, rd, OP_LUI), enc_i(lo, rd, 0, rd, OP_IMM)]
        if n == "mv":
            need(2)
            return [enc_i(0, self.reg(a[1]), 0, self.reg(a[0]), OP_IMM)]
        if n == "not":
            need(2)
            return [enc_i(-1, self.reg(a[1]), 4, self.reg(a[0]), OP_IMM)]
        if n == "neg":
            need(2)
            return [enc_r(0x20, self.reg(a[1]), 0, 0, self.reg(a[0]), OP_REG)]
        if n == "seqz":
            need(2)
            return [enc_i(1, self.reg(a[1]), 3, self.reg(a[0]), OP_IMM)]
        if n == "snez":
            need(2)
            return [enc_r(0, self.reg(a[1]), 0, 3, self.reg(a[0]), OP_REG)]
        if n == "sltz":
            need(2)
            return [enc_r(0, 0, self.reg(a[1]), 2, self.reg(a[0]), OP_REG)]
        if n == "sgtz":
            need(2)
            return [enc_r(0, self.reg(a[1]), 0, 2, self.reg(a[0]), OP_REG)]
        if n == "j":
            need(1)
            return [enc_j(self.val(a[0]) - pc, 0, OP_JAL)]
        if n == "call":
            need(1)
            return [enc_j(self.val(a[0]) - pc, 1, OP_JAL)]
        if n == "tail":
            need(1)
            return [enc_j(self.val(a[0]) - pc, 0, OP_JAL)]
        if n == "jr":
            need(1)
            return [enc_i(0, self.reg(a[0]), 0, 0, OP_JALR)]
        if n == "ret":
            return [enc_i(0, 1, 0, 0, OP_JALR)]
        zb = {"beqz": ("beq", 0), "bnez": ("bne", 0), "bgez": ("bge", 0), "bltz": ("blt", 0),
              "blez": ("bge", 1), "bgtz": ("blt", 1)}
        if n in zb:
            need(2)
            base, swap = zb[n]
            r = self.reg(a[0])
            rs1, rs2 = (0, r) if swap else (r, 0)
            return [enc_b(self.val(a[1]) - pc, rs2, rs1, BRANCHES[base], OP_BRANCH)]
        sw = {"bgt": "blt", "ble": "bge", "bgtu": "bltu", "bleu": "bgeu"}
        if n in sw:
            need(3)
            return [enc_b(self.val(a[2]) - pc, self.reg(a[0]), self.reg(a[1]), BRANCHES[sw[n]], OP_BRANCH)]
        raise AsmError(f"nieznana instrukcja: {n}")

    # ---- dyrektywy: zwraca bajty (w 2. przebiegu) lub rozmiar ----
    def directive(self, st, addr, emit):
        n, a = st.name, st.args
        if n in (".text", ".data", ".bss", ".section", ".globl", ".global", ".type",
                 ".size", ".option", ".file", ".attribute", ".p2align_ignore"):
            return b""
        if n in (".equ", ".set"):
            if not emit:
                try:
                    self.symbols[a[0].strip()] = self.val(a[1])
                except Undefined as e:
                    raise AsmError(f".equ: symbol {e} musi być zdefiniowany wcześniej")
            return b""
        if n == ".org":
            target = self.val(a[0])
            if target < addr:
                raise AsmError(f".org 0x{target:x} cofa się (jesteśmy na 0x{addr:x})")
            return bytes(target - addr)
        if n in (".align", ".p2align", ".balign"):
            al = self.val(a[0])
            if n != ".balign":
                al = 1 << al
            return bytes((-addr) % al)
        if n in (".space", ".zero", ".skip"):
            return bytes(self.val(a[0]))
        if n in (".word", ".half", ".hword", ".short", ".byte"):
            w = {".word": 4, ".half": 2, ".hword": 2, ".short": 2, ".byte": 1}[n]
            out = b""
            for x in a:
                v = self.val(x) if emit else 0
                out += (v & ((1 << (8 * w)) - 1)).to_bytes(w, "little")
            return out
        if n in (".ascii", ".asciz", ".string"):
            out = b""
            for x in a:
                out += parse_string(x) + (b"\0" if n != ".ascii" else b"")
            return out
        raise AsmError(f"nieznana dyrektywa: {n}")

    def assemble(self, stmts):
        # 1. przebieg: adresy i symbole
        addr = 0
        for st in stmts:
            try:
                st.addr = addr
                if st.kind == "label":
                    if st.name in self.symbols:
                        raise AsmError(f"etykieta {st.name} zdefiniowana dwukrotnie")
                    self.symbols[st.name] = addr
                elif st.kind == "dir":
                    st.size = len(self.directive(st, addr, emit=False))
                else:
                    if addr % 4:
                        raise AsmError("instrukcja pod niewyrównanym adresem (dodaj .align 2)")
                    st.ninstr = self.instr_count(st)
                    st.size = 4 * st.ninstr * (1 + self.pad)
                addr += st.size
            except (AsmError, Undefined) as e:
                raise AsmError(f"{st.loc}: {e}\n    {st.src}")
        # 2. przebieg: kodowanie
        image = bytearray()
        listing = []
        for st in stmts:
            try:
                assert len(image) == st.addr
                if st.kind == "label":
                    listing.append((None, None, st.src))
                    continue
                if st.kind == "dir":
                    data = self.directive(st, st.addr, emit=True)
                    image += data
                    listing.append((st.addr, data, st.src))
                    continue
                # pc pierwszego słowa leży za ewentualnymi nop-ami (--pad-nops)
                words = self.encode(st, st.addr + 4 * self.pad)
                if len(words) != st.ninstr:
                    raise AsmError("wewnętrzny błąd: zmiana rozmiaru pseudoinstrukcji")
                for i, w in enumerate(words):
                    # nop-y PRZED instrukcją: wtedy adres powrotu jal (pc+4)
                    # nadal wskazuje na etykietę następnej instrukcji
                    for _ in range(self.pad):
                        image += (0x00000013).to_bytes(4, "little")
                    pc = len(image)
                    image += w.to_bytes(4, "little")
                    listing.append((pc, w, st.src if i == 0 else ""))
            except Undefined as e:
                raise AsmError(f"{st.loc}: niezdefiniowany symbol {e}\n    {st.src}")
            except AsmError as e:
                raise AsmError(f"{st.loc}: {e}\n    {st.src}")
        while len(image) % 4:
            image.append(0)
        return bytes(image), listing


# --------------------------------------------------------------------------
# Disasembler
# --------------------------------------------------------------------------
def sext(v, n):
    return v - (1 << n) if v & (1 << (n - 1)) else v


def dis(w, pc=None):
    op = w & 0x7F
    rd, f3, rs1, rs2, f7 = bits(w, 11, 7), bits(w, 14, 12), bits(w, 19, 15), bits(w, 24, 20), bits(w, 31, 25)
    R = lambda i: ABI[i]
    imm_i = sext(bits(w, 31, 20), 12)
    imm_s = sext((bits(w, 31, 25) << 5) | bits(w, 11, 7), 12)
    imm_b = sext((bits(w, 31, 31) << 12) | (bits(w, 7, 7) << 11) | (bits(w, 30, 25) << 5) | (bits(w, 11, 8) << 1), 13)
    imm_j = sext((bits(w, 31, 31) << 20) | (bits(w, 19, 12) << 12) | (bits(w, 20, 20) << 11) | (bits(w, 30, 21) << 1), 21)

    def tgt(off):
        return f"0x{(pc + off) & 0xFFFFFFFF:x}" if pc is not None else f"pc{off:+d}"

    if op == OP_REG:
        for n, (a7, a3) in R_TYPE.items():
            if a7 == f7 and a3 == f3:
                return f"{n} {R(rd)}, {R(rs1)}, {R(rs2)}"
    elif op == OP_IMM:
        if f3 == 1 and f7 == 0:
            return f"slli {R(rd)}, {R(rs1)}, {rs2}"
        if f3 == 5 and f7 in (0, 0x20):
            return f"{'srai' if f7 else 'srli'} {R(rd)}, {R(rs1)}, {rs2}"
        for n, a3 in I_ALU.items():
            if a3 == f3:
                if w == 0x13:
                    return "nop"
                return f"{n} {R(rd)}, {R(rs1)}, {imm_i}"
    elif op == OP_LOAD:
        for n, a3 in LOADS.items():
            if a3 == f3:
                return f"{n} {R(rd)}, {imm_i}({R(rs1)})"
    elif op == OP_STORE:
        for n, a3 in STORES.items():
            if a3 == f3:
                return f"{n} {R(rs2)}, {imm_s}({R(rs1)})"
    elif op == OP_BRANCH:
        for n, a3 in BRANCHES.items():
            if a3 == f3:
                return f"{n} {R(rs1)}, {R(rs2)}, {tgt(imm_b)}"
    elif op == OP_LUI:
        return f"lui {R(rd)}, 0x{bits(w, 31, 12):x}"
    elif op == OP_AUIPC:
        return f"auipc {R(rd)}, 0x{bits(w, 31, 12):x}"
    elif op == OP_JAL:
        return f"jal {R(rd)}, {tgt(imm_j)}"
    elif op == OP_JALR and f3 == 0:
        return f"jalr {R(rd)}, {imm_i}({R(rs1)})"
    elif op == OP_FENCE:
        return "fence"
    elif op == OP_SYSTEM:
        return {0x73: "ecall", 0x100073: "ebreak"}.get(w, f"system 0x{w:08x}")
    return f".word 0x{w:08x}   # nieznana instrukcja"


def read_hex(path):
    words = []
    with open(path) as f:
        for line in f:
            line = line.split("//")[0].strip()
            if not line or line.startswith("@"):
                continue
            words.extend(int(t, 16) for t in line.split())
    return words


def write_hex(path, image):
    with open(path, "w") as f:
        for i in range(0, len(image), 4):
            f.write(f"{int.from_bytes(image[i:i + 4], 'little'):08x}\n")


# --------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    pa = sub.add_parser("asm")
    pa.add_argument("src")
    pa.add_argument("-o", "--output", required=True)
    pa.add_argument("-l", "--listing")
    pa.add_argument("-I", dest="incdirs", action="append", default=[])
    pa.add_argument("--pad-nops", type=int, default=0)
    pd = sub.add_parser("dis")
    pd.add_argument("what")
    pb = sub.add_parser("bin2hex")
    pb.add_argument("src")
    pb.add_argument("-o", "--output", required=True)
    args = ap.parse_args()

    if args.cmd == "asm":
        stmts = []
        try:
            parse_file(args.src, args.incdirs, stmts)
            image, listing = Assembler(args.pad_nops).assemble(stmts)
        except AsmError as e:
            print(f"rvtool: błąd: {e}", file=sys.stderr)
            sys.exit(1)
        write_hex(args.output, image)
        if args.listing:
            with open(args.listing, "w") as f:
                for addr, data, src in listing:
                    if addr is None:
                        f.write(f"{'':22}{src}\n")
                    elif isinstance(data, int):
                        f.write(f"{addr:08x}:  {data:08x}    {src:40} # {dis(data, addr)}\n")
                    else:
                        f.write(f"{addr:08x}:  {data[:8].hex():12}{src}\n")
    elif args.cmd == "dis":
        if os.path.exists(args.what):
            for i, w in enumerate(read_hex(args.what)):
                print(f"{4 * i:08x}:  {w:08x}    {dis(w, 4 * i)}")
        else:
            w = int(args.what, 0)
            print(f"{w:08x}    {dis(w)}")
    elif args.cmd == "bin2hex":
        with open(args.src, "rb") as f:
            image = f.read()
        image += bytes((-len(image)) % 4)
        write_hex(args.output, image)


if __name__ == "__main__":
    main()
