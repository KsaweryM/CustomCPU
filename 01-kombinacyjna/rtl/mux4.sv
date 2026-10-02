// ZADANIE 1.1 — multiplekser 4:1 o parametryzowanej szerokości.
//   sel = 0 -> y = d0,  1 -> d1,  2 -> d2,  3 -> d3
// Napisz go DWA razy (zostaw jedną wersję, drugą w komentarzu):
//   a) always_comb + case
//   b) jednym assign z operatorem ?:
module mux4 #(
  parameter int WIDTH = 8
) (
  input  logic [WIDTH-1:0] d0, d1, d2, d3,
  input  logic [1:0]       sel,
  output logic [WIDTH-1:0] y
);
  // TODO
  assign y = '0;
endmodule
