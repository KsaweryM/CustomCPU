// ZADANIE 4.2 — generator stałej natychmiastowej (immediate).
//
// Na podstawie opcode (instr[6:0]) wybierz format i złóż 32-bitową stałą
// rozszerzoną znakiem (bit znaku to ZAWSZE instr[31]):
//
//   I-type (OP_IMM, OP_LOAD, OP_JALR):  instr[31:20]
//   S-type (OP_STORE):                  {instr[31:25], instr[11:7]}
//   B-type (OP_BRANCH):                 {instr[31], instr[7], instr[30:25], instr[11:8], 1'b0}
//   U-type (OP_LUI, OP_AUIPC):          {instr[31:12], 12'b0}       (bez rozszerzania)
//   J-type (OP_JAL):                    {instr[31], instr[19:12], instr[20], instr[30:21], 1'b0}
//   inne opcode'y:                      0
//
// Uwaga: dla slli/srli/srai wynik to po prostu I-immediate (z bitem 10
// ustawionym dla srai) — ALU i tak patrzy tylko na 5 młodszych bitów.
module imm_gen import rv32i_pkg::*; (
  input  logic [31:0] instr,
  output logic [31:0] imm
);
  // TODO
  assign imm = 32'd0;
endmodule
