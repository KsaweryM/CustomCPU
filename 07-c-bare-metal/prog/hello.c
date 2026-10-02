// hello.c — pierwszy program w C na Twoim procesorze.
// Nie używa mnożenia ani dzielenia, więc działa przed zadaniem 7.2.
#include "rt.h"

static const char *names[] = {"zero", "ra", "sp", "gp"};
static int counter;          // .bss — wyzerowane przez crt0
static int answer = 42;      // .data

int main(void) {
    puts("Hello, world! Tu Twoj procesor RV32I.");
    print_str("answer = 0x");
    print_hex((uint32_t)answer, 2);
    putchar('\n');
    for (int i = 0; i < 4; i++) {
        counter++;
        print_str("  x");
        putchar('0' + i);
        print_str(" = ");
        puts(names[i]);
    }
    return counter == 4 ? 0 : 1;   // 0 -> PASS
}
