# Moduł 07 — Programy w C na Twoim procesorze

**Cel:** uruchomić skompilowany kod C na procesorze, który sam zbudowałeś.
Bez systemu operacyjnego i bez libc, czyli na „gołym metalu”. To terytorium,
które znasz z pracy, tylko tym razem pod spodem jest Twój własny sprzęt.

**Czas:** 1–2 wieczory.

---

## 0. Toolchain

Makefile wykrywa toolchain sam. Wystarczy jedno z dwóch:

```bash
sudo apt install lld                      # clang już masz, brakuje tylko linkera
# albo
sudo apt install gcc-riscv64-unknown-elf  # pełny toolchain GNU (umie też rv32)
```

`make check-tools` sprawdza, czego brakuje.

> Ten moduł zweryfikowałem z clang 18 + ld.lld 18: wszystkie trzy programy
> przechodzą na emulatorze, rdzeniu jednocyklowym i potoku. Ścieżka GCC jest
> w Makefile, ale nie była testowana na tej maszynie (brak toolchaina GNU).

## 1. Co się dzieje przed `main()`

Procesor po resecie zaczyna od `pc = 0` i nic nie wie o C. Zanim wywołamy
`main`, kod startowy `crt0.S` musi:
1. **ustawić stos** (`sp`), bo C go używa do zmiennych lokalnych i wywołań,
2. **wyzerować `.bss`**, bo standard C gwarantuje, że `static int x;` = 0,
3. wywołać `main`,
4. przekazać wynik do testbencha (TOHOST: 0 → PASS).

`.data` (zmienne zainicjowane) nie trzeba kopiować: cały obraz programu
ląduje w RAM przez `$readmemh`. Na prawdziwym mikrokontrolerze `.data` leży
we flashu i crt0 kopiuje je do RAM.

## 2. Skrypt linkera (`link.ld`)

Mówi linkerowi, pod jakimi adresami położyć sekcje:

```
0x0000  .text     (najpierw .text.init = crt0 — bo pc startuje od 0!)
        .rodata   stałe, napisy
        .data     zmienne zainicjowane
        .bss      zmienne zerowane  (__bss_start .. __bss_end)
  ...   wolne
0xFFFF  ← _stack_top  (stos rośnie w dół)
```

Symbole `__bss_start`, `__bss_end` i `_stack_top` są zdefiniowane w skrypcie i
używane w `crt0.S`. Tak linker przekazuje adresy do kodu.

## 3. Od C do `.hex`

```
prog/hello.c ──clang -c──► .o ─┐
crt0.S, lib/*.c ──────────► .o ─┴─ld.lld -T link.ld──► .elf ──objcopy -O binary──► .bin ──rvtool bin2hex──► .hex
```

Ważne flagi (`Makefile`):
- `-march=rv32i -mabi=ilp32`: tylko instrukcje bazowe, `int`/`long`/wskaźnik po 32 bity,
- `-ffreestanding -nostdlib`: nie ma libc ani standardowego startu,
- `-mno-relax`: linker nie zamienia adresowania na względne względem `gp`
  (nasz crt0 nie ustawia `gp`),
- `-O2`: zobacz, jak dobry kod generuje kompilator (`make dis P=bench`).

## 4. Brakujące instrukcje: `__mulsi3` i spółka

RV32I nie ma mnożenia ani dzielenia. Gdy piszesz `a * b`, kompilator wstawia
`call __mulsi3`. Normalnie dostarcza ją `libgcc` albo `compiler-rt`, a u nas
piszesz ją sam (zadanie 7.2). Sprawdź w `build/bench.dis`, ile razy jest
wywoływana. W module 09 możesz dodać rozszerzenie M (`mul`, `div` w sprzęcie)
i porównać czas.

Kompilator może też sam wstawić wywołania `memset`/`memcpy` (np. przy
zerowaniu tablicy na stosie), nawet jeśli nigdzie ich nie wołasz. Dlatego są w
`lib/rt.c`.

## 5. MMIO i `volatile`

```c
#define MMIO_PUTCHAR ((volatile uint32_t *)0x10000004)
*MMIO_PUTCHAR = 'A';
```
Bez `volatile` kompilator mógłby uznać dwa zapisy pod ten sam adres za
zbędne i usunąć jeden. Na tym poziomie nie ma różnicy między „zmienną” a
„rejestrem urządzenia”. To ten sam `sw`, tylko pod inny adres, a testbench
(albo prawdziwy dekoder adresów) kieruje go do urządzenia.

## 6. Konwencja wywołań (ilp32)

Argumenty idą w `a0`–`a7`, wynik w `a0`. `ra` to adres powrotu. `s0`–`s11`
funkcja musi zachować (zapisuje je na stosie w prologu), a `t*` i `a*` może
niszczyć. Stos jest wyrównany do 16 bajtów. Obejrzyj prolog dowolnej funkcji w
`build/bench.dis`: `addi sp, sp, -N` i seria `sw s*, ...(sp)`.

---

## Zadania

### 7.1 Hello, world
```bash
make                    # kompiluje wszystko z prog/
make emu P=hello        # na emulatorze
make run P=hello        # na Twoim rdzeniu z modułu 05
make run P=hello CORE=08   # (po module 08) na potoku
```
Przeczytaj `crt0.S` i `link.ld`, a potem odpowiedz:
- Pod jakim adresem leży `counter` z `hello.c`? (`build/hello.dis` albo
  `llvm-objdump-18 -t build/hello.elf`, z GCC: `riscv64-unknown-elf-objdump -t`). W której sekcji?
- Co by się stało, gdyby crt0 nie zerował `.bss`? Sprawdź: zakomentuj pętlę,
  wstaw do `.bss` niezerowe śmieci (podpowiedź: nie da się łatwo, bo RAM w
  testbenchu jest zerowany; zmień chwilowo `mem[i] = 32'h0` na `32'hAAAAAAAA`
  w `soc_tb.sv`) i uruchom.
- Ile instrukcji wykonuje `hello`? Ile z nich to crt0?

### 7.2 Mnożenie i dzielenie programowe (`lib/muldiv.c`)
Zasady są w komentarzu w pliku. Test:
```bash
make emu P=muldiv_test
make run P=muldiv_test
```
Wektory w `prog/muldiv_test.c` obejmują przypadki brzegowe: dzielenie przez
zero, `INT_MIN / -1`, liczby ujemne.

### 7.3 Benchmark
```bash
make run P=bench
```
`bench` wypisuje wyniki i liczbę cykli dla czterech zadań (CRC32, sito,
sortowanie, mnożenie macierzy).
- Która część jest najdroższa? Dlaczego sortowanie tyle kosztuje?
- Policz z śladu (`build/bench.trace`), które PC wykonują się najczęściej:
  ```bash
  cut -d' ' -f1 build/bench.trace | sort | uniq -c | sort -rn | head
  ```
  i znajdź te adresy w `build/bench.dis`. To jest profilowanie na poziomie
  sprzętu.

### 7.4 Wszystko razem
```bash
make test            # hello, muldiv_test, bench: emulator i rdzeń
```

### 7.5 Własny program
Napisz `prog/<coś>.c`, np. liczby pierwsze do 10 000 i ich suma, szukanie
w drzewie BST w statycznej tablicy albo „gra w życie” wypisywana znakami.
`main` zwraca 0 = PASS. Makefile sam go znajdzie.

**Gotowe, gdy:** `make test` → wszystkie PASS na emulatorze i na rdzeniu.
