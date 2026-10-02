// ZADANIE 1.2 — enkoder priorytetowy 8 -> 3.
//   idx   = numer NAJSTARSZEGO ustawionego bitu wejścia (np. 8'b0010_0110 -> 5)
//   valid = 1, jeśli którykolwiek bit jest ustawiony; gdy in = 0: valid = 0, idx = 0
// Wymaganie: użyj pętli for w always_comb (bez wypisywania 8 przypadków).
// Zastanów się: jak syntezator "rozwinie" tę pętlę? Ile poziomów logiki powstanie?
module prio_enc (
  input  logic [7:0] in,
  output logic [2:0] idx,
  output logic       valid
);
  // TODO
  assign idx   = 3'd0;
  assign valid = 1'b0;
endmodule
