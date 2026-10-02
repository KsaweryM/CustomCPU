// ZADANIE 1.3 — sumator z przeniesieniami szeregowymi (ripple-carry).
//
// 1) full_adder: s = a + b + cin (1 bit), cout = przeniesienie.
//    Tylko operatory bitowe (& | ^), bez '+'.
// 2) adder: WIDTH sztuk full_adder połączonych łańcuchem przeniesień.
//    Użyj generate/for. Bez operatora '+'.
//
// Potem (ćwiczenie z syntezą, patrz README):
//    make synth T=adder   — ile bramek, jaka najdłuższa ścieżka?
//    Porównaj z wersją `assign {cout, sum} = a + b + cin;`
module full_adder (
  input  logic a, b, cin,
  output logic s, cout
);
  // TODO
  assign s    = 1'b0;
  assign cout = 1'b0;
endmodule

module adder #(
  parameter int WIDTH = 32
) (
  input  logic [WIDTH-1:0] a, b,
  input  logic             cin,
  output logic [WIDTH-1:0] sum,
  output logic             cout
);
  // TODO: łańcuch przeniesień c[0..WIDTH], c[0] = cin, cout = c[WIDTH]
  assign sum  = '0;
  assign cout = 1'b0;
endmodule
