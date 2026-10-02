// ZADANIE 5.1 — dekoder instrukcji / jednostka sterująca.
//
// Wejście: słowo instrukcji. Wyjście: sygnały sterujące ścieżką danych.
// Pełna tabela jest w README.md (sekcja "Tabela sterowania") — wypełnij ją
// najpierw na kartce, potem przepisz na kod.
//
//   reg_write  1 = zapisz wynik do rd
//   wb_sel     co zapisać do rd: WB_ALU (wynik ALU), WB_MEM (dana z load), WB_PC4 (pc+4)
//   alu_a_sel  operand A ALU: A_RS1, A_PC (auipc), A_ZERO (lui)
//   alu_b_imm  operand B ALU: 0 = rs2, 1 = immediate
//   alu_op     operacja ALU (ALU_*); dla OP_REG = {instr[30], funct3}
//              UWAGA na OP_IMM: instr[30] jest częścią immediate'a, liczy się
//              tylko dla srai (funct3 = 101); addi z ujemną stałą to NIE sub!
//   mem_read   load        mem_write  store
//   branch     instrukcja B-type (czy skok wykonać, decyduje branch_cmp)
//   jump       jal         jump_reg   jalr
//   illegal    nieznany opcode (FENCE i SYSTEM to nie błąd: traktuj jak nop)
//
// Zasada bezpieczeństwa: dla każdej instrukcji, która czegoś NIE robi,
// sygnały reg_write / mem_write / branch / jump / jump_reg muszą być 0.
// Najprościej: na początku always_comb ustaw wszystkie wartości domyślne.
module control import rv32i_pkg::*; (
  input  logic [31:0] instr,
  output logic        reg_write,
  output logic [1:0]  wb_sel,
  output logic [1:0]  alu_a_sel,
  output logic        alu_b_imm,
  output logic [3:0]  alu_op,
  output logic        mem_read,
  output logic        mem_write,
  output logic        branch,
  output logic        jump,
  output logic        jump_reg,
  output logic        illegal
);
  // TODO
  assign reg_write = 1'b0;
  assign wb_sel    = WB_ALU;
  assign alu_a_sel = A_RS1;
  assign alu_b_imm = 1'b0;
  assign alu_op    = ALU_ADD;
  assign mem_read  = 1'b0;
  assign mem_write = 1'b0;
  assign branch    = 1'b0;
  assign jump      = 1'b0;
  assign jump_reg  = 1'b0;
  assign illegal   = 1'b0;
endmodule
