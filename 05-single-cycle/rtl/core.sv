// ZADANIE 5.3 — jednocyklowy procesor RV32I.
//
// Każda instrukcja wykonuje się w jednym takcie zegara:
//   pc -> imem -> dekoder/rejestry/immediate -> ALU -> pamięć danych -> zapis do rd
//   oraz równolegle: obliczenie następnego pc.
// Schemat ścieżki danych i opis wszystkich portów: README.md.
//
// Użyj modułów, które już masz: control, regfile, imm_gen, alu, branch_cmp, lsu.
//
// Interfejs jest STAŁY — testbench (common/tb/soc_tb.sv) na nim polega:
//   * pamięć ma odczyt kombinacyjny: imem_rdata = mem[imem_addr] w tym samym takcie,
//   * zapis do pamięci danych następuje na zboczu clk, gdy dmem_wstrb != 0,
//   * po resecie (rst = 1, synchroniczny) pc = 0,
//   * commit_*: w każdym takcie, w którym instrukcja się "kończy", ustaw
//     commit_valid = 1 i opisz ją (pc, słowo instrukcji, rd i zapisana wartość;
//     commit_rd = 0, jeśli instrukcja nie zapisuje rejestru). W procesorze
//     jednocyklowym to po prostu bieżąca instrukcja w każdym takcie poza resetem.
module core import rv32i_pkg::*; (
  input  logic        clk,
  input  logic        rst,
  // pamięć instrukcji
  output logic [31:0] imem_addr,
  input  logic [31:0] imem_rdata,
  // pamięć danych
  output logic [31:0] dmem_addr,
  output logic        dmem_re,
  input  logic [31:0] dmem_rdata,
  output logic [3:0]  dmem_wstrb,
  output logic [31:0] dmem_wdata,
  // ślad wykonania (do weryfikacji)
  output logic        commit_valid,
  output logic [31:0] commit_pc,
  output logic [31:0] commit_instr,
  output logic [4:0]  commit_rd,
  output logic [31:0] commit_rd_val
);
  // TODO
  assign imem_addr     = 32'd0;
  assign dmem_addr     = 32'd0;
  assign dmem_re       = 1'b0;
  assign dmem_wstrb    = 4'b0000;
  assign dmem_wdata    = 32'd0;
  assign commit_valid  = 1'b0;
  assign commit_pc     = 32'd0;
  assign commit_instr  = 32'd0;
  assign commit_rd     = 5'd0;
  assign commit_rd_val = 32'd0;
endmodule
