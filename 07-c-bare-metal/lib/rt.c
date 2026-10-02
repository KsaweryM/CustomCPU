// rt.c — implementacja rt.h. Celowo prosta: bez buforowania, bez libc.
#include <stdarg.h>
#include "rt.h"

int putchar(int c) {
    *MMIO_PUTCHAR = (uint32_t)(unsigned char)c;
    return c;
}

void print_str(const char *s) {
    while (*s) putchar(*s++);
}

int puts(const char *s) {
    print_str(s);
    putchar('\n');
    return 0;
}

// Dzielenie przez 10 kompilator zamieni na wywołanie __udivsi3/__umodsi3
// (RV32I nie ma instrukcji div!) — patrz lib/muldiv.c.
static void print_num(uint32_t v, unsigned base, int width, char pad, int upper) {
    char buf[12];
    int i = 0;
    const char *dig = upper ? "0123456789ABCDEF" : "0123456789abcdef";
    do {
        buf[i++] = dig[v % base];
        v /= base;
    } while (v && i < (int)sizeof buf);
    while (width-- > i) putchar(pad);
    while (i) putchar(buf[--i]);
}

void print_udec(uint32_t v) { print_num(v, 10, 0, ' ', 0); }
void print_hex(uint32_t v, int digits) { print_num(v, 16, digits, '0', 0); }

void print_dec(int32_t v) {
    if (v < 0) {
        putchar('-');
        print_num(0u - (uint32_t)v, 10, 0, ' ', 0);
    } else
        print_num((uint32_t)v, 10, 0, ' ', 0);
}

static void pad_to(int n, int width) {
    while (n++ < width) putchar(' ');
}

static int num_len(uint32_t v, unsigned base) {
    int n = 1;
    while (v >= base) { v /= base; n++; }
    return n;
}

int printf(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    for (; *fmt; fmt++) {
        if (*fmt != '%') { putchar(*fmt); continue; }
        fmt++;
        char pad = ' ';
        int width = 0, left = 0;
        if (*fmt == '-') { left = 1; fmt++; }
        if (*fmt == '0') { pad = '0'; fmt++; }
        while (*fmt >= '0' && *fmt <= '9') width = width * 10 + (*fmt++ - '0');
        switch (*fmt) {
        case 'd': {
            int32_t v = va_arg(ap, int32_t);
            uint32_t mag = v < 0 ? 0u - (uint32_t)v : (uint32_t)v;
            int len = num_len(mag, 10) + (v < 0);
            if (!left && pad == ' ') pad_to(len, width);
            if (v < 0) putchar('-');
            print_num(mag, 10, (!left && pad == '0') ? width - (v < 0) : 0, '0', 0);
            if (left) pad_to(len, width);
            break;
        }
        case 'u': case 'x': case 'X': {
            uint32_t v = va_arg(ap, uint32_t);
            unsigned base = (*fmt == 'u') ? 10 : 16;
            int len = num_len(v, base);
            if (left) { print_num(v, base, 0, ' ', *fmt == 'X'); pad_to(len, width); }
            else print_num(v, base, width, pad, *fmt == 'X');
            break;
        }
        case 's': {
            const char *str = va_arg(ap, const char *);
            int len = (int)strlen(str);
            if (!left) pad_to(len, width);
            print_str(str);
            if (left) pad_to(len, width);
            break;
        }
        case 'c': putchar(va_arg(ap, int)); break;
        case '%': putchar('%'); break;
        case 0: va_end(ap); return 0;
        default: putchar('%'); putchar(*fmt); break;
        }
    }
    va_end(ap);
    return 0;
}

// Kompilator może sam wstawiać wywołania memset/memcpy (np. przy
// zerowaniu tablic na stosie), więc muszą istnieć.
void *memset(void *dst, int c, size_t n) {
    unsigned char *d = dst;
    while (n--) *d++ = (unsigned char)c;
    return dst;
}

void *memcpy(void *dst, const void *src, size_t n) {
    unsigned char *d = dst;
    const unsigned char *s = src;
    while (n--) *d++ = *s++;
    return dst;
}

size_t strlen(const char *s) {
    size_t n = 0;
    while (s[n]) n++;
    return n;
}
