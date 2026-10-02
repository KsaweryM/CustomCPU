`timescale 1ns/1ps
module tb_fifo;
  `include "tb_common.svh"
  localparam int W = 8, D = 8;
  logic clk = 0, rst, push, pop, full, empty;
  logic [W-1:0] din, dout;
  logic [$clog2(D):0] count;
  logic [W-1:0] q[$];     // model: kolejka SystemVerilog
  fifo #(.WIDTH(W), .DEPTH(D)) dut (.*);
  always #5 clk = ~clk;

  task automatic check_state(input string when);
    `CHECK_EQ(count, q.size(), {"count ", when})
    `CHECK_EQ(empty, q.size() == 0, {"empty ", when})
    `CHECK_EQ(full, q.size() == D, {"full ", when})
    if (q.size() > 0) `CHECK_EQ(dout, q[0], {"dout ", when})
  endtask

  initial begin
    tb_start();
    rst = 1; push = 0; pop = 0; din = 0;
    @(negedge clk);
    rst = 0;
    #1 check_state("po resecie");

    // napełnij do pełna (z próbą nadmiarowego zapisu), potem opróżnij
    for (int i = 0; i < D + 2; i++) begin
      push = 1; din = 8'h10 + i[7:0];
      @(negedge clk);
      if (q.size() < D) q.push_back(8'h10 + i[7:0]);
      check_state($sformatf("po push %0d", i));
    end
    push = 0;
    for (int i = 0; i < D + 2; i++) begin
      pop = 1;
      @(negedge clk);
      if (q.size() > 0) void'(q.pop_front());
      check_state($sformatf("po pop %0d", i));
    end
    pop = 0;

    // losowo
    repeat (3000) begin
      push = $urandom; pop = $urandom; din = $urandom;
      @(negedge clk);
      begin
        bit can_pop, can_push;
        can_pop  = pop && q.size() > 0;
        can_push = push && q.size() < D;
        if (can_pop)  void'(q.pop_front());
        if (can_push) q.push_back(din);
      end
      check_state("losowo");
    end
    tb_finish();
  end
endmodule
