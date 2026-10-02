# Moduł 09 — Co dalej: projekty rozszerzające

Masz działający, zweryfikowany procesor RV32I w dwóch mikroarchitekturach,
emulator referencyjny, infrastrukturę testową i toolchain C. Poniższe projekty
są niezależne. Wybierz to, co Cię ciekawi. Każdy opisuje cel, kroki i sposób
weryfikacji. Rozwiązań tu nie ma, ale wszystkie narzędzia z kursu nadal działają.

---

## A. Rozszerzenie M (mnożenie i dzielenie): ~2 wieczory

**Cel:** `mul, mulh, mulhsu, mulhu, div, divu, rem, remu` w sprzęcie i
porównanie wydajności z programowym `__mulsi3` z modułu 07.

1. Emulator: dopisz case `f7 == 0x01` dla opcode `0x33`. Test:
   `make -C ../04-isa-emulator emu-test-m`. Uwaga na przypadki brzegowe
   (dzielenie przez zero, `INT_MIN / -1`), opisane w specyfikacji
   (*Unprivileged ISA*, rozdział „M”).
2. RTL, wersja prosta: `*` w ALU (1 takt; syntezator zbuduje mnożarkę, a
   `make synth` pokaże, ile to kosztuje!).
3. Dzielenie iteracyjne: 32 takty, potok musi czekać (stall z EX, aż
   dzielnik skończy). To dobre ćwiczenie z wielocyklowych jednostek wykonawczych.
4. Testy: assembluj `common/sw/tests_m/m_ext.S` (np. skopiuj go do
   `common/sw/tests/13_m_ext.S`), fuzzing `make fuzz FUZZ_FLAGS=--mext`,
   C z `make -C ../07-c-bare-metal ARCH=rv32im`, a potem porównaj cykle `bench`.

## B. CSR, wyjątki i przerwania: ~4–6 wieczorów

**Cel:** zrobić z rdzenia procesor, na którym da się uruchomić RTOS.

1. Zicsr: instrukcje `csrrw/csrrs/csrrc` (+ wersje z `i`) i rejestry
   `mcycle`, `minstret` (liczniki wydajności zamiast MMIO!), `mstatus`, `mtvec`,
   `mepc`, `mcause`, `mie`, `mip`.
2. Wyjątki: `ecall`, `ebreak`, nielegalna instrukcja (masz już sygnał `illegal`
   z dekodera!), niewyrównany dostęp. Skok do `mtvec`, zapis `mepc`/`mcause`,
   powrót przez `mret`.
3. W potoku: wyjątek musi być **precyzyjny**. Instrukcje starsze się kończą,
   młodsze są unieważniane. Najprościej obsługiwać wyjątek w jednym etapie (np. MEM).
4. Przerwanie od timera (`mtime`/`mtimecmp` jako MMIO w testbenchu).
5. Weryfikacja: emulator musi dostać to samo (to sporo pracy, ale bez tego
   co-symulacja nie zadziała). Alternatywa: porównanie ze Spike
   (oficjalny symulator RISC-V) w trybie `--log-commits`.

## C. Procesor na FPGA: ~3–5 wieczorów + płytka

**Cel:** program w C wypisuje tekst z Twojego procesora do terminala na
komputerze przez UART.

Płytki z w pełni otwartym toolchainem (Yosys + nextpnr):
- **iCEBreaker / iCESugar** (Lattice iCE40UP5K): najlepiej udokumentowane,
  `yosys synth_ice40` + `nextpnr-ice40` + `icepack`,
- **Tang Nano 9K / 20K** (Gowin): tanie, `yosys synth_gowin` + `nextpnr-himbaechel`
  (Apicula),
- **ULX3S / OrangeCrab** (Lattice ECP5): więcej zasobów, `nextpnr-ecp5`.

Co trzeba zmienić:
1. **Pamięć:** blokowy RAM w FPGA ma **odczyt synchroniczny**. Procesor
   jednocyklowy tego nie zniesie wprost. Opcje: odczyt na zboczu opadającym
   (szybki hack), wersja wielocyklowa albo potok z odczytem imem w IF (adres
   podany takt wcześniej, czyli PC „następny”).
2. **Program w pamięci:** `$readmemh` w `initial` jest syntezowalny dla BRAM.
3. **UART:** Twój `uart_tx` z modułu 02 jako urządzenie MMIO (rejestr
   danych + bit `busy` do odczytu). `putchar` w C czeka, aż `busy = 0`.
4. **Zegar i reset:** PLL albo dzielnik, reset z przycisku przez synchronizator
   (moduł 02, sekcja o sygnałach z zewnątrz).
5. **Timing:** `nextpnr` poda maksymalną częstotliwość. Porównaj procesor
   jednocyklowy z potokiem, bo to jest prawdziwa odpowiedź na pytanie z modułu 08.

## D. Pamięć z opóźnieniem i cache: ~4 wieczory

**Cel:** realistyczny interfejs pamięci zamiast pamięci „magicznej”, która
odpowiada w tym samym takcie.

1. Zmień interfejs na `req/valid/ready` (handshake). Testbench odpowiada po N
   taktach (parametr).
2. Potok musi umieć stać, gdy pamięć nie odpowiada (stall całego potoku).
3. Dodaj cache instrukcji: direct-mapped, linie 16 B. Zmierz hit rate na `bench`.

## E. Weryfikacja formalna: ~2–3 wieczory

**Cel:** udowodnić (a nie tylko przetestować), że rdzeń implementuje ISA.

- **riscv-formal** (YosysHQ) + SymbiYosys: zestaw sprawdzeń formalnych dla
  rdzeni RISC-V. Rdzeń wystawia interfejs **RVFI**, który jest rozszerzoną
  wersją Twojego `commit_*` (dochodzą m.in. wartości rs1/rs2, adres i dane
  pamięci, pc następnej instrukcji).
- Na początek prostsze: asercje SVA w potoku, np. „po stallu instrukcja w ID
  jest ta sama”, „bańka nigdy nie ma `mem_write`”.

## F. Oficjalne testy riscv-tests: ~1 wieczór

Repozytorium `riscv-software-src/riscv-tests` (`isa/rv32ui-p-*`) to oficjalny
zestaw testów zgodności. Używają tego samego protokołu TOHOST co my
(dlatego wybrałem właśnie taki!). Potrzebny toolchain GNU. Trzeba dostosować
`env/p/link.ld` do naszej mapy pamięci (start od 0, TOHOST pod
`0x1000_0000`) i zastąpić CSR-y w kodzie startowym (albo zrobić projekt B).

---

## Lektura

- **D. Harris, S. Harris — *Digital Design and Computer Architecture: RISC-V Edition*.**
  Rozdziały 5 (bloki), 7 (mikroarchitektura: jednocyklowy, wielocyklowy, potok)
  i 8 (pamięć, cache) to dokładnie ścieżka tego kursu, z innymi szczegółami.
- **D. Patterson, J. Hennessy — *Computer Organization and Design RISC-V Edition*.**
  Klasyka, rozdział 4 o potoku.
- **J. Hennessy, D. Patterson — *Computer Architecture: A Quantitative Approach*.**
  Następny poziom: OoO, predykcja, pamięć. Na później.
- **The RISC-V Instruction Set Manual, Volume I: Unprivileged ISA** (riscv.org).
  Czyta się zaskakująco dobrze, z uzasadnieniami decyzji projektowych.
- **Volume II: Privileged Architecture** dla projektu B.
- **Sutherland, Davidson, Flake — *SystemVerilog for Design*.** Język od strony RTL.

## Prawdziwe rdzenie do czytania (po skończeniu kursu!)

| Rdzeń | Co w nim ciekawego |
|---|---|
| **PicoRV32** (YosysHQ) | jeden plik, wielocyklowy, nastawiony na mały rozmiar |
| **SERV** | bit-serialny RV32I: 1 bit na takt, najmniejszy rdzeń RISC-V |
| **Ibex** (lowRISC) | 2–3 etapy, produkcyjna jakość, świetna dokumentacja weryfikacji |
| **VexRiscv** | konfigurowalny potok, pisany w SpinalHDL |
| **CVA6** | 64-bitowy, 6 etapów, uruchamia Linuksa |

Porównaj ich decyzje (gdzie rozstrzygają skoki, jak robią bank rejestrów,
jak obsługują pamięć) ze swoimi.
