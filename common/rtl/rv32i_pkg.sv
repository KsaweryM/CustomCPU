// ---------------------------------------------------------------------------
// rv32i_pkg — stałe wspólne dla całego kursu.
//
// Użycie w module:   module foo import rv32i_pkg::*; ( ... );
// Plik pakietu musi być podany kompilatorowi PRZED plikami, które go używają
// (Makefile'e kursu robią to za Ciebie).
// ---------------------------------------------------------------------------
package rv32i_pkg;

  // ---- Opcode'y (instr[6:0]) ----------------------------------------------
  localparam logic [6:0] OP_LUI    = 7'b0110111;
  localparam logic [6:0] OP_AUIPC  = 7'b0010111;
  localparam logic [6:0] OP_JAL    = 7'b1101111;
  localparam logic [6:0] OP_JALR   = 7'b1100111;
  localparam logic [6:0] OP_BRANCH = 7'b1100011;
  localparam logic [6:0] OP_LOAD   = 7'b0000011;
  localparam logic [6:0] OP_STORE  = 7'b0100011;
  localparam logic [6:0] OP_IMM    = 7'b0010011;
  localparam logic [6:0] OP_REG    = 7'b0110011;
  localparam logic [6:0] OP_FENCE  = 7'b0001111;
  localparam logic [6:0] OP_SYSTEM = 7'b1110011;

  // ---- Operacje ALU -------------------------------------------------------
  // Kodowanie celowo = {funct7[5], funct3} instrukcji R-type, dzięki temu
  // dekoder dla OP_REG po prostu przepisuje bity instrukcji.
  localparam logic [3:0] ALU_ADD  = 4'b0_000;
  localparam logic [3:0] ALU_SUB  = 4'b1_000;
  localparam logic [3:0] ALU_SLL  = 4'b0_001;
  localparam logic [3:0] ALU_SLT  = 4'b0_010;
  localparam logic [3:0] ALU_SLTU = 4'b0_011;
  localparam logic [3:0] ALU_XOR  = 4'b0_100;
  localparam logic [3:0] ALU_SRL  = 4'b0_101;
  localparam logic [3:0] ALU_SRA  = 4'b1_101;
  localparam logic [3:0] ALU_OR   = 4'b0_110;
  localparam logic [3:0] ALU_AND  = 4'b0_111;

  // ---- funct3 skoków warunkowych -------------------------------------------
  localparam logic [2:0] F3_BEQ  = 3'b000;
  localparam logic [2:0] F3_BNE  = 3'b001;
  localparam logic [2:0] F3_BLT  = 3'b100;
  localparam logic [2:0] F3_BGE  = 3'b101;
  localparam logic [2:0] F3_BLTU = 3'b110;
  localparam logic [2:0] F3_BGEU = 3'b111;

  // ---- funct3 load/store (szerokość dostępu) -------------------------------
  localparam logic [2:0] F3_B  = 3'b000;
  localparam logic [2:0] F3_H  = 3'b001;
  localparam logic [2:0] F3_W  = 3'b010;
  localparam logic [2:0] F3_BU = 3'b100;
  localparam logic [2:0] F3_HU = 3'b101;

  // ---- Sygnały sterujące ścieżki danych (moduł 05) --------------------------
  // Źródło operandu A ALU
  localparam logic [1:0] A_RS1  = 2'd0;
  localparam logic [1:0] A_PC   = 2'd1;
  localparam logic [1:0] A_ZERO = 2'd2;
  // Co zapisujemy do rd
  localparam logic [1:0] WB_ALU = 2'd0;
  localparam logic [1:0] WB_MEM = 2'd1;
  localparam logic [1:0] WB_PC4 = 2'd2;

  // ---- Mapa pamięci testbenchu ---------------------------------------------
  localparam logic [31:0] RAM_SIZE     = 32'h0001_0000;  // 64 KiB od adresu 0
  localparam logic [31:0] MMIO_TOHOST  = 32'h1000_0000;  // zapis: koniec testu
  localparam logic [31:0] MMIO_PUTCHAR = 32'h1000_0004;  // zapis: wypisz znak
  localparam logic [31:0] MMIO_CYCLES  = 32'h1000_0008;  // odczyt: licznik cykli

  localparam logic [31:0] NOP = 32'h0000_0013;           // addi x0, x0, 0

endpackage
