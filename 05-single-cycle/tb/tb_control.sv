`timescale 1ns/1ps
// Wektory w tb/control_vectors.txt wygenerował asembler. Linia:
//   <instrukcja> <oczekiwane sygnały> <maska "obchodzi nas"> <mnemonik>
// Sygnały spakowane jako (od najstarszego bitu):
//   reg_write, wb_sel[1:0], alu_a_sel[1:0], alu_b_imm, alu_op[3:0],
//   mem_read, mem_write, branch, jump, jump_reg, illegal
// Bity spoza maski to "don't care" (np. wb_sel dla store).
module tb_control;
  import rv32i_pkg::*;
  `include "tb_common.svh"
  logic [31:0] instr;
  logic        reg_write, alu_b_imm, mem_read, mem_write, branch, jump, jump_reg, illegal;
  logic [1:0]  wb_sel, alu_a_sel;
  logic [3:0]  alu_op;
  logic [15:0] got, exp_v, care;
  string       name;
  int          fd;
  control dut (.*);
  assign got = {reg_write, wb_sel, alu_a_sel, alu_b_imm, alu_op, mem_read, mem_write, branch, jump, jump_reg, illegal};

  function automatic string fields(input logic [15:0] v, input logic [15:0] m);
    string s, n;
    s = "";
    if (m[15])    s = {s, $sformatf("reg_write=%0d ", v[15])};
    if (m[14:13]) s = {s, $sformatf("wb_sel=%0d ", v[14:13])};
    if (m[12:11]) s = {s, $sformatf("alu_a_sel=%0d ", v[12:11])};
    if (m[10])    s = {s, $sformatf("alu_b_imm=%0d ", v[10])};
    if (m[9:6])   s = {s, $sformatf("alu_op=%b ", v[9:6])};
    if (m[5])     s = {s, $sformatf("mem_read=%0d ", v[5])};
    if (m[4])     s = {s, $sformatf("mem_write=%0d ", v[4])};
    if (m[3])     s = {s, $sformatf("branch=%0d ", v[3])};
    if (m[2])     s = {s, $sformatf("jump=%0d ", v[2])};
    if (m[1])     s = {s, $sformatf("jump_reg=%0d ", v[1])};
    if (m[0])     s = {s, $sformatf("illegal=%0d", v[0])};
    return s;
  endfunction

  initial begin
    tb_start();
    fd = $fopen("tb/control_vectors.txt", "r");
    if (fd == 0) begin
      $display("FAIL: brak tb/control_vectors.txt");
      $finish(0);
    end
    while ($fscanf(fd, "%h %h %h %s\n", instr, exp_v, care, name) == 4) begin
      #1;
      tb_checks++;
      if ((got & care) !== (exp_v & care)) begin
        tb_errors++;
        if (tb_errors <= 15) begin
          $display("BŁĄD %s (0x%08h):", name, instr);
          $display("     jest:      %s", fields(got & care, care));
          $display("     oczekiwano: %s", fields(exp_v, care));
        end
      end
    end
    $fclose(fd);
    tb_finish();
  end
endmodule
