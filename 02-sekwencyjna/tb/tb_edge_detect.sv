`timescale 1ns/1ps
module tb_edge_detect;
  `include "tb_common.svh"
  logic clk = 0, rst, in, rise, prev_model;
  edge_detect dut (.*);
  always #5 clk = ~clk;
  always @(posedge clk) prev_model <= rst ? 1'b0 : in;
  initial begin
    tb_start();
    rst = 1; in = 0;
    @(negedge clk);
    rst = 0;
    in = 1; #1;
    `CHECK_EQ(rise, 1'b1, "0 -> 1: rise")
    @(negedge clk);
    `CHECK_EQ(rise, 1'b0, "1 trzymane: brak rise")
    in = 0; #1;
    `CHECK_EQ(rise, 1'b0, "1 -> 0: brak rise")
    repeat (300) begin
      @(negedge clk);
      in = $urandom;
      rst = ($urandom % 40) == 0;
      #1;
      `CHECK_EQ(rise, in & ~prev_model, $sformatf("in=%0d prev=%0d", in, prev_model))
    end
    tb_finish();
  end
endmodule
