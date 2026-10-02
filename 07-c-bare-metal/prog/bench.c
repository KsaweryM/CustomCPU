// bench.c — mały benchmark: CRC32, sito Eratostenesa, sortowanie, mnożenie macierzy.
// Wymaga działającego lib/muldiv.c (zadanie 7.2).
// Zwraca liczbę niezgodnych wyników (0 = PASS).
#include "rt.h"

static uint8_t buf[1024];
static uint8_t sieve[2000];
static uint32_t arr[200];
static int32_t A[8][8], B[8][8], C[8][8];

static uint32_t crc32(const uint8_t *p, int n) {
    uint32_t c = 0xFFFFFFFFu;
    for (int i = 0; i < n; i++) {
        c ^= p[i];
        for (int k = 0; k < 8; k++)
            c = (c >> 1) ^ (0xEDB88320u & (0u - (c & 1u)));
    }
    return ~c;
}

static int count_primes(int n) {
    int cnt = 0;
    for (int i = 2; i < n; i++) sieve[i] = 1;
    for (int i = 2; i < n; i++) {
        if (!sieve[i]) continue;
        cnt++;
        for (int j = i + i; j < n; j += i) sieve[j] = 0;
    }
    return cnt;
}

static void insertion_sort(uint32_t *a, int n) {
    for (int i = 1; i < n; i++) {
        uint32_t x = a[i];
        int j = i - 1;
        while (j >= 0 && a[j] > x) { a[j + 1] = a[j]; j--; }
        a[j + 1] = x;
    }
}

static int errors;
static void expect(const char *what, uint32_t got, uint32_t exp, uint32_t cyc) {
    printf("%-8s = %08x  (%s)  cykli: %u\n", what, got, got == exp ? "OK" : "BLAD", cyc);
    if (got != exp) errors++;
}

int main(void) {
    uint32_t t;

    t = cycles();
    for (int i = 0; i < 1024; i++) buf[i] = (uint8_t)(i * 7 + 3);
    uint32_t crc = crc32(buf, 1024);
    expect("crc32", crc, 0x5d3de8edu, cycles() - t);

    t = cycles();
    expect("primes", (uint32_t)count_primes(2000), 303, cycles() - t);

    t = cycles();
    uint32_t x = 1, sum = 0;
    for (int i = 0; i < 200; i++) {
        x = x * 1103515245u + 12345u;
        arr[i] = x >> 16;
        sum += arr[i];
    }
    insertion_sort(arr, 200);
    int sorted = 1;
    for (int i = 1; i < 200; i++) sorted &= arr[i - 1] <= arr[i];
    expect("sorted", (uint32_t)sorted, 1, cycles() - t);
    expect("sum", sum, 6657269, 0);
    expect("min", arr[0], 1414, 0);
    expect("max", arr[199], 65202, 0);

    t = cycles();
    for (int i = 0; i < 8; i++)
        for (int j = 0; j < 8; j++) {
            A[i][j] = i + j;
            B[i][j] = i - 2 * j;
        }
    int32_t total = 0;
    for (int i = 0; i < 8; i++)
        for (int j = 0; j < 8; j++) {
            int32_t s = 0;
            for (int k = 0; k < 8; k++) s += A[i][k] * B[k][j];
            C[i][j] = s;
            total += s;
        }
    expect("matmul", (uint32_t)total, (uint32_t)-9856, cycles() - t);
    expect("C[7][7]", (uint32_t)C[7][7], (uint32_t)-840, 0);

    printf("bledow: %d\n", errors);
    return errors;
}
