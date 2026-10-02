`timescale 1ns/1ps
module tb_branch_cmp;
  import rv32i_pkg::*;
  `include "tb_common.svh"
  logic [31:0] a, b;
  logic [2:0]  funct3;
  logic        taken, exp_t;
  branch_cmp dut (.*);
  initial begin
    tb_start();
    for (int i = 0; i < 8000; i++) begin
      funct3 = i[2:0];
      case ($urandom % 4)
        0: begin a = $urandom; b = a; end
        1: begin a = 32'hFFFF_FFFF; b = 1; end
        2: begin a = 1; b = 32'h8000_0000; end
        default: begin a = $urandom; b = $urandom; end
      endcase
      if ($urandom % 2) {a, b} = {b, a};
      case (funct3)
        F3_BEQ:  exp_t = a == b;
        F3_BNE:  exp_t = a != b;
        F3_BLT:  exp_t = $signed(a) <  $signed(b);
        F3_BGE:  exp_t = $signed(a) >= $signed(b);
        F3_BLTU: exp_t = a <  b;
        F3_BGEU: exp_t = a >= b;
        default: exp_t = 0;
      endcase
      #1;
      `CHECK_EQ(taken, exp_t, $sformatf("funct3=%b a=%h b=%h", funct3, a, b))
    end
    tb_finish();
  end
endmodule
