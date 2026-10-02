# Moduł 00 — Narzędzia i pierwszy układ

**Cel:** zrozumieć, czym różni się opis sprzętu od programu, i opanować cykl pracy
*napisz → zasymuluj → obejrzyj przebiegi → zlintuj → zsyntezuj*.

**Czas:** 1 wieczór.

---

## 1. HDL to nie jest język programowania

W C piszesz **sekwencję kroków** dla procesora, który już istnieje. W Verilogu
opisujesz **układ**: zbiór bramek i przerzutników połączonych drutami. Wszystkie
działają *jednocześnie* i *bez przerwy*.

```systemverilog
assign y = a & b;     // to NIE jest "oblicz a&b i zapisz do y" —
                      // to jest bramka AND, której wyjście jest na stałe
                      // połączone z drutem y
```

Kod w Verilogu ma dwa życia:

| | Symulacja | Synteza |
|---|---|---|
| Narzędzie | Icarus Verilog (`iverilog` + `vvp`), Verilator | Yosys (a dalej nextpnr → FPGA) |
| Co robi | wykonuje opis jak program zdarzeniowy | zamienia opis na sieć bramek i przerzutników |
| Co akceptuje | prawie wszystko (`#5`, `$display`, pliki...) | tylko **syntezowalny podzbiór** |

Testbench (`tb/*.sv`) żyje tylko w symulacji i może używać wszystkiego.
Kod w `rtl/` musi być syntezowalny. W tym kursie każdy plik RTL możesz w
każdej chwili sprawdzić poleceniem `make synth T=nazwa_modułu`.

> **Pułapka dla programisty C:** kod, który się symuluje, wcale nie musi się
> syntezować do tego, co myślisz. Przykłady: pętla `for` zamienia się w N
> *kopii* sprzętu, a nie w N iteracji w czasie; `if` bez `else` w logice
> kombinacyjnej tworzy zatrzask (latch); `/` i `%` tworzą ogromny dzielnik.
> W razie wątpliwości zawsze możesz zapytać: „jak wyglądałby ten układ na schemacie?”.

## 2. Dwa rodzaje logiki

Każdy układ cyfrowy składa się z dwóch części:

**Logika kombinacyjna**: wyjście zależy *tylko* od bieżących wejść, nie ma pamięci.
Bramki, multipleksery, sumatory, dekodery.
```systemverilog
always_comb y = sel ? a : b;      // multiplekser
assign sum = a + b;               // sumator
```

**Logika sekwencyjna**: przerzutniki (flip-flopy) zapamiętują wartość na
zboczu zegara. To jest pamięć układu, czyli jego *stan*.
```systemverilog
always_ff @(posedge clk) q <= d;  // rejestr: na zboczu narastającym q := d
```

Prawie każdy układ synchroniczny wygląda tak:

```
          ┌──────────────┐        ┌──────────┐
 wejścia ─┤    logika    ├── d ──►│ rejestry ├──┬── q ──► wyjścia
       ┌─►│ kombinacyjna │        └────▲─────┘  │
       │  └──────────────┘             │clk     │
       └────────────────────────────────────────┘
                     (stan wraca do logiki)
```

Między zboczami zegara logika kombinacyjna „liczy” następny stan. Na zboczu
wszystkie rejestry naraz go zapamiętują. Okres zegara musi być dłuższy niż
najdłuższa ścieżka przez logikę kombinacyjną (o tym w module 02).

## 3. Anatomia modułu

Otwórz `rtl/counter.sv`:

```systemverilog
module counter #(
  parameter int WIDTH = 8           // parametr: stała ustalana przy tworzeniu instancji
) (
  input  logic             clk,
  input  logic             rst,
  input  logic             en,
  output logic [WIDTH-1:0] q        // wektor WIDTH bitów, bit 0 najmłodszy
);
  always_ff @(posedge clk) begin
    if (rst)     q <= '0;
    else if (en) q <= q + 1'b1;
  end
endmodule
```

- `logic`: typ SystemVerilog dla sygnałów, zastępuje stare `wire`/`reg`.
  W kursie używamy wyłącznie `logic`.
- `[WIDTH-1:0]`: zakres bitów. `q[0]` to bit najmłodszy, `q[WIDTH-1]` najstarszy.
- `1'b1`: literał o szerokości 1 bitu, w zapisie binarnym, o wartości 1.
  Format: `<szerokość>'<baza><wartość>`, np. `8'hFF`, `4'b1010`, `32'd100`.
- `'0`, `'1`: „same zera”, „same jedynki” w dowolnej szerokości.
- Reset jest **synchroniczny** (sprawdzany na zboczu) i **aktywny w stanie 1**.
  Tę konwencję trzymamy w całym kursie.

Instancja (czyli „wstawienie układu”) wygląda tak:
```systemverilog
counter #(.WIDTH(16)) u_cnt (.clk(clk), .rst(rst), .en(1'b1), .q(cnt_value));
counter #(.WIDTH(16)) u_cnt (.clk, .rst, .en(1'b1), .q(cnt_value)); // .clk = .clk(clk)
```

## 4. Anatomia testbencha

Otwórz `tb/tb_counter.sv`. Testbench to moduł bez portów, który:
1. tworzy sygnały i instancję testowanego układu (DUT),
2. generuje zegar: `always #5 clk = ~clk;` (okres 10 jednostek czasu),
3. w bloku `initial` podaje pobudzenia i sprawdza wyniki.

```systemverilog
rst = 1; en = 0;
@(negedge clk);              // czekaj na zbocze opadające
`CHECK_EQ(q, 8'd0, "po resecie")
```

**Dlaczego wejścia zmieniamy na zboczu opadającym?** Przerzutniki reagują na
zbocze narastające. Jeśli testbench zmieni wejście *dokładnie* w chwili zbocza
narastającego, to wynik zależy od kolejności zdarzeń w symulatorze, czyli mamy
wyścig (race). Zmiana w połowie okresu (`negedge`) eliminuje problem. Kursowe
testbenche zawsze tak robią.

Makra `CHECK_EQ` i `CHECK` oraz zadania `tb_start()` i `tb_finish()` pochodzą z
`common/tb/tb_common.svh`. `CHECK_EQ` porównuje operatorem `!==`, więc wartość
`X` też jest wykrywana jako błąd (o `X` poniżej).

## 5. Logika czterowartościowa: 0, 1, X, Z

Symulator zna cztery wartości bitu:
- `0`, `1` — wiadomo,
- `X` — **nieznana**: niezainicjowany przerzutnik, konflikt dwóch sterowników
  albo wynik operacji na `X`,
- `Z` — wysoka impedancja (nikt nie steruje drutem). W tym kursie się nie pojawia.

`X` jest Twoim przyjacielem. Gdy w przebiegach widzisz czerwone `X`, to znaczy,
że coś nie zostało zainicjowane albo przypisane. Prawdziwy sprzęt miałby tam
losowe 0 lub 1 i błąd ujawniłby się „czasem”. Symulacja pokazuje go od razu.

Uwaga: `==` z `X` daje `X` (czyli „fałsz” w `if`!), a `===` / `!==` porównują
dosłownie, łącznie z X. W testbenchach używaj `===`/`!==`. W RTL używaj `==`.

## 6. Ściąga poleceń

W każdym module (uruchamiaj z katalogu modułu):

| Polecenie | Co robi |
|---|---|
| `make test` | wszystkie testy modułu |
| `make unit T=updown` | jeden test jednostkowy |
| `make wave T=updown` | test + zapis przebiegów + GTKWave |
| `make lint` | Verilator: ostrzeżenia o podejrzanych konstrukcjach |
| `make synth T=updown` | Yosys: liczba bramek/przerzutników i najdłuższa ścieżka |
| `make clean` | usuwa `build/` |

### GTKWave w 60 sekund
1. Po lewej, w drzewku „SST”, kliknij `tb_updown`, potem `dut`.
2. Zaznacz sygnały na liście poniżej i kliknij **Append** (albo przeciągnij).
3. `Ctrl+Shift+F` (albo lupa z ramką): dopasuj widok do całego czasu.
4. Prawy klik na wektorze → *Data Format* → *Decimal* / *Hexadecimal*.
5. *File → Write Save File*: zapamiętuje układ sygnałów na następny raz.

---

## Zadania

### 0.1 Uruchom gotowy licznik
```bash
cd 00-start
make unit T=counter
make wave T=counter
```
W GTKWave dodaj `clk`, `rst`, `en`, `q`. Znajdź moment, w którym `en` spada do 0,
i sprawdź, że `q` się zatrzymuje. **Pytanie:** w którym dokładnie momencie
zmienia się `q`? Względem którego zbocza?

### 0.2 Licznik w górę/w dół (`rtl/updown.sv`)
Specyfikacja jest w komentarzu w pliku. Napisz:
- `always_ff` dla `q` (priorytety: `rst` > `load` > `en`),
- kombinacyjne wyjście `tc`.

```bash
make unit T=updown
```
Test porównuje Twój układ z modelem przez 500 losowych taktów. Gdy coś się nie
zgadza, wypisuje pierwsze 20 rozbieżności z czasem symulacji. Użyj tego czasu,
żeby znaleźć miejsce w GTKWave (`make wave T=updown`).

### 0.3 Pierwsza synteza
```bash
make synth T=counter
```
Yosys wypisze listę komórek, np. `$_SDFFE_PP0P_` (przerzutnik z synchronicznym
resetem do 0 i zezwoleniem, czyli dokładnie to, co opisałeś!) oraz bramki
sumatora. **Pytania:**
- Ile przerzutników ma licznik 8-bitowy? Czy to się zgadza z intuicją?
- Zmień w `counter.sv` domyślne `WIDTH = 8` na 32 i zsyntezuj ponownie.
  Jak rośnie liczba bramek? A najdłuższa ścieżka (*longest topological path*)?
  Dlaczego? (Podpowiedź: przeniesienie w dodawaniu.) Na koniec przywróć 8.

### 0.4 Lint
```bash
make lint
```
Verilator powinien powiedzieć `OK` dla obu modułów. Dla eksperymentu zmień w
`updown.sv` szerokość jakiegoś wyrażenia, np. `q <= q + 2'b01;` przy `WIDTH=4`
(to akurat jest poprawne, rozszerzy się) albo przypisz `q <= d[1:0];` i zobacz
ostrzeżenie `WIDTH`. Verilator to Twój „-Wall -Werror”.

**Gotowe, gdy:** `make test` pokazuje PASS dla `counter` i `updown`, a `make lint`
nie zgłasza ostrzeżeń.
