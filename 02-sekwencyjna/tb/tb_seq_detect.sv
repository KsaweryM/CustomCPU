`timescale 1ns/1ps
module tb_seq_detect;
  `include "tb_common.svh"
  logic clk = 0, rst, in, found;
  logic [3:0] hist;
  int hits;
  seq_detect dut (.*);
  always #5 clk = ~clk;

  task automatic feed(input string bits_, output int n);
    n = 0;
    for (int i = 0; i < bits_.len(); i++) begin
      in = (bits_[i] == "1");
      @(negedge clk);
      if (found) n++;
    end
  endtask

  initial begin
    tb_start();
    rst = 1; in = 0;
    @(negedge clk);
    rst = 0;
    #1;
    `CHECK_EQ(found, 1'b0, "po resecie")
    feed("1011", hits);
    `CHECK_EQ(hits, 1, "1011 -> 1 wykrycie")
    `CHECK_EQ(found, 1'b1, "found tuż po ostatnim bicie")
    feed("011", hits);
    `CHECK_EQ(hits, 1, "nakładanie: 1011|011 -> kolejne wykrycie")
    feed("0000", hits);
    feed("10101011", hits);
    `CHECK_EQ(hits, 1, "10101011 -> 1 wykrycie")
    feed("1111011101101", hits);
    `CHECK_EQ(hits, 2, "1111011101101 -> 2 wykrycia")

    // losowo, z modelem: found == ostatnie 4 próbki to 1011
    rst = 1;
    @(negedge clk);
    rst = 0;
    hist = 0;
    repeat (2000) begin
      in = $urandom;
      @(negedge clk);
      hist = {hist[2:0], in};
      `CHECK_EQ(found, hist == 4'b1011, $sformatf("historia %b", hist))
    end
    tb_finish();
  end
endmodule
