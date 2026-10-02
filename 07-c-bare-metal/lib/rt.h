// rt.h — minimalne "środowisko uruchomieniowe" dla programów na naszym CPU.
#pragma once
#include <stdint.h>
#include <stddef.h>

#define MMIO_TOHOST  ((volatile uint32_t *)0x10000000)
#define MMIO_PUTCHAR ((volatile uint32_t *)0x10000004)
#define MMIO_CYCLES  ((volatile uint32_t *)0x10000008)

// Licznik cykli z testbencha (w rv32sim: liczba wykonanych instrukcji).
static inline uint32_t cycles(void) { return *MMIO_CYCLES; }

int  putchar(int c);
int  puts(const char *s);              // wypisuje s i '\n'
void print_str(const char *s);         // bez '\n'
void print_dec(int32_t v);
void print_udec(uint32_t v);
void print_hex(uint32_t v, int digits);
// Obsługuje: %d %u %x %X %s %c %%, szerokość (%8d), zera (%08x) i wyrównanie do lewej (%-8s).
int  printf(const char *fmt, ...);

void  *memset(void *dst, int c, size_t n);
void  *memcpy(void *dst, const void *src, size_t n);
size_t strlen(const char *s);
