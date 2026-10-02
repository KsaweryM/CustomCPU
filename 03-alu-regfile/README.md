# Moduł 03 — ALU, bank rejestrów, komparator skoków

**Cel:** zbudować trzy największe bloki ścieżki danych procesora RV32I.
Od tego modułu interfejsy są „kontraktem”: moduły 05 i 08 użyją dokładnie
tych portów.

**Czas:** 1–2 wieczory.

---

## 1. Krótko o RV32I (szczegóły w module 04)

RISC-V RV32I to 32-bitowa architektura typu load/store:
- **32 rejestry** `x0`..`x31` po 32 bity, przy czym **`x0` jest zawsze zerem**
  (zapis jest ignorowany). Dzięki temu wiele pseudoinstrukcji jest darmowych:
  `mv a, b` = `addi a, b, 0`, `nop` = `addi x0, x0, 0`, `j L` = `jal x0, L`.
- Arytmetyka tylko na rejestrach. Pamięć jest dostępna wyłącznie przez load i store.
- Brak flag (nie ma rejestru statusu jak w x86/ARM). Skoki warunkowe same
  porównują dwa rejestry: `blt a0, a1, L`. Dlatego potrzebny jest
  komparator skoków, a nie flagi z ALU.

Nazwy ABI, które zobaczysz w asemblerze i disasemblerze:

| Rejestr | ABI | Rola |
|---|---|---|
| x0 | zero | stałe zero |
| x1 | ra | adres powrotu |
| x2 | sp | wskaźnik stosu |
| x3 | gp | global pointer (u nas: numer podtestu) |
| x5–7, x28–31 | t0–t6 | tymczasowe (caller-saved) |
| x8–9, x18–27 | s0–s11 | zachowywane (callee-saved), s0 = fp |
| x10–17 | a0–a7 | argumenty i wynik funkcji |

## 2. ALU

Dziesięć operacji, które wystarczą na wszystkie instrukcje arytmetyczne RV32I:

| `op` | Operacja | Instrukcje |
|---|---|---|
| ADD | a + b | add, addi, adresy load/store, auipc, lui (0 + imm), jalr |
| SUB | a − b | sub |
| SLL/SRL/SRA | przesunięcia o b[4:0] | sll, slli, srl, srli, sra, srai |
| SLT/SLTU | a < b ? 1 : 0 | slt, slti, sltu, sltiu |
| XOR/OR/AND | bitowe | xor, xori, or, ori, and, andi |

Kody operacji (`ALU_*` w `common/rtl/rv32i_pkg.sv`) to celowo
`{funct7[5], funct3}` instrukcji R-type. Dekoder w module 05 dla instrukcji
`add/sub/sll/...` po prostu przepisze te bity.

Pakiet importujesz w nagłówku modułu, a stałe są wtedy widoczne bez prefiksu:
```systemverilog
module alu import rv32i_pkg::*; ( ... );
  ...  case (op) ALU_ADD: ...
```

### Optymalizacja (dla chętnych, po zaliczeniu testu)
Prosta wersja z `case` tworzy osobny sumator dla ADD, osobny subtraktor dla SUB i
jeszcze jeden dla SLT. Wszystkie trzy da się zrobić **jednym** sumatorem:
`a + (~b) + 1` to `a - b`, a SLT/SLTU to znak / przeniesienie z odejmowania
(uwaga na przepełnienie przy SLT!). Porównaj `make synth T=alu` przed i po.
Yosys może część tego współdzielenia zrobić sam, a część nie. Sprawdź.

## 3. Bank rejestrów

```
           rs1 ──►┌──────────────┐──► rs1_val      odczyt: kombinacyjny
           rs2 ──►│   32 × 32b   │──► rs2_val
  we, rd, rd_val ►│   x0 == 0    │                 zapis: na zboczu clk
           clk ──►└──────────────┘
```

Szczegóły, które mają znaczenie:
- **x0**: najprościej trzymać tablicę `regs[1:31]` i przy odczycie `rs == 0`
  zwracać 0. Zapis z `rd == 0` ignoruj.
- **Odczyt w tym samym takcie co zapis** pod ten sam adres zwraca *starą*
  wartość. W procesorze jednocyklowym to poprawne zachowanie: instrukcja czyta
  rejestry na początku taktu, a jej wynik zapisuje się na końcu. W potoku
  (moduł 08) dodasz „bypass” obok banku, nie w nim.
- **Inicjalizacja zerami (`initial`)**. Prawdziwy procesor po resecie ma w
  rejestrach śmieci, a programy nie mogą zakładać zer. W naszym kursie zerujemy
  rejestry z praktycznego powodu: w module 06 porównujemy ślad procesora z
  emulatorem, który ma zera. Gdyby program zapisał na stos niezainicjowany
  rejestr (kompilatory C robią to w prologach funkcji!), RTL miałby tam `X`, a
  emulator 0, i porównanie by się rozjechało. Na FPGA `initial` jest
  syntezowalne (wartości trafiają do bitstreamu), w ASIC nie.

### Ile to kosztuje?
Po napisaniu uruchom `make synth T=regfile`. Zobaczysz ok. 31×32 = 992
przerzutników i ok. 1900 multiplekserów 2:1: każdy port odczytu to 32-bitowy
multiplekser 32:1, czyli drzewo 31 multiplekserów 2:1 dla każdego z 32 bitów
(×2 porty ≈ 2000). Cała ALU jest o połowę mniejsza! Asynchroniczny odczyt z 2 portów to drogi luksus. Dlatego
prawdziwe procesory na FPGA mają często bank rejestrów z odczytem
synchronicznym (w BRAM-ie), a odczyt rejestrów jest wtedy osobnym etapem potoku.

## 4. Komparator skoków

| funct3 | instrukcja | warunek |
|---|---|---|
| 000 | beq | a == b |
| 001 | bne | a != b |
| 100 | blt | a < b (signed) |
| 101 | bge | a ≥ b (signed) |
| 110 | bltu | a < b (unsigned) |
| 111 | bgeu | a ≥ b (unsigned) |

Zwróć uwagę na strukturę: bit 0 funct3 to negacja (eq↔ne, lt↔ge), a bity 2:1
wybierają rodzaj porównania. Da się to zapisać krócej niż przez 6 przypadków.

---

## Zadania

### 3.1 ALU (`rtl/alu.sv`)
Test: 20 000 kombinacji z naciskiem na przypadki brzegowe (0, 1, −1, 0x80000000,
0x7FFFFFFF, przesunięcie o 33). Typowe błędy: `>>>` bez `$signed`, SLT bez
`$signed`, przesuwanie o całe `b` zamiast `b[4:0]`.

### 3.2 Bank rejestrów (`rtl/regfile.sv`)
Test sprawdza zerowy stan początkowy, x0, zapis z `we = 0` i *stary* odczyt
w takcie zapisu.

### 3.3 Komparator (`rtl/branch_cmp.sv`)

### 3.4 Synteza i myślenie o koszcie
```bash
make synth T=alu
make synth T=regfile
make synth T=branch_cmp
```
Zapisz liczby komórek i długości ścieżek. Odpowiedz sobie:
- który blok jest największy i dlaczego,
- która operacja ALU wyznacza najdłuższą ścieżkę (podpowiedź: zakomentuj
  na chwilę ADD/SUB/SLT i zsyntezuj ponownie).

**Gotowe, gdy:** `make test` → 3 × PASS, `make lint` czysto.
