// ZADANIE 2.1 — detektor zbocza narastającego.
//
//   prev = wartość `in` z poprzedniego zbocza zegara (przerzutnik; po resecie 0)
//   rise = in & ~prev   (kombinacyjnie)
//
// rise trwa więc od chwili, gdy `in` przejdzie 0 -> 1, do najbliższego
// zbocza zegara. Typowy element: zamiana "poziomu" (przycisk) na "impuls".
module edge_detect (
  input  logic clk,
  input  logic rst,
  input  logic in,
  output logic rise
);
  // TODO
  assign rise = 1'b0;
endmodule
