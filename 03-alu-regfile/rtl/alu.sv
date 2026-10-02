// ZADANIE 3.1 — ALU procesora RV32I.
//
// Operacje (stałe ALU_* w common/rtl/rv32i_pkg.sv):
//   ALU_ADD  a + b              ALU_SUB  a - b
//   ALU_SLL  a << b[4:0]        ALU_SRL  a >> b[4:0]    ALU_SRA  a >>> b[4:0] (arytm.)
//   ALU_SLT  (a < b) ze znakiem  -> 1 albo 0
//   ALU_SLTU (a < b) bez znaku   -> 1 albo 0
//   ALU_XOR  a ^ b   ALU_OR  a | b   ALU_AND  a & b
//   inne kody: y = 0
//
// Liczy się TYLKO 5 młodszych bitów b przy przesunięciach (tak definiuje
// to ISA: sll x1, x2, x3 przesuwa o x3 & 31).
// Uwaga na $signed: `a >>> n` jest arytmetyczne tylko, gdy a jest signed.
module alu import rv32i_pkg::*; (
  input  logic [31:0] a,
  input  logic [31:0] b,
  input  logic [3:0]  op,
  output logic [31:0] y
);
  // TODO
  assign y = 32'd0;
endmodule
