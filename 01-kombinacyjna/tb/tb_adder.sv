`timescale 1ns/1ps
module tb_adder;
  `include "tb_common.svh"
  logic [7:0]  a8, b8, s8;
  logic [31:0] a, b, s;
  logic        cin, c8, c;
  adder #(.WIDTH(8))  dut8  (.a(a8), .b(b8), .cin, .sum(s8), .cout(c8));
  adder #(.WIDTH(32)) dut32 (.a, .b, .cin, .sum(s), .cout(c));
  initial begin
    tb_start();
    // 8 bitów: wszystkie kombinacje
    for (int i = 0; i < 512; i++)
      for (int j = 0; j < 256; j++) begin
        {cin, a8} = i[8:0];
        b8 = j[7:0];
        #1;
        `CHECK_EQ({c8, s8}, {1'b0, a8} + {1'b0, b8} + cin, $sformatf("8b: %0d + %0d + %0d", a8, b8, cin))
      end
    // 32 bity: losowo + przypadki brzegowe
    for (int i = 0; i < 2000; i++) begin
      a = $urandom; b = $urandom; cin = $urandom;
      if (i == 0) begin a = 32'hFFFF_FFFF; b = 0; cin = 1; end
      if (i == 1) begin a = 32'hFFFF_FFFF; b = 32'hFFFF_FFFF; cin = 1; end
      #1;
      `CHECK_EQ({c, s}, {1'b0, a} + {1'b0, b} + cin, $sformatf("32b: %h + %h + %0d", a, b, cin))
    end
    tb_finish();
  end
endmodule
