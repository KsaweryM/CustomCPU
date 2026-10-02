// muldiv_test.c — test dla lib/muldiv.c (zadanie 7.2).
// Zwraca liczbę błędów (0 = PASS). Nie używa printf z %d, bo ten
// sam potrzebuje dzielenia — błędy wypisujemy szesnastkowo.
#include "rt.h"

uint32_t __mulsi3(uint32_t, uint32_t);
uint32_t __udivsi3(uint32_t, uint32_t);
uint32_t __umodsi3(uint32_t, uint32_t);
int32_t  __divsi3(int32_t, int32_t);
int32_t  __modsi3(int32_t, int32_t);

static int errors;

static void check(const char *what, uint32_t a, uint32_t b, uint32_t got, uint32_t exp) {
    if (got != exp) {
        errors++;
        print_str("BLAD ");
        print_str(what);
        print_str("(0x");  print_hex(a, 8);
        print_str(", 0x"); print_hex(b, 8);
        print_str(") = 0x"); print_hex(got, 8);
        print_str(", oczekiwano 0x"); print_hex(exp, 8);
        putchar('\n');
    }
}

struct vec { uint32_t a, b, mul, udiv, umod, div, mod; };

// Wartości policzone na hoście (Python) — patrz README.
static const struct vec v[] = {
    {0, 0, 0, 0xFFFFFFFF, 0, 0xFFFFFFFF, 0},
    {1234, 5678, 7006652, 0, 1234, 0, 1234},
    {5678, 1234, 7006652, 4, 742, 4, 742},
    {0xFFFFFFFF, 1, 0xFFFFFFFF, 0xFFFFFFFF, 0, 0xFFFFFFFF, 0},
    {0xFFFFFFFF, 0xFFFFFFFF, 1, 1, 0, 1, 0},
    {0xFFFFFFF9, 2, 0xFFFFFFF2, 0x7FFFFFFC, 1, 0xFFFFFFFD, 0xFFFFFFFF},   // -7, 2
    {7, 0xFFFFFFFE, 0xFFFFFFF2, 0, 7, 0xFFFFFFFD, 1},                     // 7, -2
    {0x80000000, 0xFFFFFFFF, 0x80000000, 0, 0x80000000, 0x80000000, 0},   // INT_MIN / -1
    {123, 0, 0, 0xFFFFFFFF, 123, 0xFFFFFFFF, 123},                       // dzielenie przez 0
    {0x12345678, 0x9ABC, 0xDA73B020, 0x1E1E, 0x2C70, 0x1E1E, 0x2C70},
    {100000, 100000, 0x540BE400, 1, 0, 1, 0},
    {0x80000000, 2, 0, 0x40000000, 0, 0xC0000000, 0},
};

int main(void) {
    for (unsigned i = 0; i < sizeof v / sizeof v[0]; i++) {
        check("mul",  v[i].a, v[i].b, __mulsi3(v[i].a, v[i].b), v[i].mul);
        check("udiv", v[i].a, v[i].b, __udivsi3(v[i].a, v[i].b), v[i].udiv);
        check("umod", v[i].a, v[i].b, __umodsi3(v[i].a, v[i].b), v[i].umod);
        check("div",  v[i].a, v[i].b, (uint32_t)__divsi3((int32_t)v[i].a, (int32_t)v[i].b), v[i].div);
        check("mod",  v[i].a, v[i].b, (uint32_t)__modsi3((int32_t)v[i].a, (int32_t)v[i].b), v[i].mod);
    }
    if (errors == 0) puts("muldiv: wszystko OK");
    return errors;
}
