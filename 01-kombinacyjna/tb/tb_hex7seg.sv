`timescale 1ns/1ps
module tb_hex7seg;
  `include "tb_common.svh"
  logic [3:0] x;
  logic       en;
  logic [6:0] seg;
  // 16 kodów po 7 bitów, cyfra 0 na najmłodszej pozycji
  localparam logic [16*7-1:0] TABLE = {7'h71, 7'h79, 7'h5E, 7'h39, 7'h7C, 7'h77, 7'h6F, 7'h7F,
                                       7'h07, 7'h7D, 7'h6D, 7'h66, 7'h4F, 7'h5B, 7'h06, 7'h3F};
  hex7seg dut (.*);
  initial begin
    tb_start();
    for (int i = 0; i < 16; i++) begin
      // Najpierw jakaś inna cyfra, potem wyłączenie: zatrzask "zapamiętałby"
      // poprzednią wartość zamiast zgasić segmenty.
      en = 1; x = i[3:0];
      #1;
      `CHECK_EQ(seg, TABLE[7*i +: 7], $sformatf("cyfra %h", x))
      en = 0;
      #1;
      `CHECK_EQ(seg, 7'h00, $sformatf("en = 0 po cyfrze %h", x))
    end
    tb_finish();
  end
endmodule
