# Moduł 06 — Weryfikacja: co-symulacja, fuzzing, Verilator

**Cel:** przestać ufać „przeszło 12 testów”. W prawdziwych projektach
weryfikacja zajmuje więcej czasu niż projektowanie. Ten moduł nie ma nowego RTL:
uczysz się sprawdzać rdzeń z modułu 05, a później tymi samymi narzędziami
potok z modułu 08.

**Czas:** 1–2 wieczory.

---

## 1. Trzy poziomy testowania

1. **Testy kierowane** (directed): ręcznie napisane programy sprawdzające
   konkretne zachowania, czyli `common/sw/tests/*.S`. Dobre na start i na przypadki
   brzegowe, które znasz. Słabe na te, o których nie pomyślałeś.
2. **Co-symulacja z modelem referencyjnym**: ten sam program idzie przez
   emulator (moduł 04) i przez RTL, a porównujemy **każdą** wykonaną instrukcję
   (pc, słowo, zapisany rejestr, wartość). Błąd zostaje wykryty w miejscu, w którym
   powstał, a nie 500 instrukcji później, gdy program „coś” źle policzy.
3. **Testy losowe** (fuzzing, w branży „constrained random”): generator tworzy
   tysiące programów, których nikt by ręcznie nie napisał, a co-symulacja mówi,
   czy RTL zgadza się z modelem. Znajduje błędy, o których nie wiedziałeś, że
   mogą istnieć. Zwłaszcza w potoku: kombinacje zależności, skoków i loadów.

Tak samo weryfikuje się prawdziwe procesory. Na przykład otwarte rdzenie RISC-V
porównują ślad z modelem Spike albo Sail, a generatorem jest `riscv-dv`.

### Skąd model wie, co jest poprawne?
Nie wie. Emulator też może mieć błąd. Siła metody polega na tym, że dwie
**niezależne** implementacje (C i RTL, napisane różnymi technikami) rzadko mylą
się tak samo. Gdy się różnią, któraś ma błąd i trzeba sprawdzić w specyfikacji.

## 2. Ograniczenia porównania śladów

- Ślad obejmuje tylko zapisy do rejestrów. Błędny **store** wyjdzie dopiero przy
  późniejszym load z tego adresu. (Rozszerzenie: dodaj do interfejsu commit
  adres i daną zapisu.)
- Odczyt licznika cykli (MMIO `CYCLES`) z natury daje różne wartości w
  emulatorze i w RTL. Dlatego `cosim` pomija `12_mmio`, a ślady programów w C
  odczytujących `cycles()` rozjadą się w tym miejscu (moduł 07).
- Ślad RTL może być dłuższy niż wzorcowy, bo testbench pozwala potokowi
  dokończyć instrukcje po zapisie do TOHOST. `tracecmp` porównuje długość śladu
  wzorcowego.

## 3. Verilator

Icarus to klasyczny symulator zdarzeniowy: interpretuje opis i obsługuje 4
wartości (0/1/X/Z). Verilator **kompiluje** RTL do C++: symuluje 2 wartości,
myśli w cyklach zegara i jest zwykle 10–100× szybszy. Z tym samym
testbenchem (`--timing` obsługuje `#5` i `@(posedge)`) zmierzyłem na
rozwiązaniu wzorcowym: `10_recursion` w Icarusie ok. 0,55 s, w Verilatorze ok. 0,01 s.

Cena: Verilator nie widzi `X` (niezainicjowany sygnał to po prostu 0), więc
błędy inicjalizacji ukrywa. Dobra praktyka: debugować w Icarusie, a masowo
testować w Verilatorze.

```bash
make progs SIM=verilator      # pierwsza kompilacja trwa kilka sekund
make fuzz N=500 SIM=verilator
```

## 4. Mutacje: kto pilnuje strażnika?

Skąd wiadomo, że testy są dobre? Wstaw do rdzenia **celowy** błąd i sprawdź,
czy go wykryją. To się nazywa testowanie mutacyjne. Przy tworzeniu tego kursu
w ten sposób wyszło, że pierwotne testy nie wykrywały błędu w bicie 11
immediate'a skoku warunkowego (żaden skok nie był dłuższy niż 2 KiB). Stąd
„dalekie skoki” w `05_branch.S`.

---

## Zadania

Wszystkie polecenia uruchamiasz z tego katalogu. Domyślnie testowany jest
rdzeń z modułu 05. Z `CORE=08` testujesz potok z modułu 08.

### 6.1 Co-symulacja
```bash
make cosim
```
Wymaga działającego emulatora (moduł 04) i rdzenia (moduł 05). Jeśli coś się
rozjedzie, przeczytaj raport `tracecmp` i znajdź błąd. Rozjazd może być też
w emulatorze! Rozstrzyga specyfikacja (README modułu 04).

### 6.2 Fuzzing
```bash
make fuzz                      # 20 programów po 300 instrukcji
make fuzz N=300 LEN=600 SEED=1000
```
Przeczytaj `common/tools/rvgen.py` i jeden wygenerowany program
(`build/core05/fuzz/r1.S`). Odpowiedz sobie:
- jakich instrukcji i sytuacji generator **nie** tworzy? (dalekie skoki?
  pętle wstecz poza kontrolowanymi? dostępy do tego samego adresu tuż po sobie?)

### 6.3 Polowanie na mutanty
Wprowadzaj do swojego rdzenia (albo do modułów z 03–05) po jednym błędzie,
uruchamiaj `make -C ../05-single-cycle progs`, `make cosim`, `make fuzz` i notuj,
co wykryło błąd. Propozycje:
1. `sra` działa jak `srl`,
2. `lh` nie rozszerza znakiem,
3. zapis do `x0` nie jest ignorowany,
4. `jalr` nie zeruje bitu 0,
5. `sb` zawsze zapisuje bajt 0 słowa,
6. bit 11 B-immediate'a wzięty z `instr[31]` zamiast `instr[7]`,
7. `sltiu` porównuje ze znakiem.

**Zadanie właściwe:** dla mutanta, którego fuzzer nie wykrywa, rozszerz
`rvgen.py` tak, żeby wykrywał (np. o dalekie skoki: wstaw `.space` między
skokiem a celem). Po skończeniu cofnij mutację!

### 6.4 Pokrycie (coverage)
Napisz krótki skrypt (Python), który z plików `build/core05/fuzz/*.trace`
policzy, ile razy wykonała się każda instrukcja (disasembler: `from rvtool
import dis`). Czy wszystkie 37 instrukcji RV32I (bez fence/ecall/ebreak) wystąpiły? Czy `bgeu` był
choć raz *wykonany* (skok wzięty), a nie tylko *niewzięty*? Tak myśli się o
pokryciu funkcjonalnym: nie „ile testów”, tylko „które zachowania zostały
sprawdzone”.

### 6.5 Lint i synteza całego rdzenia
```bash
make lint
make synth T=core
```

**Gotowe, gdy:** `make cosim` → wszystko ZGODNE, `make fuzz N=200` → 0 różnic,
a fuzzer po Twojej zmianie wykrywa mutanta nr 6.
