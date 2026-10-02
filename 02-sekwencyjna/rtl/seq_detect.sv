// ZADANIE 2.3 — automat Moore'a wykrywający sekwencję 1011 (z nakładaniem).
//
// Na każdym zboczu zegara automat odczytuje jeden bit `in`.
// `found` = 1 przez cały takt PO zboczu, na którym odczytano ostatnią
// jedynkę sekwencji 1-0-1-1. Wyjście zależy TYLKO od stanu (Moore).
// Nakładanie: wejście 1011011 daje dwa wykrycia (ostatnie "1" pierwszej
// sekwencji jest początkiem drugiej... sprawdź na kartce, od którego stanu
// trzeba zacząć!).
//
// Styl wymagany w kursie (dwa procesy):
//   typedef enum logic [2:0] {...} state_t;
//   always_ff  — tylko rejestr stanu,
//   always_comb — logika następnego stanu (z domyślnym przypisaniem!),
//   assign found = ...;
//
// Narysuj najpierw diagram stanów (5 stanów).
//
// Uwaga (Icarus Verilog): `next = in ? S_A : S_B;` dla typu enum daje błąd
// "This assignment requires an explicit cast". Pisz `if (in) next = S_A;
// else next = S_B;` albo rzutuj: `next = state_t'(in ? S_A : S_B);`
module seq_detect (
  input  logic clk,
  input  logic rst,
  input  logic in,
  output logic found
);
  // TODO
  assign found = 1'b0;
endmodule
