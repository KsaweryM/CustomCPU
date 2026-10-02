// rv32sim — emulator referencyjny RV32I (model "złoty" dla Twojego procesora).
//
// Użycie:  rv32sim prog.hex [-t trace.txt] [-n max_instr] [-q]
//
// Mapa pamięci i format śladu są identyczne jak w common/tb/soc_tb.sv,
// więc ślady z emulatora i z symulacji RTL można porównać 1:1
// (common/tools/tracecmp.py).
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define RAM_SIZE     0x10000u
#define MMIO_TOHOST  0x10000000u
#define MMIO_PUTCHAR 0x10000004u
#define MMIO_CYCLES  0x10000008u

typedef struct {
    uint32_t x[32];
    uint32_t pc;
    uint64_t instret;
    int      done;      // 1 po zapisie do TOHOST
    uint32_t tohost;    // zapisana wartość
} cpu_t;

static uint8_t ram[RAM_SIZE];
static int quiet;

// ---------------------------------------------------------------------------
// Pamięć i MMIO (gotowe)
// ---------------------------------------------------------------------------
static void die(const char *msg, uint32_t a, uint32_t pc) {
    fprintf(stderr, "rv32sim: %s 0x%08x (pc=0x%08x)\n", msg, a, pc);
    printf("FAIL: %s 0x%08x\n", msg, a);
    exit(2);
}

// size = 1, 2 lub 4; zwraca wartość BEZ rozszerzania znaku
static uint32_t mem_read(cpu_t *c, uint32_t addr, int size) {
    if (addr + size <= RAM_SIZE) {
        uint32_t v = 0;
        for (int i = 0; i < size; i++) v |= (uint32_t)ram[addr + i] << (8 * i);
        return v;
    }
    if (addr == MMIO_CYCLES) return (uint32_t)c->instret;
    die("odczyt spod nieobsługiwanego adresu", addr, c->pc);
    return 0;
}

static void mem_write(cpu_t *c, uint32_t addr, uint32_t val, int size) {
    if (addr + size <= RAM_SIZE) {
        for (int i = 0; i < size; i++) ram[addr + i] = (uint8_t)(val >> (8 * i));
    } else if (addr == MMIO_TOHOST) {
        c->done = 1;
        c->tohost = val;
    } else if (addr == MMIO_PUTCHAR) {
        if (!quiet) { putchar((int)(val & 0xFF)); fflush(stdout); }
    } else {
        die("zapis pod nieobsługiwany adres", addr, c->pc);
    }
}

// ---------------------------------------------------------------------------
// Pomocnicze
// ---------------------------------------------------------------------------
static inline uint32_t bits(uint32_t v, int hi, int lo) {
    return (v >> lo) & ((1u << (hi - lo + 1)) - 1);
}
static inline int32_t sext(uint32_t v, int nbits) {
    uint32_t m = 1u << (nbits - 1);
    return (int32_t)((v ^ m) - m);
}

// ---------------------------------------------------------------------------
// ZADANIE 4.3 — wykonanie jednej instrukcji.
//
// Dostajesz stan procesora i 32-bitowe słowo instrukcji spod c->pc.
// Masz:
//   * policzyć wynik i (jeśli instrukcja ma rd) zwrócić go przez *rd_val,
//   * zaktualizować c->x[rd] (pamiętaj: zapis do x0 nie ma efektu),
//   * ustawić c->pc na adres następnej instrukcji,
//   * zwrócić numer rejestru, do którego zapisano wynik
//     (0, jeśli instrukcja nic nie zapisuje: branch, store, fence...).
//     Ta wartość trafia do śladu (trace), więc musi się zgadzać z RTL.
//
// Pamięć: mem_read(c, addr, size) zwraca wartość BEZ rozszerzania znaku,
//         mem_write(c, addr, val, size) zapisuje size bajtów (1, 2, 4).
// Instrukcje: wszystkie z RV32I (patrz README: tabela opcode'ów i formatów).
// FENCE, ECALL, EBREAK traktuj jak nop. Nieznana instrukcja -> illegal.
// Rozszerzenie M (opcode 0x33, funct7 = 0x01) — opcjonalne, moduł 09.
//
// Wskazówki dla C:
//   * (int32_t)a < (int32_t)b — porównanie ze znakiem,
//   * (uint32_t)((int32_t)a >> n) — przesunięcie arytmetyczne (w praktyce
//     wszystkie kompilatory robią tak dla signed; formalnie implementation-defined),
//   * przesunięcie o >= 32 to w C UB — maskuj: b & 31.
// ---------------------------------------------------------------------------
static int step(cpu_t *c, uint32_t instr, uint32_t *rd_val) {
    uint32_t op  = bits(instr, 6, 0);
    uint32_t rd  = bits(instr, 11, 7);
    uint32_t f3  = bits(instr, 14, 12);
    uint32_t rs1 = bits(instr, 19, 15);
    uint32_t rs2 = bits(instr, 24, 20);
    uint32_t f7  = bits(instr, 31, 25);
    uint32_t a = c->x[rs1], b = c->x[rs2];

    // TODO: immediate'y dla formatów I, S, B, U, J (użyj bits() i sext())

    uint32_t next = c->pc + 4;   // adres następnej instrukcji
    uint32_t res = 0;            // wartość do zapisania w rd
    int writes = 1;              // czy instrukcja zapisuje rd

    switch (op) {
    case 0x37:                   // LUI — gotowe, jako przykład
        res = instr & 0xFFFFF000u;
        break;

    // TODO: AUIPC, JAL, JALR, BRANCH, LOAD, STORE, OP-IMM, OP, FENCE, SYSTEM

    default:
        fprintf(stderr, "rv32sim: nieznana instrukcja 0x%08x pod pc=0x%08x\n", instr, c->pc);
        printf("FAIL: nieznana instrukcja 0x%08x pod pc=0x%08x\n", instr, c->pc);
        exit(2);
    }
    (void)f3; (void)f7; (void)a; (void)b;   // usuń, gdy zaczniesz ich używać
    (void)mem_write;

    if (writes && rd != 0) c->x[rd] = res;
    c->pc = next;
    *rd_val = res;
    return writes ? (int)rd : 0;
}

// ---------------------------------------------------------------------------
// Ładowanie programu i pętla główna (gotowe)
// ---------------------------------------------------------------------------
static void load_hex(const char *path) {
    FILE *f = fopen(path, "r");
    if (!f) { perror(path); exit(2); }
    char line[256];
    uint32_t addr = 0;
    while (fgets(line, sizeof line, f)) {
        char *p = line;
        while (*p == ' ' || *p == '\t') p++;
        if (*p == '\n' || *p == 0 || *p == '/') continue;
        uint32_t w = (uint32_t)strtoul(p, NULL, 16);
        if (addr + 4 > RAM_SIZE) { fprintf(stderr, "program za duży\n"); exit(2); }
        for (int i = 0; i < 4; i++) ram[addr + i] = (uint8_t)(w >> (8 * i));
        addr += 4;
    }
    fclose(f);
}

int main(int argc, char **argv) {
    const char *hex = NULL, *trace_path = NULL;
    uint64_t max_instr = 10000000;
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "-t") && i + 1 < argc) trace_path = argv[++i];
        else if (!strcmp(argv[i], "-n") && i + 1 < argc) max_instr = strtoull(argv[++i], NULL, 0);
        else if (!strcmp(argv[i], "-q")) quiet = 1;
        else hex = argv[i];
    }
    if (!hex) {
        fprintf(stderr, "użycie: %s prog.hex [-t trace.txt] [-n max_instr] [-q]\n", argv[0]);
        return 2;
    }
    load_hex(hex);
    FILE *trace = trace_path ? fopen(trace_path, "w") : NULL;

    cpu_t c;
    memset(&c, 0, sizeof c);
    while (!c.done && c.instret < max_instr) {
        if (c.pc >= RAM_SIZE || (c.pc & 3)) die("pc poza RAM albo niewyrównany", c.pc, c.pc);
        uint32_t instr = mem_read(&c, c.pc, 4), pc = c.pc, val = 0;
        if (instr == 0) die("wykonano słowo 0x00000000 pod adresem", pc, pc);
        int rd = step(&c, instr, &val);
        c.x[0] = 0;
        c.instret++;
        if (trace) {
            if (rd) fprintf(trace, "%08x %08x x%d=%08x\n", pc, instr, rd, val);
            else    fprintf(trace, "%08x %08x -\n", pc, instr);
        }
    }
    if (trace) fclose(trace);

    if (!c.done) {
        printf("FAIL: TIMEOUT po %llu instrukcjach\n", (unsigned long long)c.instret);
        return 2;
    }
    if (c.tohost == 1) {
        printf("PASS  instret=%llu\n", (unsigned long long)c.instret);
        return 0;
    }
    printf("FAIL: podtest %u\n", c.tohost >> 1);
    return 1;
}
