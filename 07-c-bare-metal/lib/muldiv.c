// muldiv.c — ZADANIE 7.2
//
// RV32I nie ma instrukcji mnożenia ani dzielenia. Gdy w C napiszesz a * b
// albo a / b, kompilator wygeneruje wywołanie funkcji pomocniczej
// o ustalonej nazwie (ABI libgcc / compiler-rt). Zwykle dostarcza je
// libgcc — my piszemy je sami.
//
// Zasady:
//   * NIE używaj operatorów * / % w tym pliku (kompilator wywołałby ...
//     te same funkcje — nieskończona rekurencja).
//   * Wystarczą przesunięcia, dodawanie, odejmowanie i porównania.
//   * Dzielenie przez zero: zachowaj się tak jak instrukcje RISC-V M:
//     x / 0 = 0xFFFFFFFF (czyli -1), x % 0 = x.
//   * Dzielenie ze znakiem zaokrągla w stronę zera (jak w C99):
//     -7 / 2 = -3, -7 % 2 = -1.
//
// Test: make run P=muldiv_test
#include <stdint.h>

// a * b (mod 2^32) — działa tak samo dla liczb ze znakiem i bez
uint32_t __mulsi3(uint32_t a, uint32_t b) {
    // TODO: mnożenie "pisemne" binarnie (shift-and-add)
    (void)a; (void)b;
    return 0;
}

// a / b bez znaku
uint32_t __udivsi3(uint32_t a, uint32_t b) {
    // TODO: dzielenie "pisemne" binarnie (restoring division):
    //   przesuwaj resztę w lewo o 1 bit, dosuwaj kolejny bit a od góry,
    //   jeśli reszta >= b, odejmij b i ustaw bit ilorazu.
    (void)a; (void)b;
    return 0;
}

// a % b bez znaku
uint32_t __umodsi3(uint32_t a, uint32_t b) {
    // TODO
    (void)a; (void)b;
    return 0;
}

// a / b ze znakiem
int32_t __divsi3(int32_t a, int32_t b) {
    // TODO: sprowadź do __udivsi3 na wartościach bezwzględnych, popraw znak
    (void)a; (void)b;
    return 0;
}

// a % b ze znakiem (znak wyniku = znak dzielnej)
int32_t __modsi3(int32_t a, int32_t b) {
    // TODO
    (void)a; (void)b;
    return 0;
}
