# TODO: rozszerzenia po kursie

Pomysły na dalsze projekty, mniej więcej od najprostszych.
Proponowana kolejność: **liczniki wydajności → predykcja skoków → rozszerzenie M →
FPGA → przerwania → RTOS**. Każdy krok buduje na poprzednim i daje mierzalny efekt.

## Krótkie projekty (1–3 wieczory)

- [ ] **Rozszerzenie M:** mnożenie w jednym takcie, potem dzielnik iteracyjny,
  który wstrzymuje potok. Test już jest (`common/sw/tests_m/m_ext.S`),
  fuzzer: `make fuzz FUZZ_FLAGS=--mext`. Porównać cykle `bench` (`ARCH=rv32im`).
- [ ] **Liczniki wydajności** (CSR `mcycle`, `minstret` + własne): liczniki
  wziętych skoków, stalli load-use i flushy. Mały wysiłek, a potem każda
  optymalizacja potoku ma twarde liczby.
- [ ] **Predykcja skoków:** najpierw statyczna (skoki wstecz zakładamy jako
  wzięte), potem tablica 2-bitowych liczników + BTB. Cel: CPI na `bench`
  z ok. 1,3 bliżej 1,1.
- [ ] **Rozszerzenie B (Zba/Zbb):** `clz`, `ctz`, `cpop`, `min/max`, `andn`,
  `sh1add`… Łatwe w ALU, clang ich używa (`-march=rv32i_zba_zbb`), więc widać
  zmianę w wygenerowanym kodzie.

## Średnie (tydzień)

- [ ] **Rozszerzenie C (instrukcje 16-bitowe):** kod mniejszy o ok. 25–30%, ale
  instrukcje przestają być wyrównane do 4 bajtów. Przebudować IF tak, żeby
  składał instrukcję z dwóch połówek słowa (prawdziwy front-end procesora).
- [ ] **Wyjątki i przerwania** (Zicsr, `mtvec`, `mepc`, `mcause`, `mret`):
  wyjątki precyzyjne w potoku. Bez tego nie ma systemu operacyjnego.
- [ ] **Cache i pamięć z opóźnieniem:** interfejs `valid/ready`, cache
  instrukcji i danych, pomiar trafień na `bench`. Wąskim gardłem okaże się
  pamięć, nie ALU.
- [ ] **Procesor na FPGA:** Tang Nano 9K (ok. 100 zł) albo iCEBreaker.
  `uart_tx` z modułu 02 jako MMIO, BRAM z odczytem synchronicznym, `nextpnr`
  poda prawdziwe fmax, czyli uczciwe porównanie procesora jednocyklowego z
  potokiem.

## Duże (miesiąc i więcej)

- [ ] **RTOS (FreeRTOS albo Zephyr):** wymaga przerwań timera i CSR. Procesor
  przełącza zadania.
- [ ] **Superskalar 2-drożny w kolejności (in-order):** dwie instrukcje na
  takt, wykrywanie zależności między nimi, bank rejestrów z 4 portami odczytu.
- [ ] **Wykonanie poza kolejnością (OoO):** Tomasulo, czyli zmiana nazw
  rejestrów, ROB i kolejki rezerwacji. Najpierw przeczytać Hennessy'ego i
  Pattersona (*Computer Architecture: A Quantitative Approach*).
- [ ] **Uprzywilejowanie i MMU (Sv32):** tryby M/S/U, stronicowanie, TLB.
  Na końcu tej drogi: Linux (por. „Linux on LiteX-VexRiscv”).
- [ ] **Weryfikacja formalna (riscv-formal + SymbiYosys):** interfejs
  `commit_*` to już połowa RVFI. Dowód zgodności z ISA znajduje błędy, których
  fuzzer nie trafi.

## Z boku

- [ ] **Wielordzeniowość:** dwa rdzenie, wspólna pamięć, instrukcje atomowe
  (rozszerzenie A: `lr/sc`, `amoadd`), spójność cache.
- [ ] **Własna instrukcja (custom opcode):** np. `crc32` albo krok AES w jednej
  instrukcji, wywoływana z C przez wstawkę asemblerową. Zmierzyć przyspieszenie
  na `bench`.
- [ ] **Ten sam potok w innym HDL:** Chisel, Amaranth (Python) albo SpinalHDL,
  dla porównania z SystemVerilogiem.

---

# Wybrane: rozpisane dokładniej

Zależności między projektami:

```
liczniki/CSR ──► wyjątki i przerwania ──► tryb U ──► PMP
      │
      └────────► rozszerzenie F (potrzebuje CSR fcsr)
rozszerzenie M ─► rozszerzenie wektorowe (Zve32x)
uart_tx (moduł 02) ─► UART RX ─► monitor w C ─► VGA ─► gra   (najpierw w symulacji, potem FPGA)
```

## Cały komputer: ekran, klawiatura, pamięć masowa

Cel: samodzielny komputer w stylu lat 80. Po włączeniu wita Cię monitor,
wpisujesz polecenia, uruchamiasz programy, a na ekranie działa gra.
**Wszystko da się zrobić najpierw w symulacji.** FPGA jest potrzebne dopiero
na końcu.

- [ ] **UART RX:** odbiornik do pary z `uart_tx` (próbkowanie w połowie bitu,
  synchronizator wejścia, FIFO z modułu 02 na odebrane bajty). MMIO: rejestr
  danych + bit „są dane”. Test: testbench nadaje bajty, a program w C odsyła
  je z powrotem (echo).
- [ ] **Magistrala i dekoder adresów:** porządna mapa pamięci zamiast `if`-ów
  w testbenchu (RAM, ROM, UART, VGA, timer jako osobne moduły), np. Wishbone.
- [ ] **Boot ROM + ładowanie programu przez UART:** ROM z małym bootloaderem
  (np. protokół „długość + bajty + suma kontrolna”). Program wysyłasz
  skryptem w Pythonie z PC. Koniec z przebudową bitstreamu dla każdego programu.
- [ ] **Monitor w C:** `d <adr>` (zrzut pamięci), `w <adr> <wartość>`,
  `g <adr>` (skok), `l` (wczytaj program), `r` (rejestry). Pierwszy
  „system operacyjny”.
- [ ] **Wyjście VGA (tryb tekstowy):** 640×480 przy 25 MHz, 80×30 znaków,
  pamięć znaków (dual-port: procesor pisze, sterownik VGA czyta), font 8×16
  w ROM, opcjonalnie kolory. **Test w symulacji:** testbench zbiera piksele
  jednej klatki i zapisuje plik `.ppm`, czyli „zrzut ekranu” z symulacji.
- [ ] **Klawiatura PS/2** (albo na początek po prostu UART RX z PC): dekoder
  scancode'ów, mapowanie na ASCII, bufor FIFO.
- [ ] **Karta SD lub flash SPI:** kontroler SPI (MMIO), sterownik w C,
  wczytywanie programów z karty. Opcjonalnie prosty system plików (np. FAT
  tylko do odczytu).
- [ ] **Timer + przerwania** (wymaga projektu „wyjątki i przerwania”): stałe
  tempo gry niezależne od CPI.
- [ ] **Gra:** Snake albo Tetris w C, tryb tekstowy, sterowanie z klawiatury.
- [ ] **FPGA:** płytka z wyjściem HDMI/VGA (np. Tang Nano 9K/20K z HDMI,
  ULX3S). HDMI = VGA + enkoder TMDS (osobny ciekawy moduł).

## Rozszerzenie F (liczby zmiennoprzecinkowe, IEEE 754)

Cel: `float` w C liczony sprzętowo. To najlepszy trening weryfikacji w całej
liście, bo IEEE 754 ma ogrom przypadków brzegowych.

- [ ] **Stan architektoniczny:** 32 rejestry `f0..f31`, CSR `fcsr`
  (`frm`: tryb zaokrąglania, `fflags`: flagi NV/DZ/OF/UF/NX).
  Wymaga obsługi CSR.
- [ ] **Najpierw proste instrukcje:** `flw/fsw`, `fmv.x.w/fmv.w.x`, `fsgnj*`
  (znak), `fclass.s`, porównania `feq/flt/fle`, `fmin/fmax`. Nie wymagają
  zaokrąglania.
- [ ] **Konwersje:** `fcvt.w.s`, `fcvt.wu.s`, `fcvt.s.w`, `fcvt.s.wu`.
  Pierwsze zaokrąglanie i nasycanie przy przepełnieniu.
- [ ] **Dodawanie/odejmowanie:** wyrównanie wykładników, bity guard/round/sticky,
  normalizacja (zliczanie wiodących zer: przyda się `clz` z Zbb!), 5 trybów
  zaokrąglania, denormale, ±0, ±∞, NaN (kanoniczny NaN w RISC-V).
- [ ] **Mnożenie i FMA:** `fmul.s`, potem `fmadd/fmsub/fnmadd/fnmsub` (jedno
  zaokrąglenie na końcu, więc nie da się złożyć z `fmul` + `fadd`).
- [ ] **Dzielenie i pierwiastek:** iteracyjnie (cyfra po cyfrze albo
  Newton-Raphson), z wstrzymaniem potoku jak dzielnik całkowity.
- [ ] **Weryfikacja:**
  - model referencyjny w emulatorze przez **Berkeley SoftFloat** (bit-exact
    z IEEE, łącznie z flagami), a nie przez `float` hosta;
  - wektory z **TestFloat** (`testfloat_gen`), czyli miliony przypadków
    brzegowych na operację;
  - fuzzer rozszerzony o instrukcje F, ślad z rejestrami `f*` i `fflags`.
- [ ] **C:** `-march=rv32if -mabi=ilp32f`. Porównać `bench` z
  macierzami na `float` (programowo przez `__addsf3` vs sprzętowo).

## Rozszerzenie wektorowe (podzbiór RVV 1.0: profil Zve32x)

Cel: jedna instrukcja przetwarza wiele elementów. Pełne RVV jest ogromne, ale
profil **Zve32x** (elementy do 32 bitów, bez float) to oficjalny,
„wbudowany” podzbiór, idealny na start.

- [ ] **Stan:** 32 rejestry wektorowe `v0..v31` (np. VLEN = 128 bitów, czyli
  4 × 32 b), CSR `vl`, `vtype`, `vstart`.
- [ ] **`vsetvli`:** serce RVV, programowe „ile elementów naraz”
  (strip-mining). Najpierw tylko SEW = 32, LMUL = 1.
- [ ] **Pamięć:** `vle32.v` / `vse32.v` (sekwencyjne), potem z krokiem
  (`vlse32`) i indeksowane (gather/scatter).
- [ ] **Arytmetyka:** `vadd`, `vsub`, `vmul`, `vmacc` (mnożenie z akumulacją),
  logiczne, przesunięcia, porównania z maską `v0`.
- [ ] **Redukcje:** `vredsum` (suma elementów do skalara).
- [ ] **Mikroarchitektura:** najpierw „element na takt” (prosto, potok czeka),
  potem kilka torów (lanes) równolegle. Bank rejestrów wektorowych to
  świetne ćwiczenie z pamięci wieloportowych.
- [ ] **Weryfikacja:** model w emulatorze, ślad z zapisami do `v*`, fuzzer
  z losowymi `vl` (szczególnie ogony, gdy liczba elementów nie dzieli się
  przez VLEN).
- [ ] **Benchmark:** mnożenie macierzy, `memcpy`, suma tablicy, ręcznie
  w asemblerze, a potem przez intrinsics RVV w clangu
  (`-march=rv32i_zve32x`). Mierzyć przyspieszenie względem wersji skalarnej.

## PMP (Physical Memory Protection)

Cel: ochrona pamięci bez MMU. Kod w trybie U nie może czytać ani pisać tam,
gdzie nie pozwolono, a próba kończy się wyjątkiem. Tak chroni się firmware
w mikrokontrolerach i jest to fundament np. dla izolacji zadań w RTOS-ie.

- [ ] **Wymagania:** CSR + wyjątki (projekt „wyjątki i przerwania”) oraz
  **tryb U**: `mstatus.MPP`, `mret` przełączający do U, `ecall` z U do M.
- [ ] **CSR PMP:** `pmpcfg0..3` (po 4 regiony, bity R/W/X/A/L), `pmpaddr0..15`.
  Na start 4–8 regionów.
- [ ] **Tryby dopasowania adresu:** TOR (zakres między dwoma `pmpaddr`), NA4,
  NAPOT (region o rozmiarze potęgi 2, kodowany jedynkami na końcu adresu).
- [ ] **Sprawdzanie w sprzęcie:** dla każdego dostępu (pobranie instrukcji,
  load, store) znajdź pierwszy pasujący region (priorytet od najniższego
  numeru) i sprawdź uprawnienia. W potoku: IF dla instrukcji, MEM dla danych.
- [ ] **Wyjątki:** instruction/load/store access fault (`mcause` = 1, 5, 7),
  w `mtval` adres, który nie przeszedł. Bit L (lock) blokuje region także dla
  trybu M.
- [ ] **Testy:** programy, które ustawiają PMP w trybie M, przechodzą do U
  i celowo naruszają ochronę. Handler w M sprawdza `mcause`/`mtval` i zgłasza
  PASS. Przypadki brzegowe: granice regionów, nakładające się regiony, NAPOT
  o różnych rozmiarach, bit L.
- [ ] **Demo:** dwa „zadania” w trybie U, każde widzi tylko swoją pamięć,
  a jądro w M przełącza między nimi (z timerem) i przestawia PMP.

---
Szczegóły części projektów (M, CSR, FPGA, cache, formalna, riscv-tests):
`09-dalej/README.md` i rozdział 9 w `notatki/kurs.pdf`.
