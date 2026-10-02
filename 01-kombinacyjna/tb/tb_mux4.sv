`timescale 1ns/1ps
module tb_mux4;
  `include "tb_common.svh"
  logic [7:0]  d0, d1, d2, d3, y;
  logic [1:0]  sel;
  logic [15:0] e0, e1, e2, e3, ey;
  mux4 #(.WIDTH(8))  dut8  (.d0, .d1, .d2, .d3, .sel, .y);
  mux4 #(.WIDTH(16)) dut16 (.d0(e0), .d1(e1), .d2(e2), .d3(e3), .sel, .y(ey));
  initial begin
    tb_start();
    repeat (200) begin
      {d0, d1, d2, d3} = {$urandom, $urandom};
      {e0, e1, e2, e3} = {$urandom, $urandom};
      sel = $urandom;
      #1;
      `CHECK_EQ(y,  (sel == 0) ? d0 : (sel == 1) ? d1 : (sel == 2) ? d2 : d3, $sformatf("WIDTH=8, sel=%0d", sel))
      `CHECK_EQ(ey, (sel == 0) ? e0 : (sel == 1) ? e1 : (sel == 2) ? e2 : e3, $sformatf("WIDTH=16, sel=%0d", sel))
    end
    tb_finish();
  end
endmodule
