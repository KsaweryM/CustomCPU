`timescale 1ns/1ps
module tb_lfsr16;
  `include "tb_common.svh"
  logic clk = 0, rst, en;
  logic [15:0] q, model;
  int period;
  lfsr16 dut (.*);
  always #5 clk = ~clk;
  initial begin
    tb_start();
    rst = 1; en = 0;
    @(negedge clk);
    `CHECK_EQ(q, 16'hACE1, "wartość po resecie")
    rst = 0;
    model = 16'hACE1;
    repeat (1000) begin
      en = ($urandom % 4) != 0;
      @(negedge clk);
      if (en) model = {model[0] ^ model[2] ^ model[3] ^ model[5], model[15:1]};
      `CHECK_EQ(q, model, "kolejna wartość")
    end
    // pełny okres: po 65535 krokach wracamy do wartości startowej
    rst = 1;
    @(negedge clk);
    rst = 0; en = 1;
    period = 0;
    do begin
      @(negedge clk);
      period++;
    end while (q !== 16'hACE1 && period < 70000);
    `CHECK_EQ(period, 65535, "okres LFSR")
    tb_finish();
  end
endmodule
