# Moduł 04 — Architektura RV32I i emulator w C

**Cel:** znać RV32I na poziomie bitów i napisać **model referencyjny** procesora
w C, czyli emulator, z którym w modułach 06–08 porównasz swój sprzęt instrukcja
po instrukcji. W tej części korzystasz ze swojej przewagi: emulator to zwykły
program w C.

**Czas:** 2–3 wieczory.

---

## 1. Formaty instrukcji

Każda instrukcja ma 32 bity. Pola rejestrów są **zawsze w tych samych miejscach**,
więc dekoder może czytać rejestry, zanim jeszcze wie, co to za instrukcja.

```
 31        25 24    20 19    15 14  12 11         7 6       0
┌────────────┬────────┬────────┬──────┬────────────┬─────────┐
│   funct7   │  rs2   │  rs1   │funct3│     rd     │ opcode  │  R  add x1, x2, x3
├────────────┴────────┼────────┼──────┼────────────┼─────────┤
│      imm[11:0]      │  rs1   │funct3│     rd     │ opcode  │  I  addi, lw, jalr
├────────────┬────────┼────────┼──────┼────────────┼─────────┤
│ imm[11:5]  │  rs2   │  rs1   │funct3│  imm[4:0]  │ opcode  │  S  sw
├─┬──────────┼────────┼────────┼──────┼────────┬─┬─┼─────────┤
│*│imm[10:5] │  rs2   │  rs1   │funct3│imm[4:1]│*│ │ opcode  │  B  beq   (* = imm[12], imm[11])
├─┴──────────┴────────┴────────┴──────┼────────┴─┴─┼─────────┤
│              imm[31:12]             │     rd     │ opcode  │  U  lui, auipc
├─┬──────────────────┬─┬──────────────┼────────────┼─────────┤
│*│    imm[10:1]     │*│  imm[19:12]  │     rd     │ opcode  │  J  jal   (* = imm[20], imm[11])
└─┴──────────────────┴─┴──────────────┴────────────┴─────────┘
```

Wartości stałych (immediate):

| Format | Immediate (32 bity) |
|---|---|
| I | `{{20{i[31]}}, i[31:20]}` |
| S | `{{20{i[31]}}, i[31:25], i[11:7]}` |
| B | `{{19{i[31]}}, i[31], i[7], i[30:25], i[11:8], 1'b0}` |
| U | `{i[31:12], 12'b0}` |
| J | `{{11{i[31]}}, i[31], i[19:12], i[20], i[30:21], 1'b0}` |

**Dlaczego te bity są tak „pomieszane”?** Zasada projektowa RISC-V: każdy bit
immediate'a ma pochodzić z jak najmniejszej liczby pozycji w instrukcji.
Bit znaku to *zawsze* `instr[31]`, więc rozszerzanie znakiem może zacząć się
przed dekodowaniem formatu. Bity `[10:5]` są zawsze w `instr[30:25]`. W sprzęcie
każdy bit wyniku to mały multiplekser o 2–3 wejściach zamiast dużego.
W B i J brakuje bitu 0, bo skoki są zawsze o parzystą liczbę bajtów. Zyskujemy
dzięki temu dwukrotnie większy zasięg (±4 KiB dla B, ±1 MiB dla J).

## 2. Lista instrukcji RV32I

| opcode (binarnie) | Format | Instrukcje | Semantyka |
|---|---|---|---|
| `0110111` LUI | U | lui rd, imm | rd = imm << 12 |
| `0010111` AUIPC | U | auipc rd, imm | rd = pc + (imm << 12) |
| `1101111` JAL | J | jal rd, off | rd = pc+4; pc += off |
| `1100111` JALR | I | jalr rd, off(rs1) | t = (rs1+off) & ~1; rd = pc+4; pc = t |
| `1100011` BRANCH | B | beq bne blt bge bltu bgeu | if (cmp(rs1, rs2)) pc += off |
| `0000011` LOAD | I | lb lh lw lbu lhu | rd = ext(mem[rs1+off]) |
| `0100011` STORE | S | sb sh sw | mem[rs1+off] = rs2 (8/16/32 bity) |
| `0010011` OP-IMM | I | addi slti sltiu xori ori andi slli srli srai | rd = rs1 op imm |
| `0110011` OP | R | add sub sll slt sltu xor srl sra or and | rd = rs1 op rs2 |
| `0001111` FENCE | I | fence | u nas: nop |
| `1110011` SYSTEM | I | ecall, ebreak, csr* | u nas: nop |

`funct3` wybiera wariant (ALU: rodzaj operacji; load/store: szerokość; branch:
warunek). `funct7` = `0100000` (czyli `instr[30] = 1`) odróżnia `sub` od `add`
i `sra`/`srai` od `srl`/`srli`. Przy `slli/srli/srai` pole rs2 to `shamt`
(przesunięcie o 0–31).

**Kolejność w `jalr` ma znaczenie:** gdy `rd == rs1` (np. `jalr a0, 0(a0)`),
cel liczysz ze *starej* wartości rs1. Test 06 to sprawdza.

## 3. Pseudoinstrukcje i `li`

Asembler rozwija wygodne skróty w prawdziwe instrukcje:

| Pseudo | Rozwinięcie |
|---|---|
| `nop` | `addi x0, x0, 0` |
| `mv rd, rs` | `addi rd, rs, 0` |
| `not rd, rs` | `xori rd, rs, -1` |
| `j L` / `jr rs` / `ret` | `jal x0, L` / `jalr x0, 0(rs)` / `jalr x0, 0(ra)` |
| `call L` | `jal ra, L` |
| `beqz rs, L` | `beq rs, x0, L` |
| `bgt a, b, L` | `blt b, a, L` |
| `li rd, imm32` | `lui rd, hi` + `addi rd, rd, lo` |

Pułapka w `li`: `addi` rozszerza 12-bitową stałą **znakiem**. Żeby załadować
`0x12345FFF`, nie wystarczy `lui 0x12345; addi 0xFFF`, bo `0xFFF` = −1!
Trzeba `hi = (v + 0x800) >> 12`, czyli `lui 0x12346; addi -1`. (`rvtool` robi to
za Ciebie, ale w emulatorze i dekoderze zobaczysz właśnie takie pary.)

## 4. Pamięć

- Adresowanie bajtowe, **little-endian**: słowo `0x11223344` pod adresem 0
  to bajty `44 33 22 11` pod adresami 0, 1, 2, 3.
- `lb`/`lh` rozszerzają znakiem, `lbu`/`lhu` zerami.
- Zakładamy dostępy **wyrównane** (`lw` pod adres podzielny przez 4, `lh` pod
  parzysty). Specyfikacja pozwala implementacji nie obsługiwać
  niewyrównanych dostępów (wtedy zgłasza wyjątek). U nas to zachowanie
  niezdefiniowane, a programy testowe ich nie używają.

## 5. Nasza maszyna

To samo „środowisko” mają emulator (`emu/rv32sim.c`) i testbench RTL
(`common/tb/soc_tb.sv`):

| Adres | Co | Dostęp |
|---|---|---|
| `0x0000_0000`–`0x0000_FFFF` | RAM 64 KiB, tu ładowany jest program | odczyt/zapis |
| `0x1000_0000` | TOHOST: zapis kończy symulację. 1 = PASS, (n<<1)\|1 = FAIL w podteście n | zapis |
| `0x1000_0004` | PUTCHAR: zapis wypisuje znak `wdata[7:0]` | zapis |
| `0x1000_0008` | CYCLES: licznik cykli (w emulatorze: liczba instrukcji) | odczyt |

Po resecie `pc = 0` i wszystkie rejestry są zerami (patrz moduł 03).

**Konwencja testów** (`common/sw/tests/*.S`): rejestr `gp` przechowuje numer
aktualnego podtestu, a na końcu jest skok do `pass` albo `fail` (plik
`test_end.S`). Gdy test zgłasza „FAIL: podtest 5”, szukaj w źródle linii
`li gp, 5`.

## 6. Narzędzia: `rvtool`

```bash
T=../common/tools/rvtool.py
python3 $T asm ../common/sw/tests/08_fib.S -I ../common/sw/tests -o fib.hex -l fib.lst
python3 $T dis fib.hex              # disasemblacja całego obrazu
python3 $T dis 0x00a50533           # jedno słowo: add a0, a0, a0
```
Listing (`-l`) pokazuje adres, słowo maszynowe, linię źródła i disasemblację.
Makefile tworzy go automatycznie w `build/hex/*.lst`.

## 7. Ślad wykonania (commit trace)

Emulator z opcją `-t plik` zapisuje po każdej instrukcji jedną linię:
```
00000010 00a50533 x10=0000002a      pc, słowo instrukcji, zapisany rejestr i wartość
00000014 fe051ce3 -                 instrukcja nic nie zapisała do rejestru
```
Twój procesor w RTL wypisze dokładnie taki sam format. Porównując oba ślady
(`tracecmp.py`), znajdziesz **pierwszą** instrukcję, w której sprzęt odbiega od
modelu. To najskuteczniejsza technika debugowania procesorów, zarówno
w kursie, jak i w przemyśle.

---

## Zadania

### 4.1 Kodowanie na kartce
Zakoduj ręcznie (do postaci szesnastkowej) i sprawdź `rvtool dis`:
1. `addi a0, a0, -1`
2. `sw ra, 12(sp)`
3. `srai a1, a2, 3`
4. `lui t0, 0x10000`
5. `beq a0, zero, +16` (skok 16 bajtów do przodu)
6. `jal ra, -2048`

Przy 5 i 6 rozpisz bity immediate'a na pozycje w instrukcji. To najlepsze
przygotowanie do zadania 4.2.

### 4.2 Generator immediate'ów (`rtl/imm_gen.sv`)
```bash
make unit
```
Wektory testowe w `tb/imm_vectors.txt` wygenerował asembler (400 instrukcji
wszystkich formatów, z przypadkami brzegowymi). Gdy test zgłasza błąd,
zdekoduj instrukcję: `python3 ../common/tools/rvtool.py dis 0x<słowo>`.

### 4.3 Emulator (`emu/rv32sim.c`)
Gotowe są: pamięć i MMIO, ładowanie `.hex`, pętla główna, zapis śladu.
Ty piszesz funkcję `step()`, czyli dekodowanie i wykonanie jednej instrukcji
(opis kontraktu jest w komentarzu nad funkcją).

```bash
make emu-test                 # wszystkie programy testowe
make emu-test P=07_load_store # jeden, z wyjściem i śladem w build/07_load_store.trace
```
Programy są ułożone od najprostszych. `01_smoke` potrzebuje tylko `lui`, `addi`,
`sw`, `jal`. Implementuj instrukcje w kolejności testów.

Kilka rad z praktyki:
- Pisz z myślą o porównywaniu z RTL: ten emulator jest „specyfikacją”. Jasność
  ważniejsza niż wydajność.
- Wartość zwracana przez `step()` (numer rd albo 0) trafia do śladu. Dla
  branch/store/fence musi to być 0, a dla instrukcji z `rd = x0` też 0.
- `make emu-test` musi pokazać 12 × PASS. Dopiero wtedy emulator nadaje się na
  wzorzec dla sprzętu.

### 4.4 Czytanie programu
Uruchom `make emu-test P=10_recursion` i otwórz `build/hex/10_recursion.lst`
oraz `build/10_recursion.trace`.
- Znajdź w śladzie pierwsze wywołanie `fib` i prześledź, jak `sp` maleje.
- Ile instrukcji wykonuje `mul(1234, 5678)`? Dlaczego tyle? (Ile bitów ma 5678?)
- Policz (np. `grep -c`), ile razy wykonało się `jalr`. Skąd ta liczba?

**Gotowe, gdy:** `make test` → PASS dla `imm_gen` i 12 × PASS emulatora.

*Opcjonalnie (moduł 09):* rozszerzenie M w emulatorze, test: `make emu-test-m`.
