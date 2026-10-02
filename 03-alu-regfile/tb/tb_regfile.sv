`timescale 1ns/1ps
module tb_regfile;
  `include "tb_common.svh"
  logic clk = 0, we;
  logic [4:0]  rs1, rs2, rd;
  logic [31:0] rs1_val, rs2_val, rd_val;
  logic [31:0] model [32];
  regfile dut (.*);
  always #5 clk = ~clk;
  initial begin
    tb_start();
    for (int i = 0; i < 32; i++) model[i] = 0;
    we = 0; rd = 0; rd_val = 0;
    for (int i = 0; i < 32; i++) begin
      rs1 = i[4:0]; rs2 = 5'(31 - i);
      #1;
      `CHECK_EQ(rs1_val, 32'd0, $sformatf("x%0d na starcie = 0", i))
      `CHECK_EQ(rs2_val, 32'd0, $sformatf("x%0d na starcie = 0", 31 - i))
    end
    repeat (5000) begin
      @(negedge clk);
      we = $urandom; rd = $urandom; rd_val = $urandom;
      rs1 = ($urandom % 2) ? rd : 5'($urandom);
      rs2 = $urandom;
      #1;
      // przed zboczem: stare wartości, także gdy rs1 == rd
      `CHECK_EQ(rs1_val, model[rs1], $sformatf("odczyt x%0d (rs1)", rs1))
      `CHECK_EQ(rs2_val, model[rs2], $sformatf("odczyt x%0d (rs2)", rs2))
      @(posedge clk);
      if (we && rd != 0) model[rd] = rd_val;
    end
    tb_finish();
  end
endmodule
