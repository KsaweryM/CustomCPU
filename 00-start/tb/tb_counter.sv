// Testbench licznika — przeczytaj go: tak wyglądają wszystkie testy w kursie.
`timescale 1ns/1ps
module tb_counter;
  `include "tb_common.svh"

  logic       clk = 0;
  logic       rst, en;
  logic [7:0] q;

  // Testowany układ (DUT = device under test). `.clk` to skrót od `.clk(clk)`.
  counter #(.WIDTH(8)) dut (.clk, .rst, .en, .q);

  // Zegar o okresie 10 ns.
  always #5 clk = ~clk;

  initial begin
    tb_start();

    // Wejścia zmieniamy na zboczu OPADAJĄCYM, a sprawdzamy przed
    // narastającym. Dzięki temu nie ścigamy się z przerzutnikami.
    rst = 1; en = 0;
    @(negedge clk);
    @(negedge clk);
    `CHECK_EQ(q, 8'd0, "po resecie")

    rst = 0; en = 1;
    repeat (5) @(negedge clk);
    `CHECK_EQ(q, 8'd5, "po 5 taktach liczenia")

    en = 0;
    repeat (3) @(negedge clk);
    `CHECK_EQ(q, 8'd5, "en = 0 zatrzymuje licznik")

    en = 1;
    repeat (251) @(negedge clk);
    `CHECK_EQ(q, 8'd0, "zawinięcie 255 -> 0")

    tb_finish();
  end
endmodule
