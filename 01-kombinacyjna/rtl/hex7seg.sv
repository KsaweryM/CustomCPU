// ZADANIE 1.5 — znajdź i usuń zatrzask (latch).
//
// Dekoder cyfry szesnastkowej na wyświetlacz 7-segmentowy.
//   seg = {g, f, e, d, c, b, a}, 1 = segment świeci.
//   en = 0 -> wszystkie segmenty zgaszone (seg = 0).
//
// Ten kod ma DWA błędy, przez które syntezator wstawi zatrzask:
// nie każda ścieżka przez always_comb przypisuje wartość do seg.
//   * `make lint`  — Verilator znajdzie jeden z nich (CASEINCOMPLETE),
//   * `make synth T=hex7seg` — Yosys odmówi: "Latch inferred ... from always_comb",
//   * `make unit T=hex7seg`  — test wykryje oba.
// Napraw i dokończ tablicę. Kody A..F:  A=77  b=7C  C=39  d=5E  E=79  F=71
module hex7seg (
  input  logic [3:0] x,
  input  logic       en,
  output logic [6:0] seg
);
  always_comb begin
    if (en) begin
      case (x)
        4'h0: seg = 7'h3F;
        4'h1: seg = 7'h06;
        4'h2: seg = 7'h5B;
        4'h3: seg = 7'h4F;
        4'h4: seg = 7'h66;
        4'h5: seg = 7'h6D;
        4'h6: seg = 7'h7D;
        4'h7: seg = 7'h07;
        4'h8: seg = 7'h7F;
        4'h9: seg = 7'h6F;
      endcase
    end
  end
endmodule
