// ZADANIE 2.2 — 16-bitowy rejestr przesuwny z liniowym sprzężeniem (LFSR).
//
// Generator pseudolosowy w kilkunastu bramkach. Wersja Fibonacciego,
// wielomian x^16 + x^14 + x^13 + x^11 + 1 (okres 65535):
//
//   rst = 1 -> q = 16'hACE1
//   en  = 1 -> fb = q[0] ^ q[2] ^ q[3] ^ q[5];
//              q  = {fb, q[15:1]}        (przesunięcie w prawo, fb wchodzi od góry)
//   en  = 0 -> q bez zmian
//
// To samo w C:  bit = ((l >> 0) ^ (l >> 2) ^ (l >> 3) ^ (l >> 5)) & 1;
//               l = (l >> 1) | (bit << 15);
module lfsr16 (
  input  logic        clk,
  input  logic        rst,
  input  logic        en,
  output logic [15:0] q
);
  // TODO
  assign q = 16'h0;
endmodule
