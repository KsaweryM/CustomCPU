# Moduł 05 — Procesor jednocyklowy RV32I

**Cel:** złożyć działający procesor, który wykonuje prawdziwe programy w kodzie
maszynowym RISC-V. Każda instrukcja zajmuje jeden takt zegara.

**Czas:** 3–4 wieczory.

---

## 1. Ścieżka danych

```
                        ┌────────────────────────────────────────────────────────────┐
                        │                     pc_next                                │
   ┌────┐   pc    ┌─────┴────┐ instr                                                 │
   │ PC ├──┬─────►│   imem   ├──┬──────────────► control ──► sygnały sterujące       │
   └─▲──┘  │      │ (w tb)   │  │                                                   │
     │     │      └──────────┘  ├─ rs1,rs2 ─►┌─────────┐ rs1_val ┌───┐               │
     │     │                    │            │ regfile ├────────►│ A │  ┌─────┐       │
     │     │                    │      ┌────►│         ├──┐      │mux├─►│     │ alu_y │
     │     │                    │      │ wb  └─────────┘  │      └───┘  │ ALU ├──┬────┤
     │     │                    └─► imm_gen ──── imm ──┐  │rs2_val┌───┐ │     │  │    │
     │     │                                           └──┼──────┤ B ├─►│     │  │    │
     │     │                                              │      │mux│  └─────┘  │    │
     │     │                                              │      └───┘           │    │
     │     │                                              │  ┌──────────┐ addr   │    │
     │     │                                              └─►│   LSU    │◄───────┘    │
     │     │                                                 │  + dmem  │             │
     │     │                                                 └────┬─────┘ load_data   │
     │     │                       wb_sel: ALU / MEM / PC+4 ◄─────┘                   │
     │     │                                                                          │
     │     └──► pc+4, pc+imm (branch/jal), alu_y & ~1 (jalr) ───────────────────────┘
     │                      ▲ branch_cmp(rs1_val, rs2_val, funct3)
     └──────────────────────┘
```

W jednym takcie, od zbocza do zbocza:
1. `pc` adresuje pamięć instrukcji, a `instr` pojawia się kombinacyjnie.
2. Dekoder (`control`) i `imm_gen` patrzą na `instr`, bank rejestrów czyta `rs1`, `rs2`.
3. ALU liczy wynik (albo adres dla load/store, albo cel dla `jalr`).
4. Load: LSU wybiera bajty ze słowa z pamięci danych. Store: LSU ustawia
   `wstrb`/`wdata`, a zapis nastąpi na zboczu.
5. Multiplekser `wb_sel` wybiera, co trafi do `rd`. Zapis nastąpi na zboczu.
6. Logika następnego PC wybiera `pc+4`, `pc+imm` albo `alu_y & ~1`. Też na zboczu.

**Wszystkie efekty jednej instrukcji (zapis rejestru, zapis pamięci, nowe PC)
dzieją się na tym samym zboczu zegara.** Dlatego ten procesor jest taki prosty.
Cena: okres zegara musi pomieścić całą drogę od PC przez pamięć instrukcji,
rejestry, ALU, pamięć danych aż do zapisu.

## 2. Przejście instrukcji przez ścieżkę

| Instrukcja | A | B | ALU | Pamięć | Do rd | Następne PC |
|---|---|---|---|---|---|---|
| `add rd, rs1, rs2` | rs1 | rs2 | {i[30],f3} | — | alu_y | pc+4 |
| `addi rd, rs1, imm` | rs1 | imm | {0,f3}* | — | alu_y | pc+4 |
| `lw rd, imm(rs1)` | rs1 | imm | ADD | czyt. | load_data | pc+4 |
| `sw rs2, imm(rs1)` | rs1 | imm | ADD | zapis rs2 | — | pc+4 |
| `beq rs1, rs2, off` | — | — | — | — | — | taken ? pc+imm : pc+4 |
| `jal rd, off` | — | — | — | — | pc+4 | pc+imm |
| `jalr rd, imm(rs1)` | rs1 | imm | ADD | — | pc+4 | alu_y & ~1 |
| `lui rd, imm` | 0 | imm | ADD | — | alu_y | pc+4 |
| `auipc rd, imm` | pc | imm | ADD | — | alu_y | pc+4 |

\* dla `srai`: {i[30], f3}.

## 3. Tabela sterowania

Wypełnij ją **na kartce** przed pisaniem `control.sv` (`x` = obojętne):

| opcode | reg_write | wb_sel | alu_a_sel | alu_b_imm | alu_op | mem_read | mem_write | branch | jump | jump_reg |
|---|---|---|---|---|---|---|---|---|---|---|
| OP (R) | | | | | | | | | | |
| OP-IMM | | | | | | | | | | |
| LOAD | | | | | | | | | | |
| STORE | | | | | | | | | | |
| BRANCH | | | | | | | | | | |
| JAL | | | | | | | | | | |
| JALR | | | | | | | | | | |
| LUI | | | | | | | | | | |
| AUIPC | | | | | | | | | | |
| FENCE/SYSTEM | | | | | | | | | | |

Test `tb_control` sprawdza dokładnie tę tabelę na 97 zakodowanych instrukcjach
i sygnalizuje różnice z nazwami pól.

## 4. Interfejs rdzenia (kontrakt z testbenchem)

```
module core (clk, rst,
             imem_addr → / ← imem_rdata,
             dmem_addr →, dmem_re →, ← dmem_rdata, dmem_wstrb →, dmem_wdata →,
             commit_valid →, commit_pc →, commit_instr →, commit_rd →, commit_rd_val →)
```

- Pamięć jest **jedna** (64 KiB), widziana przez dwa porty. Odczyt jest
  kombinacyjny, zapis następuje na zboczu, gdy `dmem_wstrb != 0`.
- `dmem_addr` to pełny adres bajtowy, pamięć sama bierze `addr[15:2]`.
  `dmem_rdata` to całe słowo, a wybór bajtów robi Twoje LSU.
- `dmem_re` jest informacyjny (testbench go nie potrzebuje, prawdziwa
  pamięć by potrzebowała).
- Reset synchroniczny, a po nim `pc = 0`.
- **Interfejs commit** służy wyłącznie do weryfikacji: w każdym takcie, w którym
  instrukcja się kończy, `commit_valid = 1` i opis tej instrukcji. Testbench
  zapisuje z niego ślad (`+trace=`) w formacie emulatora z modułu 04.
  `commit_rd = 0`, jeśli instrukcja nie zapisuje rejestru (wtedy w śladzie jest `-`).

Testbench pilnuje kilku rzeczy i od razu przerywa z komunikatem, gdy:
PC jest X po resecie, `commit_valid` jest X, następuje zapis pod adres X,
zapis pod nieobsługiwany adres, wykonanie słowa `0x00000000` (skok w pustą
pamięć), brak commitu przez 1000 taktów albo przekroczenie limitu cykli.

## 5. Jak debugować procesor

1. **Zawsze zaczynaj od najprostszego testu**, który nie przechodzi:
   `make prog P=01_smoke`.
2. **Ślad.** `make prog P=...` zapisuje `build/<P>.trace`. Porównaj go z
   emulatorem:
   ```bash
   make -C ../04-isa-emulator emu-test P=05_branch   # ślad wzorcowy
   python3 ../common/tools/tracecmp.py ../04-isa-emulator/build/05_branch.trace build/05_branch.trace
   ```
   Dostaniesz pierwszą różniącą się instrukcję z disasemblacją i podpowiedzią
   (inne PC = błąd skoku, inna wartość = błąd wykonania). W module 06 to
   porównanie będzie automatyczne (`make cosim`).
3. **Listing** `build/hex/<P>.lst` mapuje adresy na linie źródła.
4. **Przebiegi**: `make wave P=05_branch`. Dodaj `dut.pc`, `dut.instr` (albo
   `imem_rdata`), sygnały sterujące i `commit_*`. Format hex dla wektorów.
5. „FAIL: podtest N” oznacza, że w źródle testu jest `li gp, N` przed sprawdzeniem,
   które padło.

---

## Zadania

### 5.1 Dekoder (`rtl/control.sv`)
`make unit T=control`. Najczęstszy błąd to dla OP-IMM brać `instr[30]` do
`alu_op`. Wtedy `addi a0, a0, -1` (immediate z ustawionym bitem 30) liczy się
jak odejmowanie. Test zawiera takie przypadki.

### 5.2 LSU (`rtl/lsu.sv`)
`make unit T=lsu`. Rozrysuj sobie słowo 32-bitowe z czterema bajtami i zobacz,
gdzie trafia `sb` pod `addr[1:0] = 3`. Przesunięcie `dmem_rdata >> (8*addr[1:0])`
załatwia połowę roboty przy odczycie.

### 5.3 Rdzeń (`rtl/core.sv`)
Złóż ścieżkę danych z gotowych bloków. Moduły z 03 i 04 są dołączane z tamtych
katalogów (patrz `Makefile`), więc poprawka w `alu.sv` od razu działa też tutaj.

```bash
make progs                 # wszystkie 12 programów
make prog P=08_fib         # jeden, z wyjściem programu i śladem
make test                  # testy jednostkowe + programy
```
Programy, w kolejności trudności: smoke, ALU z immediate, ALU rejestr-rejestr,
lui/auipc, skoki warunkowe (także dalekie, >2 KiB), jal/jalr i stos,
load/store wszystkich szerokości, Fibonacci, sortowanie, rekurencja, „złośliwe”
zależności (dla potoku), MMIO (wypisuje napis).

Gdy `12_mmio` przejdzie, zobaczysz w terminalu tekst wypisany przez Twój procesor.

### 5.4 Pomiary
- `make synth T=core`: ile komórek ma Twój procesor? Jak to się ma do sumy
  ALU + regfile z modułu 03?
- CPI wynosi 1,000 (z definicji). W module 08 porównasz to z potokiem.

> **Uwaga o *longest topological path*:** pamięci są w testbenchu, poza modułem
> `core`, więc Yosys widzi dwie osobne ścieżki: PC → `imem_addr` oraz
> `imem_rdata` → … → `dmem_addr`, `dmem_rdata` → rejestry. Prawdziwy krytyczny
> takt procesora jednocyklowego to *suma*: odczyt imem + dekodowanie + rejestry +
> ALU + odczyt dmem + zapis. To właśnie motywacja potoku.

**Gotowe, gdy:** `make test` → 2 × PASS (unit) + 12 × PASS (programy),
`make lint` czysto.
