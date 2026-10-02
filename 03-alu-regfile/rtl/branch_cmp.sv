// ZADANIE 3.3 — komparator skoków warunkowych.
//
// funct3 instrukcji B-type (stałe F3_* w rv32i_pkg):
//   F3_BEQ  a == b           F3_BNE  a != b
//   F3_BLT  a <  b (signed)  F3_BGE  a >= b (signed)
//   F3_BLTU a <  b (unsigned) F3_BGEU a >= b (unsigned)
//   inne (010, 011): taken = 0
module branch_cmp import rv32i_pkg::*; (
  input  logic [31:0] a,
  input  logic [31:0] b,
  input  logic [2:0]  funct3,
  output logic        taken
);
  // TODO
  assign taken = 1'b0;
endmodule
