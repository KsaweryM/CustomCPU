// ZADANIE 8 — 5-etapowy potok RV32I:  IF -> ID -> EX -> MEM -> WB
//
// Interfejs IDENTYCZNY jak w module 05 (ten sam soc_tb, te same testy).
// Pracuj etapami (szczegóły w README.md):
//
//   8.1  Rejestry potoku + flush przy skoku.         make progs PAD=4
//   8.2  Forwarding EX/MEM->EX i MEM/WB->EX,
//        bypass zapisu WB w etapie ID.               make progs PAD=1
//   8.3  Stall przy load-use.                         make progs   (PAD=0)
//   8.4  make cosim && make fuzz N=200
//   8.5  Pomiary: CPI, make synth T=core — porównaj z modułem 05
//
// Konwencje, których trzyma się ten szkielet (możesz je zmienić):
//   * prefiks sygnału = etap, w którym "żyje":  d_* (ID), e_* (EX), m_* (MEM), w_* (WB)
//   * każdy etap ma bit *_valid; bańka (bubble) = valid 0 i wszystkie
//     sygnały z efektami ubocznymi (reg_write, mem_write, branch, jump...) = 0
//   * skoki (branch/jal/jalr) rozstrzygane w EX: redirect -> nowe pc,
//     unieważnij instrukcje w IF/ID i ID/EX (2 takty kary)
//   * commit_* wystawiasz z etapu WB (commit_valid = w_valid)
module core import rv32i_pkg::*; (
  input  logic        clk,
  input  logic        rst,
  output logic [31:0] imem_addr,
  input  logic [31:0] imem_rdata,
  output logic [31:0] dmem_addr,
  output logic        dmem_re,
  input  logic [31:0] dmem_rdata,
  output logic [3:0]  dmem_wstrb,
  output logic [31:0] dmem_wdata,
  output logic        commit_valid,
  output logic [31:0] commit_pc,
  output logic [31:0] commit_instr,
  output logic [4:0]  commit_rd,
  output logic [31:0] commit_rd_val
);

  // ============================ IF ============================
  // TODO: pc, wybór następnego pc (pc+4 / redirect z EX / wstrzymanie przy stall)
  // TODO: rejestr IF/ID: d_valid, d_pc, d_instr

  // ============================ ID ============================
  // TODO: control, imm_gen, regfile (zapis z WB!)
  // TODO: bypass: jeśli WB zapisuje rejestr, który ID właśnie czyta — weź nową wartość
  // TODO: wykrywanie load-use (stall)
  // TODO: rejestr ID/EX

  // ============================ EX ============================
  // TODO: forwarding operandów, ALU, branch_cmp, redirect
  // TODO: rejestr EX/MEM

  // ============================ MEM ===========================
  // TODO: lsu, dmem_*
  // TODO: rejestr MEM/WB

  // ============================ WB ============================
  // TODO: commit_*

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
