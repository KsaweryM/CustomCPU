`timescale 1ns/1ps
module tb_alu;
  import rv32i_pkg::*;
  `include "tb_common.svh"
  logic [31:0] a, b, y, exp_y;
  logic [3:0]  op;
  alu dut (.*);

  function automatic logic [31:0] model(input logic [3:0] o, input logic [31:0] x, input logic [31:0] z);
    case (o)
      ALU_ADD:  return x + z;
      ALU_SUB:  return x - z;
      ALU_SLL:  return x << z[4:0];
      ALU_SLT:  return ($signed(x) < $signed(z)) ? 32'd1 : 32'd0;
      ALU_SLTU: return (x < z) ? 32'd1 : 32'd0;
      ALU_XOR:  return x ^ z;
      ALU_SRL:  return x >> z[4:0];
      ALU_SRA:  return $signed(x) >>> z[4:0];
      ALU_OR:   return x | z;
      ALU_AND:  return x & z;
      default:  return 32'd0;
    endcase
  endfunction

  function automatic logic [31:0] interesting();
    case ($urandom % 8)
      0: return 32'h0;
      1: return 32'h1;
      2: return 32'hFFFF_FFFF;
      3: return 32'h8000_0000;
      4: return 32'h7FFF_FFFF;
      5: return 32'd33;
      default: return $urandom;
    endcase
  endfunction

  initial begin
    tb_start();
    for (int i = 0; i < 20000; i++) begin
      op = i[3:0];
      a = interesting();
      b = interesting();
      #1;
      `CHECK_EQ(y, model(op, a, b), $sformatf("op=%b a=%h b=%h", op, a, b))
    end
    tb_finish();
  end
endmodule
