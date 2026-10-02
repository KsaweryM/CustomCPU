// counter.sv — GOTOWY przykład: licznik z resetem i zezwoleniem.
// Przeczytaj go, uruchom test (make unit T=counter) i obejrzyj przebiegi
// (make wave T=counter). Szczegóły w README.md.
module counter #(
  parameter int WIDTH = 8           // parametr: szerokość licznika w bitach
) (
  input  logic             clk,     // zegar
  input  logic             rst,     // reset synchroniczny, aktywny w stanie 1
  input  logic             en,      // zezwolenie na liczenie
  output logic [WIDTH-1:0] q        // aktualna wartość
);

  // Blok taktowany zboczem narastającym zegara = przerzutniki (rejestr).
  // Przypisanie nieblokujące (<=): nowa wartość "pojawi się" dopiero
  // po zboczu, wszystkie rejestry w układzie zmieniają się jednocześnie.
  always_ff @(posedge clk) begin
    if (rst)
      q <= '0;                      // '0 = same zera, niezależnie od WIDTH
    else if (en)
      q <= q + 1'b1;
  end

endmodule
