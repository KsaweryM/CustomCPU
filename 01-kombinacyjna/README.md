# Moduł 01 — Logika kombinacyjna

**Cel:** pisać logikę kombinacyjną świadomie, czyli wiedzieć, jaki sprzęt powstanie
z każdej linii, i nie dać się złapać na szerokości wyrażeń ani zatrzaski.

**Czas:** 2 wieczory.

---

## 1. `assign` i `always_comb`

Oba opisują logikę kombinacyjną:

```systemverilog
assign y = sel ? a : b;

always_comb begin
  if (sel) y = a;
  else     y = b;
end
```

W `always_comb` używasz przypisania **blokującego** `=`. Wewnątrz bloku działa
ono jak w C: kolejne linie widzą wyniki poprzednich. Dzięki temu można pisać
„krok po kroku”, ale pamiętaj, że to wszystko jest *jedną* siecią bramek, która
liczy się „natychmiast”:

```systemverilog
always_comb begin
  t = a ^ b;        // t to tylko nazwa dla drutu pośredniego
  y = t & c;
end
```

Zasada w kursie: **`always_comb` i `=` dla logiki kombinacyjnej, `always_ff` i
`<=` dla rejestrów.** Nie mieszaj ich. `always_comb` dodatkowo pozwala narzędziom
sprawdzić, że naprawdę opisałeś logikę kombinacyjną (patrz zatrzaski niżej).

## 2. Wektory: wycinanie, sklejanie, powielanie

```systemverilog
logic [31:0] x;
x[7:0]              // najmłodszy bajt
x[31]               // bit znaku
x[8*i +: 8]         // bajt i: 8 bitów od pozycji 8*i w górę (i może być zmienną)
{a, b}              // sklejenie: a na starszych bitach
{4{b}}              // b powtórzone 4 razy
{{20{x[31]}}, x[31:20]}   // rozszerzenie znakiem 12 -> 32 bity (zobaczysz to w module 04!)
```

Sklejenie może też stać po lewej stronie:
`{cout, sum} = a + b;` daje 33-bitowy wynik z przeniesieniem.

## 3. Szerokości wyrażeń: najczęstsze źródło błędów

W C typ wyrażenia wynika z typów argumentów. W Verilogu **szerokość obliczeń
zależy też od lewej strony przypisania**:

```systemverilog
logic [7:0] a, b;
logic [7:0] s8;
logic [8:0] s9;
s8 = a + b;   // liczone na 8 bitach: przeniesienie ginie
s9 = a + b;   // liczone na 9 bitach: przeniesienie jest w s9[8]
```

Reguły w skrócie:
- Wyrażenie arytmetyczne liczy się w szerokości **max(szerokości operandów,
  szerokość lewej strony)**. Węższe operandy są rozszerzane.
- Liczba bez rozmiaru (`5`, `100`) ma 32 bity i jest *signed*. `1'b1` ma 1 bit.
- Porównania (`<`, `==`) dają 1 bit, ale operandy *między sobą* są wyrównywane.
- **Znak:** jeśli którykolwiek operand jest unsigned, *całe* wyrażenie jest
  unsigned. `logic` jest domyślnie unsigned. Żeby porównać ze znakiem:
  `$signed(a) < $signed(b)`.
- `>>` wsuwa zera, a `>>>` powiela bit znaku, **ale tylko gdy lewy operand jest
  signed**: `$signed(a) >>> n`. Samo `a >>> n` na unsigned to zwykłe `>>`!

Verilator (`make lint`) ostrzega o niejawnym obcinaniu i rozszerzaniu
(`WIDTHTRUNC`, `WIDTHEXPAND`). Traktuj te ostrzeżenia poważnie.

## 4. Jaki sprzęt powstaje

| Konstrukcja | Sprzęt | Koszt |
|---|---|---|
| `& \| ^ ~` | bramki, po jednej na bit | tani, 1 poziom logiki |
| `c ? a : b`, `if/else` | multiplekser 2:1 | tani |
| `case` na N wartości | multiplekser N:1 (drzewo, log₂N poziomów) | umiarkowany |
| `a + b`, `a - b` | sumator | średni; w prostej formie liniowy w liczbie bitów |
| `a == b` | XOR-y + drzewo OR | tani |
| `a < b` | odejmowanie (przeniesienie) | jak sumator |
| `a << b` (b zmienne) | przesuwnik: log₂N warstw multiplekserów | spory |
| `a * b` | macierz sumatorów | **drogi** |
| `a / b`, `a % b` | **bardzo drogi**: nie pisz tego w RTL, chyba że przez stałą potęgę 2 |

**Ścieżka krytyczna:** sygnał musi przejść przez najdłuższy łańcuch bramek w
jednym takcie zegara. Im dłuższy łańcuch, tym niższa maksymalna częstotliwość.
`make synth` pokazuje to jako *longest topological path*: liczbę bramek na
najdłuższej drodze. To przybliżenie, bo prawdziwe opóźnienia zależą od
technologii, ale dobrze oddaje trendy.

## 5. `if` vs `case` i priorytety

```systemverilog
always_comb begin            // łańcuch priorytetów: a wygrywa z b, b z c
  if (a)      y = 1;
  else if (b) y = 2;
  else if (c) y = 3;
  else        y = 0;
end
```
Kolejne `else if` dają kaskadę multiplekserów. Gdy warunki się wykluczają
(np. różne wartości jednego sygnału), `case` lepiej oddaje intencję.

## 6. Zatrzaski (latch): błąd nr 1 w logice kombinacyjnej

```systemverilog
always_comb begin
  if (en) y = a;    // a gdy en == 0? y ma "pamiętać" starą wartość!
end
```

Skoro `y` ma pamiętać wartość, gdy `en = 0`, syntezator musi wstawić element
pamiętający, czyli zatrzask sterowany poziomem. W układach synchronicznych to
prawie zawsze błąd: psuje analizę czasową i daje układ, który w symulacji
działa inaczej niż na krzemie.

**Lekarstwo:** każda zmienna przypisywana w `always_comb` musi dostać wartość
na *każdej* ścieżce. Najprościej przez przypisanie domyślne na początku:

```systemverilog
always_comb begin
  y = '0;           // wartość domyślna
  if (en) y = a;
end
```

To samo dotyczy `case` bez `default`, gdy nie wszystkie wartości są pokryte.

## 7. Pętle `for` i `generate`: kopiowanie sprzętu

```systemverilog
always_comb begin
  parity = 1'b0;
  for (int i = 0; i < 32; i++)
    parity = parity ^ x[i];        // 31 bramek XOR połączonych łańcuchem
end
```
Pętla jest **rozwijana podczas syntezy**. Nie ma tu żadnego licznika ani
iteracji w czasie, tylko 32 kopie logiki. Liczba iteracji musi być stała.

Do powielania *instancji* modułów służy `generate`:
```systemverilog
genvar i;
generate
  for (i = 0; i < WIDTH; i++) begin : g_fa      // etykieta bloku jest wymagana
    full_adder fa (.a(a[i]), .b(b[i]), .cin(c[i]), .s(sum[i]), .cout(c[i+1]));
  end
endgenerate
```

## 8. Znane ograniczenia Icarus Verilog 12

Icarus (nasz symulator) nie obsługuje całego SystemVeriloga. W RTL rzadko to
przeszkadza, ale warto wiedzieć:
- brak `break`/`continue` w pętlach,
- brak inicjalizacji całej tablicy w deklaracji: `logic [7:0] t [4] = '{...}`,
- `unique case` / `priority case` są akceptowane, ale ignorowane,
- komunikat `sorry: constant selects in always_* processes...` to tylko
  ostrzeżenie i można go zignorować (Makefile go ukrywa).

---

## Zadania

Wszystkie testy: `make test`. Pojedynczy: `make unit T=nazwa`.

### 1.1 Multiplekser (`rtl/mux4.sv`)
Dwie wersje (opis w pliku). Test sprawdza instancje 8- i 16-bitową, czyli też to,
czy parametr działa.

### 1.2 Enkoder priorytetowy (`rtl/prio_enc.sv`)
Użyj pętli `for` w `always_comb`. **Pytanie:** pętla idąca od bitu 0 do 7,
gdzie każde trafienie nadpisuje `idx`, daje „najstarszy wygrywa”. Dlaczego?
Narysuj, jaki łańcuch multiplekserów z tego powstaje.

### 1.3 Sumator ripple-carry (`rtl/adder.sv`)
Najpierw `full_adder` z samych bramek, potem `adder` przez `generate`.
Test sprawdza **wszystkie** kombinacje dla 8 bitów (2¹⁷ przypadków) i losowe dla 32.

Potem ćwiczenie z syntezą:
```bash
make synth T=adder
```
Zanotuj liczbę komórek i najdłuższą ścieżkę. Potem tymczasowo zastąp ciało
`adder` jedną linią `assign {cout, sum} = a + b + cin;` i porównaj.
Yosys bez biblioteki technologicznej robi z `+` też ripple-carry, więc wyniki
będą podobne. Na prawdziwym FPGA `+` trafia na dedykowane łańcuchy przeniesień
(carry chain) i jest wielokrotnie szybsze niż sumator z LUT-ów. Wniosek:
**pisz `+` i pozwól narzędziom wybrać implementację**, a ręcznie składaj
tylko wtedy, gdy wiesz, po co.

*Dla chętnych:* przeczytaj o sumatorze carry-lookahead albo Kogge-Stone (Harris &
Harris, rozdz. 5.2) i zastanów się, jak długość ścieżki zależy od liczby bitów:
O(n) dla ripple-carry, O(log n) dla Kogge-Stone.

### 1.4 Barrel shifter (`rtl/shifter.sv`)
Pięć warstw multiplekserów: warstwa k przesuwa o 2ᵏ, gdy `shamt[k] = 1`.
Bez operatorów przesunięcia. Odwracanie bitów zrób funkcją z pętlą `for`
albo blokiem `generate`.

**Pytanie:** ile multiplekserów 2:1 ma Twój przesuwnik (bez odwracania)?
Porównaj z `make synth T=shifter`. Ten układ pojawi się w ALU w module 03.

### 1.5 Polowanie na zatrzask (`rtl/hex7seg.sv`)
Kod ma dwa błędy prowadzące do zatrzasku. Zanim cokolwiek poprawisz, uruchom:
```bash
make lint            # Verilator: co widzi?
make synth T=hex7seg # Yosys: co mówi?
make unit T=hex7seg  # test: co wykrywa?
```
Zwróć uwagę, że lint znajduje tylko jeden z dwóch błędów. Potem popraw kod i
dokończ tablicę A–F.

**Gotowe, gdy:** `make test` → 5 × PASS, `make lint` → wszystko OK.
