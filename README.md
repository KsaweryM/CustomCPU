# Kurs: własny procesor RISC-V w SystemVerilogu

Od bramek logicznych do 5-etapowego procesora potokowego RV32I, na którym
uruchamiasz programy skompilowane z C, zweryfikowanego przez co-symulację
z własnym emulatorem i fuzzing.

Kurs zakłada, że znasz C i niskopoziomowe programowanie (pamięć, wskaźniki,
asembler w zarysie, ABI). Nie zakłada znajomości HDL ani elektroniki.

---

## Mapa kursu

| # | Moduł | Co budujesz | Czas |
|---|---|---|---|
| 00 | [start](00-start/README.md) | narzędzia, licznik, pierwszy testbench | 1 wieczór |
| 01 | [kombinacyjna](01-kombinacyjna/README.md) | mux, enkoder, sumator, barrel shifter; szerokości, zatrzaski | 2 |
| 02 | [sekwencyjna](02-sekwencyjna/README.md) | rejestry, timing, pamięci, FSM, FIFO, nadajnik UART | 2–3 |
| 03 | [alu-regfile](03-alu-regfile/README.md) | ALU, bank rejestrów, komparator skoków | 1–2 |
| 04 | [isa-emulator](04-isa-emulator/README.md) | ISA RV32I na poziomie bitów, generator immediate'ów, **emulator w C** | 2–3 |
| 05 | [single-cycle](05-single-cycle/README.md) | dekoder, LSU, **procesor jednocyklowy** wykonujący prawdziwe programy | 3–4 |
| 06 | [weryfikacja](06-weryfikacja/README.md) | co-symulacja z emulatorem, fuzzing, Verilator, mutacje | 1–2 |
| 07 | [c-bare-metal](07-c-bare-metal/README.md) | crt0, linker script, `__mulsi3`: **C na Twoim CPU** | 1–2 |
| 08 | [pipeline](08-pipeline/README.md) | **5-etapowy potok**: forwarding, stalle, flush; pomiar CPI | 4–6 |
| 09 | [dalej](09-dalej/README.md) | rozszerzenie M, CSR/przerwania, FPGA, cache, weryfikacja formalna | ∞ |

Razem ok. 20–25 wieczorów. Moduły trzeba robić po kolei: 05 używa Twoich plików
z 03 i 04, 06 używa emulatora z 04, a 08 używa wszystkiego.

## Notatki (PDF)

Teoria ze wszystkich modułów, z diagramami (ścieżka danych, potok, hazardy,
formaty instrukcji), pytaniami kontrolnymi i ściągami, jest zebrana w
[`notatki/kurs.pdf`](notatki/kurs.pdf). Źródła LaTeX leżą w `notatki/`,
a PDF przebudujesz poleceniem `make -C notatki`.

## Jak pracować

Każdy moduł to katalog z:
- `README.md`: teoria i zadania. **Zacznij od niego.**
- `rtl/`: szkielety do uzupełnienia (komentarz `ZADANIE` + specyfikacja + `TODO`),
- `tb/`: gotowe testbenche (czytaj je, to też nauka),
- `Makefile`: wszystkie polecenia.

```bash
cd 01-kombinacyjna
make test               # wszystkie testy modułu: na starcie wszystko FAIL, i dobrze
make unit T=mux4        # jeden test
make wave T=mux4        # przebiegi w GTKWave
make lint               # Verilator: podejrzane konstrukcje
make synth T=adder      # Yosys: ile bramek, jaka najdłuższa ścieżka
```
W modułach z procesorem (05–08) dochodzą:
```bash
make progs              # 12 programów testowych na Twoim rdzeniu
make prog P=08_fib      # jeden program: wyjście + ślad wykonania
make wave P=08_fib      # przebiegi wykonania programu
make cosim              # porównanie śladu z emulatorem, instrukcja po instrukcji
make fuzz N=100         # losowe programy + porównanie z emulatorem
make progs SIM=verilator   # 10–100× szybsza symulacja
```

**Moduł jest zaliczony**, gdy `make test` pokazuje same PASS, a `make lint` nie
zgłasza ostrzeżeń. Każdy README kończy się sekcją „Gotowe, gdy:”.

**Rada:** zrób z katalogu kursu repozytorium git (`git init && git add -A &&
git commit -m start`) i commituj po każdym zadaniu. Przy potoku (moduł 08)
to bezcenne.

## Narzędzia

Zainstalowane na tej maszynie: Icarus Verilog 12, Verilator 5.020, Yosys 0.33,
GTKWave, Python 3, gcc, clang 18.

Do modułu 07 (C na procesorze) brakuje jeszcze linkera. Wystarczy jedno z dwóch:
```bash
sudo apt install lld                       # najprościej: clang już masz
sudo apt install gcc-riscv64-unknown-elf   # albo pełny toolchain GNU
```
Asembler do testów (`common/tools/rvtool.py`) jest częścią kursu, więc moduły
00–06 i 08 nie potrzebują żadnego toolchaina RISC-V.

## Struktura

```
kurs-cpu-verilog/
├── README.md               ← jesteś tutaj
├── 00-start/ … 09-dalej/   moduły
└── common/
    ├── rtl/rv32i_pkg.sv    stałe: opcode'y, kody ALU, mapa pamięci
    ├── tb/soc_tb.sv        "komputer" wokół rdzenia: pamięć, MMIO, ślad, timeouty
    ├── tb/tb_common.svh    makra CHECK_EQ / CHECK dla testbenchy
    ├── sw/tests/*.S        12 programów testowych w asemblerze
    ├── sw/tests_m/         test rozszerzenia M (moduł 09)
    ├── mk/rules.mk         wspólne reguły Makefile
    └── tools/
        ├── rvtool.py       asembler / disasembler RV32IM, bin2hex
        ├── tracecmp.py     porównanie śladów wykonania
        ├── rvgen.py        generator losowych programów (fuzzing)
        └── yosys_prep.py   obejście ograniczeń Yosysa 0.33 dla `make synth`
```

## Konwencje w kodzie

- SystemVerilog w podzbiorze obsługiwanym przez Icarus 12, Verilator i Yosys:
  `logic`, `always_comb`, `always_ff`, `typedef enum`, pakiety. Pliki `.sv`.
- `always_comb` + `=` dla logiki kombinacyjnej, `always_ff` + `<=` dla rejestrów.
  Bez wyjątków.
- Jeden zegar `clk`, reset **synchroniczny**, aktywny w stanie wysokim (`rst`).
- Stałe ISA zawsze z pakietu `rv32i_pkg` (`module x import rv32i_pkg::*; (...)`),
  nigdy „magiczne liczby”.

## Gdy utkniesz

1. Przeczytaj komunikat testu. Testbenche starają się powiedzieć, *co* jest nie tak.
2. `make wave ...` i obejrzyj sygnały wokół czasu z komunikatu błędu.
3. Dla procesora: `make cosim` znajdzie pierwszą instrukcję, która działa inaczej
   niż w emulatorze.
4. Zapytaj Claude'a: o podpowiedź (bez gotowca), o review Twojego modułu albo o
   wyjaśnienie fragmentu teorii. Przy pytaniu podaj komunikat testu i swój kod.

## O weryfikacji samego kursu

Każdy test w kursie został sprawdzony na rozwiązaniach wzorcowych (szkielety
oblewają testy, a rozwiązania je przechodzą). Programy testowe sprawdzono
testami mutacyjnymi: celowe błędy w rdzeniu muszą zostać wykryte. Asembler
koduje instrukcje bit w bit tak samo jak LLVM (sprawdzone na 400 losowych
instrukcjach). Rozwiązań wzorcowych celowo tu nie ma.
