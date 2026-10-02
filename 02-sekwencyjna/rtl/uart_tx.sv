// ZADANIE 2.5 — nadajnik UART 8N1 (przyda się na FPGA w module 09).
//
// Linia tx w spoczynku = 1. Ramka: bit startu (0), 8 bitów danych od
// NAJMŁODSZEGO, bit stopu (1). Każdy bit trwa CLKS_PER_BIT taktów.
//
//   * gdy !busy i start = 1: zatrzaśnij data, od NASTĘPNEGO taktu
//     busy = 1 i tx = 0 (bit startu),
//   * busy = 1 przez całą ramkę: 10 * CLKS_PER_BIT taktów,
//   * start podczas busy jest ignorowany,
//   * tx musi pochodzić prosto z przerzutnika (bez logiki za nim —
//     inaczej na linii mogą pojawić się szpilki).
//
// Wskazówka: licznik taktów w bicie, licznik bitów, rejestr przesuwny
// {stop, data, start}.
module uart_tx #(
  parameter int CLKS_PER_BIT = 4
) (
  input  logic       clk,
  input  logic       rst,
  input  logic       start,
  input  logic [7:0] data,
  output logic       tx,
  output logic       busy
);
  // TODO
  assign tx   = 1'b1;
  assign busy = 1'b0;
endmodule
