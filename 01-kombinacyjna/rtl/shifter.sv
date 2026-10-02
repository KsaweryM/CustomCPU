// ZADANIE 1.4 — 32-bitowy barrel shifter (przesuwnik logarytmiczny).
//
//   right = 0               -> y = a << shamt        (SLL)
//   right = 1, arith = 0    -> y = a >> shamt        (SRL, wsuwa zera)
//   right = 1, arith = 1    -> y = a >>> shamt       (SRA, powiela bit znaku)
//   (right = 0, arith = 1 traktuj jak SLL)
//
// Wymaganie: NIE używaj operatorów << >> >>>. Zbuduj 5 warstw multiplekserów:
// warstwa k przesuwa o 2^k albo nie, zależnie od shamt[k].
// Wskazówka: przesunięcie w lewo = odwróć bity, przesuń w prawo, odwróć.
//
// Ten układ wejdzie później do ALU (moduł 03) — tam wolno już użyć operatorów.
module shifter (
  input  logic [31:0] a,
  input  logic [4:0]  shamt,
  input  logic        right,
  input  logic        arith,
  output logic [31:0] y
);
  // TODO
  assign y = '0;
endmodule
