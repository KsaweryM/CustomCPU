`timescale 1ns/1ps
module tb_prio_enc;
  `include "tb_common.svh"
  logic [7:0] in;
  logic [2:0] idx, exp_idx;
  logic       valid;
  prio_enc dut (.*);
  initial begin
    tb_start();
    for (int v = 0; v < 256; v++) begin
      in = v[7:0];
      exp_idx = 0;
      for (int b = 0; b < 8; b++) if (in[b]) exp_idx = b[2:0];
      #1;
      `CHECK_EQ(valid, |in, $sformatf("valid dla in=%b", in))
      `CHECK_EQ(idx, exp_idx, $sformatf("idx dla in=%b", in))
    end
    tb_finish();
  end
endmodule
