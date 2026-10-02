# Moduł 08 — Procesor potokowy (5 etapów)

**Cel:** przerobić procesor jednocyklowy na klasyczny 5-etapowy potok RISC,
z obsługą wszystkich hazardów, i zmierzyć, co to dało.
To najtrudniejszy i najciekawszy moduł kursu.

**Czas:** 4–6 wieczorów.

---

## 1. Po co potok?

Czas wykonania programu („żelazne prawo” wydajności procesora):

**czas = liczba instrukcji × CPI × okres zegara**

Procesor jednocyklowy ma CPI = 1, ale bardzo długi okres zegara, bo w jednym
takcie mieszczą się: odczyt pamięci instrukcji, dekodowanie, rejestry, ALU,
odczyt pamięci danych i zapis. Potok tnie tę drogę rejestrami na 5 krótszych
kawałków. Każda instrukcja nadal potrzebuje 5 etapów (opóźnienie się nie
zmienia), ale **w każdym takcie kończy się jedna instrukcja**, a takt może być
~3–5× krótszy.

```
takt:        1    2    3    4    5    6    7    8
add x1,..   IF   ID   EX   MEM  WB
sub x2,..        IF   ID   EX   MEM  WB
lw  x3,..             IF   ID   EX   MEM  WB
beq ..                     IF   ID   EX   MEM  WB
```

Cena: instrukcje „zachodzą” na siebie i zależności między nimi trzeba obsłużyć
sprzętowo. To są **hazardy**.

## 2. Etapy

| Etap | Co robi | Rejestr na końcu etapu |
|---|---|---|
| **IF** | `imem_addr = pc`, pobranie instrukcji, `pc += 4` | IF/ID: `d_valid, d_pc, d_instr` |
| **ID** | dekoder, immediate, odczyt rejestrów, wykrycie load-use | ID/EX: sygnały sterujące, `rs1_val`, `rs2_val`, `imm`, numery rs1/rs2/rd |
| **EX** | forwarding, ALU, branch_cmp, cel skoku → **redirect** | EX/MEM: wynik, dana do store, rd |
| **MEM** | LSU + pamięć danych | MEM/WB: wartość do zapisu, rd |
| **WB** | zapis do banku rejestrów, **commit** | — |

```
      ┌────┐  ┌───────┐      ┌───────┐      ┌────────┐      ┌────────┐
 pc ─►│ IF ├─►│ IF/ID ├─ ID ─►│ ID/EX ├─ EX ─►│ EX/MEM ├─ MEM─►│ MEM/WB ├─ WB ─┐
      └─▲──┘  └───────┘      └───────┘   │   └────────┘      └────────┘      │
        └──────── redirect (skok wzięty) ─┘                                   │
                  regfile ◄──────────────────────── zapis rd ─────────────────┘
```

**Konwencje** (zgodne ze szkieletem): sygnał z prefiksem `d_` żyje w ID, `e_` w
EX, `m_` w MEM, `w_` w WB. Każdy etap ma bit `*_valid`. **Bańka** (bubble) to
etap z `valid = 0` i wyzerowanymi sygnałami o efektach ubocznych (`reg_write`,
`mem_write`, `branch`, `jump`...). Bańka przepływa przez potok jak `nop`, ale
nie jest raportowana jako commit.

**Commit z WB:** `commit_valid = w_valid` i opis instrukcji niesiony przez cały
potok (`pc`, `instr`). Dzięki temu ślad jest identyczny jak w emulatorze i
`make cosim` działa bez zmian.

## 3. Hazardy

### Strukturalne
Dwa etapy chcą tego samego zasobu w tym samym takcie. U nas ich nie ma: pamięć
ma osobne porty instrukcji i danych, a bank rejestrów ma 2 porty odczytu i 1
port zapisu.

### Danych (RAW: read after write)
```
add x1, x2, x3     IF ID EX MEM WB          x1 zapisane na końcu WB (takt 5)
sub x4, x1, x5        IF ID EX MEM WB       x1 czytane w ID w takcie 3. Za wcześnie!
```
Rozwiązania, od najprostszego:
1. **Programowo:** wstawić `nop`-y między zależne instrukcje. Tak robi
   `make progs PAD=n` (`rvtool --pad-nops`), który przydaje się na etapie 8.1.
2. **Bypass WB→ID:** jeśli w tym samym takcie WB zapisuje rejestr, który ID czyta,
   weź wartość prosto z WB (bank rejestrów oddałby starą, patrz moduł 03).
3. **Forwarding do EX:** wynik `add` istnieje już na końcu EX. Następna
   instrukcja potrzebuje go na *początku* swojego EX, czyli takt później.
   Przekaż go z rejestru EX/MEM (albo MEM/WB) prosto na wejście ALU:
   ```
   fwd_a = (m_valid && m_reg_write && m_rd != 0 && m_rd == e_rs1) ? m_result :   // najnowszy wygrywa!
           (w_valid && w_reg_write && w_rd != 0 && w_rd == e_rs1) ? w_val    :
                                                                     e_rs1_val;
   ```
   Kolejność ma znaczenie (test 11, podtest 4). Warunek `rd != 0` też (podtest 8).
   Dana do store (`rs2`) też musi przejść przez forwarding.
4. **Stall (wstrzymanie) przy load-use:**
   ```
   lw  x1, 0(x2)      IF ID EX MEM WB          dana z pamięci jest dopiero na końcu MEM
   add x3, x1, x1        IF ID ** EX MEM WB    potrzebna na początku EX: trzeba poczekać 1 takt
   ```
   Wykrywasz to w ID (w EX jest load, którego `rd` to `rs1` albo `rs2` instrukcji w ID).
   Wtedy: **PC i IF/ID stoją**, a do ID/EX idzie bańka. Takt później load jest
   w MEM/WB i zwykły forwarding załatwia resztę.

### Sterowania (skoki)
Skok rozstrzyga się w EX. Do tego czasu IF i ID zdążyły pobrać 2 instrukcje
„za skokiem”. Jeśli skok jest wzięty: `pc = cel`, a instrukcje w IF/ID i ID/EX
trzeba **unieważnić** (flush, czyli zamienić w bańki). Kara wynosi 2 takty na
każdy wzięty skok. Strategia „zakładaj, że skok nie zostanie wzięty” to
najprostsza predykcja skoków.

**Priorytety**, gdy w jednym takcie dzieje się kilka rzeczy: redirect wygrywa ze
stallem (instrukcja, która czeka, i tak zostanie unieważniona).

## 4. Plan pracy

Szkielet (`rtl/core.sv`) ma sekcje dla etapów. Pracuj etapami i commituj (git!)
po każdym, który działa.

### 8.1 Potok bez obsługi hazardów danych
Rejestry potoku, bity `valid`, redirect i flush przy skokach.
Bez forwardingu, bypassu i stalli.
```bash
make progs PAD=4
```
`PAD=4` wstawia 4 `nop`-y *przed* każdą instrukcją (etykiety wskazują na pierwszy
z nich, żeby adresy powrotu `jal` się zgadzały). Przy takich odstępach żadna
zależność danych nie jest groźna.
**Pytanie:** jaki jest najmniejszy PAD, przy którym Twój potok z 8.1 przechodzi
wszystkie testy? Wylicz to z rysunku potoku, zanim sprawdzisz.

### 8.2 Forwarding i bypass
Dodaj forwarding EX/MEM→EX i MEM/WB→EX (dla obu operandów i dla danej do store)
oraz bypass WB→ID.
```bash
make progs PAD=1
```
**Pytanie:** dlaczego przy `PAD=0` nadal coś pada? Które testy i dlaczego akurat te?

### 8.3 Stall load-use
```bash
make progs           # PAD=0: pełne testy
```

### 8.4 Weryfikacja
```bash
make cosim
make fuzz N=200
make -C ../06-weryfikacja fuzz CORE=08 N=1000 SIM=verilator   # to samo, szybciej
make -C ../07-c-bare-metal test CORE=08                      # programy w C na potoku
```
Fuzzer jest tu naprawdę cenny: programy losowe tworzą zależności, skoki i
loady w kombinacjach, których nie ma w testach ręcznych.

### 8.5 Pomiary
1. **CPI.** Porównaj CPI z `make progs` z modułem 05 (zawsze 1,000). Na wzorcowym
   rozwiązaniu wychodzi np. `09_sort` ≈ 1,5, a `bench` z modułu 07 ≈ 1,3.
   Policz z śladu (albo dodając liczniki do testbencha), ile taktów tracisz na
   skoki, a ile na load-use.
2. **Synteza.**
   ```bash
   make synth T=core
   make -C ../05-single-cycle synth T=core
   ```
   Potok ma więcej komórek (rejestry potoku, forwarding). A najdłuższa ścieżka?
   **Uwaga:** Yosys liczy ścieżki wewnątrz modułu `core`. W wersji
   jednocyklowej pamięci są *poza* nim, więc prawdziwa ścieżka krytyczna
   (imem → … → dmem → zapis) jest rozcięta na kawałki i liczby wyglądają
   podobnie. W potoku każdy etap naprawdę jest odcięty rejestrami. Zastanów się,
   jaka jest teraz najdłuższa ścieżka (podpowiedź: EX, czyli forwarding + ALU +
   decyzja o skoku + multiplekser PC).

### 8.6 Dla ambitnych
- **Skoki w ID:** porównanie rejestrów i cel skoku już w ID zmniejsza karę do 1
  taktu, ale wymaga forwardingu do ID (i nowego stalla, gdy porównywany
  rejestr jest właśnie liczony w EX).
- **Statyczna predykcja BTFN** (backward taken, forward not taken): skoki wstecz
  (pętle) zakładamy jako wzięte. Wymaga obliczenia celu w IF/ID.
- **Predyktor dynamiczny:** tablica 2-bitowych liczników nasyconych indeksowana
  PC i BTB (branch target buffer). Zmierz CPI na `bench` przed i po.

**Gotowe, gdy:** `make progs` → 12 × PASS przy `PAD=0`, `make cosim` → wszystko
ZGODNE, `make fuzz N=500` → 0 różnic, `bench` z modułu 07 działa na `CORE=08`.
