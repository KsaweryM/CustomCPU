`timescale 1ns/1ps
module tb_lsu;
  import rv32i_pkg::*;
  `include "tb_common.svh"
  logic [31:0] addr, store_data, dmem_wdata, dmem_rdata, load_data;
  logic [2:0]  funct3;
  logic        mem_write;
  logic [3:0]  dmem_wstrb, exp_strb;
  logic [31:0] exp_load, sh;
  lsu dut (.*);
  initial begin
    tb_start();
    for (int i = 0; i < 6000; i++) begin
      funct3 = (i % 6 == 0) ? F3_B : (i % 6 == 1) ? F3_H : (i % 6 == 2) ? F3_W :
               (i % 6 == 3) ? F3_BU : (i % 6 == 4) ? F3_HU : F3_B;
      addr = $urandom;
      if (funct3[1:0] == 2'b01) addr[0] = 1'b0;     // wyrównane półsłowa
      if (funct3[1:0] == 2'b10) addr[1:0] = 2'b00;  // wyrównane słowa
      store_data = $urandom;
      dmem_rdata = $urandom;
      mem_write = $urandom;

      // --- zapis: sprawdzamy tylko bajty, które faktycznie są zapisywane
      if (funct3 == F3_B || funct3 == F3_H || funct3 == F3_W) begin
        exp_strb = (funct3 == F3_B) ? 4'b0001 << addr[1:0] :
                   (funct3 == F3_H) ? 4'b0011 << addr[1:0] : 4'b1111;
        if (!mem_write) exp_strb = 4'b0000;
        #1;
        `CHECK_EQ(dmem_wstrb, exp_strb, $sformatf("wstrb: funct3=%b addr[1:0]=%0d mem_write=%0d", funct3, addr[1:0], mem_write))
        for (int k = 0; k < 4; k++)
          if (exp_strb[k])
            `CHECK_EQ(dmem_wdata[8*k +: 8], (store_data << (8 * addr[1:0])) >> (8 * k) & 8'hFF,
                      $sformatf("wdata bajt %0d: funct3=%b addr[1:0]=%0d", k, funct3, addr[1:0]))
      end

      // --- odczyt
      sh = dmem_rdata >> (8 * addr[1:0]);
      case (funct3)
        F3_B:  exp_load = {{24{sh[7]}}, sh[7:0]};
        F3_H:  exp_load = {{16{sh[15]}}, sh[15:0]};
        F3_W:  exp_load = dmem_rdata;
        F3_BU: exp_load = {24'b0, sh[7:0]};
        default: exp_load = {16'b0, sh[15:0]};
      endcase
      #1;
      `CHECK_EQ(load_data, exp_load, $sformatf("load: funct3=%b addr[1:0]=%0d rdata=%h", funct3, addr[1:0], dmem_rdata))
    end
    tb_finish();
  end
endmodule
