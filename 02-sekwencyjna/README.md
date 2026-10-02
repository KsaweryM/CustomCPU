# Moduł 02 — Logika sekwencyjna i automaty stanów

**Cel:** rejestry, czas w układzie synchronicznym, pamięci i automaty skończone (FSM).
Procesor to w gruncie rzeczy wielki automat stanów: stanem są PC, rejestry i pamięć.

**Czas:** 2–3 wieczory.

---

## 1. Przerzutnik i `always_ff`

```systemverilog
always_ff @(posedge clk) q <= d;
```
Na każdym zboczu narastającym `clk` przerzutnik zapamiętuje `d`. Między zboczami
`q` się nie zmienia, niezależnie od tego, co robi `d`.

### Dlaczego `<=` (nieblokujące)?

Przypisanie nieblokujące oznacza: *oblicz prawą stronę teraz, a przypisz
dopiero na końcu kroku czasowego*. Wszystkie `<=` w całym układzie widzą więc
**stare** wartości, dokładnie tak, jak prawdziwe przerzutniki taktowane jednym
zegarem.

```systemverilog
always_ff @(posedge clk) begin   // rejestr przesuwny 3-bitowy
  a <= in;
  b <= a;                        // stare a
  c <= b;                        // stare b
end

always_ff @(posedge clk) begin   // zamiana wartości: działa!
  x <= y;
  y <= x;
end
```

Gdybyś użył `=`, `b = a` widziałoby *nowe* `a` i rejestr przesuwny zapadłby się w
jeden przerzutnik. Co gorsza, przy kilku blokach `always` wynik zależałby od
kolejności ich wykonania przez symulator. **Zasada bez wyjątków:** w
`always_ff` tylko `<=`.

### Rejestr z zezwoleniem i resetem
```systemverilog
always_ff @(posedge clk) begin
  if (rst)     q <= '0;      // reset synchroniczny: tylko na zboczu
  else if (en) q <= d;       // en = 0: q <= q (multiplekser przed przerzutnikiem)
end
```
Sprzętowo: `d_eff = rst ? 0 : (en ? d : q)`, a za tym zwykły przerzutnik.
Biblioteki FPGA/ASIC mają gotowe przerzutniki z wejściem enable (`$_SDFFE_`
z modułu 00).

**Reset synchroniczny czy asynchroniczny?** Asynchroniczny
(`always_ff @(posedge clk or posedge rst)`) działa bez zegara, ale komplikuje
analizę czasową przy zdejmowaniu resetu. W kursie używamy wyłącznie
synchronicznego. Na FPGA to standard.

**Wartość początkowa:** na FPGA przerzutniki dostają wartości z bitstreamu
(`initial` / `logic q = 0;` jest syntezowalne). W ASIC po włączeniu zasilania
jest losowo i tylko reset daje pewność. Dlatego wszystko, co musi mieć znaną
wartość (PC, stan FSM, bity `valid`), resetujemy jawnie.

## 2. Czas w układzie synchronicznym

```
     ┌─────┐   t_clk→q   ┌──────────────┐  t_comb   ┌─────┐
 ────┤ FF1 ├────────────►│    logika    ├──────────►│ FF2 │  (+ t_setup)
     └──▲──┘             └──────────────┘           └──▲──┘
  clk ──┴──────────────────────────────────────────────┘
```

Żeby FF2 poprawnie zapamiętał wynik, sygnał musi dojść przed zboczem z zapasem
*setup*:

**T_clk ≥ t_clk→q + t_comb(max) + t_setup**

Najdłuższa ścieżka kombinacyjna między dwoma rejestrami (**ścieżka krytyczna**)
wyznacza maksymalną częstotliwość. To jest „złożoność obliczeniowa” sprzętu:
nie liczba operacji, tylko głębokość logiki między rejestrami. Gdy ścieżka jest za
długa, można ją przeciąć rejestrem. Na tym polega **potokowanie** (moduł 08).

W symulacji RTL czasów nie ma: logika „liczy się w zerowym czasie”. O timing
dba synteza i place&route. My będziemy oglądać przybliżenie przez
`make synth` (*longest topological path*).

## 3. Pamięci

```systemverilog
logic [31:0] mem [0:255];               // 256 słów po 32 bity

always_ff @(posedge clk)
  if (we) mem[waddr] <= wdata;           // zapis synchroniczny

assign rdata = mem[raddr];               // odczyt asynchroniczny (kombinacyjny)
// albo:
always_ff @(posedge clk) rdata <= mem[raddr];   // odczyt synchroniczny
```

Ta różnica ma ogromne znaczenie praktyczne:
- **Odczyt synchroniczny** (dana jest dostępna takt później): tak działają
  bloki RAM w FPGA (BRAM) i pamięci SRAM. Są gęste i tanie.
- **Odczyt asynchroniczny**: wymaga zbudowania pamięci z przerzutników i
  multiplekserów albo z „rozproszonej” pamięci LUT. Jest drogi dla dużych pamięci.

W naszych procesorach pamięć w testbenchu ma odczyt asynchroniczny, bo to
upraszcza procesor jednocyklowy. Bank rejestrów (32×32 bity) jest mały i też ma
odczyt asynchroniczny. W module 03 zobaczysz w syntezie, ile to kosztuje.

## 4. Automaty skończone (FSM)

Automat to rejestr stanu i dwie funkcje kombinacyjne:
- **następny stan** = f(stan, wejścia),
- **wyjścia** = g(stan) w automacie **Moore'a** albo g(stan, wejścia) w automacie
  **Mealy'ego**.

Moore: wyjścia zmieniają się tylko po zboczu zegara, są „czyste” i opóźnione o takt.
Mealy: reaguje w tym samym takcie, ale wyjście zależy kombinacyjnie od wejść
(dłuższe ścieżki, ryzyko pętli kombinacyjnych między modułami).

Styl obowiązujący w kursie, czyli **dwa procesy**:

```systemverilog
typedef enum logic [1:0] {IDLE, RUN, DONE} state_t;
state_t state, next;

always_ff @(posedge clk)              // 1) tylko rejestr
  if (rst) state <= IDLE;
  else     state <= next;

always_comb begin                     // 2) tylko logika następnego stanu
  next = state;                       //    wartość domyślna: zostań
  case (state)
    IDLE: if (start) next = RUN;
    RUN:  if (cnt == 0) next = DONE;
    DONE: next = IDLE;
    default: next = IDLE;
  endcase
end

assign busy = (state == RUN);         // wyjście Moore'a
```

**Zanim napiszesz FSM, narysuj diagram stanów na kartce.** Serio. Każda strzałka
to jedna gałąź w `case`.

> **Icarus:** `next = cond ? S_A : S_B;` dla typu `enum` daje błąd
> „requires an explicit cast”. Pisz `if/else` albo `next = state_t'(cond ? S_A : S_B);`.

### FSM z licznikiem (datapath + control)
Większość prawdziwych układów (UART, kontroler pamięci, procesor wielocyklowy)
to mały automat sterujący plus „ścieżka danych”: liczniki, rejestry
przesuwne. Automat mówi „licz”, „przesuń”, „załaduj”, a ścieżka danych
odpowiada „doliczyłem do końca”. Zadanie 2.5 jest dokładnie takie.

## 5. Porównania z parametrami (ostrzeżenie WIDTHEXPAND)

`parameter int DEPTH = 8` ma 32 bity. Porównanie `count == DEPTH`, gdzie `count`
ma 4 bity, jest poprawne, ale Verilator zgłosi `WIDTHEXPAND`. Czysty idiom
to stała o właściwej szerokości:

```systemverilog
localparam int AW = $clog2(DEPTH);
localparam logic [AW:0] FULL = (AW+1)'(DEPTH);   // rzutowanie na AW+1 bitów
assign full = (count == FULL);
```

## 6. Sygnały z zewnątrz (na przyszłość, FPGA)

Przycisk albo linia RX z UART zmieniają się niezależnie od Twojego zegara.
Przerzutnik próbkujący taki sygnał może wpaść w **metastabilność**. Standardowe
lekarstwo to dwa przerzutniki pod rząd (synchronizator) przed jakąkolwiek
logiką. W symulacji tego nie zobaczysz, a na płytce objawia się „losowymi”
błędami raz na godzinę.

---

## Zadania

### 2.1 Detektor zbocza (`rtl/edge_detect.sv`)
Jeden przerzutnik i jedna bramka. Obejrzyj przebiegi (`make wave T=edge_detect`)
i zobacz, że `rise` jest kombinacyjny: pojawia się w chwili zmiany `in`, a znika
na zboczu zegara.

### 2.2 LFSR (`rtl/lfsr16.sv`)
Test sprawdza też, że okres to 65535: jeśli źle podłączysz odczepy, okres będzie
krótszy. **Pytanie:** dlaczego okres to 2¹⁶−1, a nie 2¹⁶? Jakiego stanu LFSR
nigdy nie osiągnie i co by się stało, gdyby w nim wystartował?

### 2.3 Detektor sekwencji 1011 (`rtl/seq_detect.sv`)
Automat Moore'a, 5 stanów, styl dwuprocesowy. Najtrudniejsza część to przejścia
przy nakładaniu się sekwencji (np. z którego stanu kontynuować po `1011`, gdy
przyjdzie `0`?). Test podaje ręcznie dobrane ciągi oraz 2000 losowych bitów.

### 2.4 FIFO (`rtl/fifo.sv`)
Kolejka cykliczna w sprzęcie. Klucz: wskaźniki mają `$clog2(DEPTH)+1` bitów,
a pamięć adresujesz młodszymi bitami. Wtedy:
- `count = wr_ptr - rd_ptr` (zawijanie modulo działa samo),
- `empty`: wskaźniki równe, `full`: różnią się tylko najstarszym bitem.

Test porównuje FIFO z kolejką `q[$]` z SystemVeriloga przez 3000 losowych taktów.
FIFO przydaje się wszędzie, gdzie dwie części układu pracują w różnym tempie.

### 2.5 Nadajnik UART (`rtl/uart_tx.sv`)
Test to „odbiornik programowy” w testbenchu (warto go przeczytać: `fork/join`,
taski z czekaniem na zbocza). Sprawdza bajty, bit stopu, czas trwania ramki i
ignorowanie `start` w trakcie nadawania. Ten moduł wykorzystasz w module 09, żeby
procesor na FPGA wysyłał tekst do komputera.

Po zrobieniu: `make synth T=uart_tx`. Ile przerzutników? Czy umiesz każdy z nich
przypisać do konkretnego rejestru w Twoim kodzie?

**Gotowe, gdy:** `make test` → 5 × PASS, `make lint` czysto.
