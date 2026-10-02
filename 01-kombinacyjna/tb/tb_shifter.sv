`timescale 1ns/1ps
module tb_shifter;
  `include "tb_common.svh"
  logic [31:0] a, y, exp_y;
  logic [4:0]  shamt;
  logic        right, arith;
  shifter dut (.*);
  initial begin
    tb_start();
    for (int i = 0; i < 3000; i++) begin
      a = (i % 3 == 0) ? 32'h8000_0001 : $urandom;
      shamt = (i < 32) ? i[4:0] : $urandom;
      {right, arith} = $urandom;
      #1;
      if (!right)     exp_y = a << shamt;
      else if (arith) exp_y = $signed(a) >>> shamt;
      else            exp_y = a >> shamt;
      `CHECK_EQ(y, exp_y, $sformatf("a=%h shamt=%0d right=%0d arith=%0d", a, shamt, right, arith))
    end
    tb_finish();
  end
endmodule
