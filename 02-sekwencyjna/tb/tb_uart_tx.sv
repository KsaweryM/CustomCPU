`timescale 1ns/1ps
module tb_uart_tx;
  `include "tb_common.svh"
  localparam int CPB = 4;
  logic clk = 0, rst, start, tx, busy;
  logic [7:0] data, got;
  int t_start, t_end;
  uart_tx #(.CLKS_PER_BIT(CPB)) dut (.*);
  always #5 clk = ~clk;

  // Odbiornik "programowy": czeka na bit startu, próbkuje w połowie bitów.
  task automatic receive(output logic [7:0] b, output bit stop_ok);
    while (tx !== 1'b0) @(posedge clk);
    repeat (CPB / 2) @(posedge clk);
    `CHECK_EQ(tx, 1'b0, "bit startu w połowie")
    for (int i = 0; i < 8; i++) begin
      repeat (CPB) @(posedge clk);
      b[i] = tx;
    end
    repeat (CPB) @(posedge clk);
    stop_ok = (tx === 1'b1);
  endtask

  initial begin
    bit stop_ok;
    tb_start();
    rst = 1; start = 0; data = 0;
    repeat (2) @(negedge clk);
    rst = 0;
    @(negedge clk);
    `CHECK_EQ(tx, 1'b1, "linia w spoczynku = 1")
    `CHECK_EQ(busy, 1'b0, "busy w spoczynku")

    for (int k = 0; k < 20; k++) begin
      data = (k == 0) ? 8'h55 : (k == 1) ? 8'h00 : (k == 2) ? 8'hFF : $urandom;
      @(negedge clk);
      start = 1;
      @(negedge clk);
      start = 0;
      t_start = $time;
      `CHECK_EQ(busy, 1'b1, "busy po start")
      fork
        receive(got, stop_ok);
        begin
          // start w trakcie nadawania musi być zignorowany
          repeat (3 * CPB) @(negedge clk);
          start = 1; data = ~data;
          @(negedge clk);
          start = 0;
        end
      join
      `CHECK_EQ(got, (k == 0) ? 8'h55 : (k == 1) ? 8'h00 : (k == 2) ? 8'hFF : ~data, "odebrany bajt")
      `CHECK(stop_ok, "bit stopu = 1")
      while (busy) @(negedge clk);
      t_end = $time;
      `CHECK_EQ((t_end - t_start) / 10, 10 * CPB, "czas trwania ramki (takty busy)")
      `CHECK_EQ(tx, 1'b1, "linia wraca do 1")
    end
    tb_finish();
  end
endmodule
