`timescale 1ns/1ps
// Wektory w tb/imm_vectors.txt wygenerował asembler (common/tools/rvtool.py):
// każda linia to "<instrukcja> <oczekiwany immediate>".
module tb_imm_gen;
  `include "tb_common.svh"
  logic [31:0] instr, imm, exp_imm;
  int fd, n;
  imm_gen dut (.*);
  initial begin
    tb_start();
    fd = $fopen("tb/imm_vectors.txt", "r");
    if (fd == 0) begin
      $display("FAIL: brak pliku tb/imm_vectors.txt (uruchamiaj z katalogu modułu)");
      $finish(0);
    end
    n = 0;
    while ($fscanf(fd, "%h %h\n", instr, exp_imm) == 2) begin
      #1;
      `CHECK_EQ(imm, exp_imm, $sformatf("instr=%h (opcode %b)", instr, instr[6:0]))
      n++;
    end
    $fclose(fd);
    `CHECK(n > 100, "wczytano wektory testowe")
    tb_finish();
  end
endmodule
