// ZADANIE 2.4 — synchroniczna kolejka FIFO.
//
//   push = 1 i !full  -> zapisz din na koniec kolejki
//   pop  = 1 i !empty -> usuń element z początku kolejki
//   push przy full oraz pop przy empty są ignorowane
//   push i pop w tym samym takcie: oba się wykonują (o ile dozwolone)
//
//   dout  = element na początku kolejki (kombinacyjnie, ważny gdy !empty)
//   count = liczba elementów (0..DEPTH), full = (count == DEPTH), empty = (count == 0)
//
// DEPTH jest potęgą dwójki. Klasyczna sztuczka: wskaźniki zapisu i odczytu
// mają o JEDEN bit więcej niż potrzeba do adresowania — wtedy
// count = wr_ptr - rd_ptr, a full i empty da się odróżnić.
// Pamięć: logic [WIDTH-1:0] mem [0:DEPTH-1]; zapis w always_ff.
module fifo #(
  parameter int WIDTH = 8,
  parameter int DEPTH = 8
) (
  input  logic                   clk,
  input  logic                   rst,
  input  logic                   push,
  input  logic [WIDTH-1:0]       din,
  input  logic                   pop,
  output logic [WIDTH-1:0]       dout,
  output logic                   full,
  output logic                   empty,
  output logic [$clog2(DEPTH):0] count
);
  // TODO
  assign dout  = '0;
  assign full  = 1'b0;
  assign empty = 1'b1;
  assign count = '0;
endmodule
