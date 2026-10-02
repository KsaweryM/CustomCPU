`timescale 1ns/1ps
module tb_updown;
  `include "tb_common.svh"

  localparam int W = 4;
  logic         clk = 0;
  logic         rst, en, up, load, tc;
  logic [W-1:0] d, q;
  logic [W-1:0] model;

  updown #(.WIDTH(W)) dut (.*);

  always #5 clk = ~clk;

  // Model referencyjny: to samo zachowanie opisane "programistycznie".
  always @(posedge clk) begin
    if (rst)       model <= 0;
    else if (load) model <= d;
    else if (en)   model <= up ? model + 1'b1 : model - 1'b1;
  end

  initial begin
    tb_start();
    rst = 1; en = 0; up = 1; load = 0; d = 0;
    @(negedge clk);
    rst = 0;

    // kilka scenariuszy ręcznie
    en = 1; up = 1;
    repeat (15) @(negedge clk);
    `CHECK_EQ(q, 4'd15, "liczenie w górę do 15")
    `CHECK_EQ(tc, 1'b1, "tc przy q=max, up=1, en=1")
    en = 0; #1;
    `CHECK_EQ(tc, 1'b0, "tc = 0, gdy en = 0")
    en = 1;
    @(negedge clk);
    `CHECK_EQ(q, 4'd0, "zawinięcie w górę")
    up = 0; #1;
    `CHECK_EQ(tc, 1'b1, "tc przy q=0, up=0, en=1")
    @(negedge clk);
    `CHECK_EQ(q, 4'd15, "zawinięcie w dół")
    load = 1; d = 4'd9;
    @(negedge clk);
    `CHECK_EQ(q, 4'd9, "load")
    load = 1; en = 1; d = 4'd3; rst = 1;
    @(negedge clk);
    `CHECK_EQ(q, 4'd0, "rst ma pierwszeństwo przed load")
    rst = 0;

    // losowe pobudzenia porównywane z modelem
    repeat (500) begin
      rst  = ($urandom % 50) == 0;
      load = ($urandom % 8) == 0;
      en   = $urandom;
      up   = $urandom;
      d    = $urandom;
      #1;
      `CHECK_EQ(tc, en && (up ? q == 4'hF : q == 4'h0), $sformatf("tc (q=%0d en=%0d up=%0d)", q, en, up))
      @(negedge clk);
      `CHECK_EQ(q, model, "q zgodne z modelem")
    end
    tb_finish();
  end
endmodule
