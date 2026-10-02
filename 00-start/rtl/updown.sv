// updown.sv — ZADANIE 0.2: licznik w górę/w dół z ładowaniem.
//
// Specyfikacja (wszystko synchroniczne, na zboczu narastającym clk):
//   * rst = 1           -> q = 0                      (najwyższy priorytet)
//   * w przeciwnym razie load = 1 -> q = d
//   * w przeciwnym razie en = 1   -> q = q + 1 (gdy up = 1) albo q - 1 (gdy up = 0),
//                                   z zawijaniem (max+1 = 0, 0-1 = max)
//   * w przeciwnym razie q bez zmian
//
// Wyjście kombinacyjne tc ("terminal count"):
//   tc = 1 dokładnie wtedy, gdy en = 1 i następny krok liczenia
//   spowoduje zawinięcie, czyli (up = 1 i q = max) albo (up = 0 i q = 0).
//   Takie wyjście pozwala łączyć liczniki kaskadowo (tc -> en następnego).
//
// Test: make unit T=updown     Przebiegi: make wave T=updown
module updown #(
  parameter int WIDTH = 4
) (
  input  logic             clk,
  input  logic             rst,
  input  logic             en,
  input  logic             up,
  input  logic             load,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q,
  output logic             tc
);

  // TODO: rejestr q (always_ff)

  // TODO: wyjście tc (assign albo always_comb)
  assign tc = 1'b0;

endmodule
