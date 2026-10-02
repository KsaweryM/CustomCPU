// ZADANIE 5.2 — jednostka load/store (LSU): dopasowanie bajtów do pamięci.
//
// Pamięć jest zorganizowana w 32-bitowe słowa. Adres słowa to addr[31:2],
// a addr[1:0] mówi, które bajty słowa nas interesują (little-endian:
// bajt pod adresem 4k+0 to bity [7:0] słowa, 4k+3 to bity [31:24]).
//
// ZAPIS (store) — funct3: F3_B (sb), F3_H (sh), F3_W (sw)
//   dmem_wstrb[i] = 1  -> pamięć zapisze bajt i słowa (bity 8i+7 : 8i)
//   dmem_wdata         -> dana ustawiona na właściwych bajtach
//   Przykład: sb x5, 2(x0) -> wstrb = 4'b0100, wdata[23:16] = x5[7:0]
//   Gdy mem_write = 0: wstrb = 0 (nic nie zapisujemy).
//   Zakładamy wyrównane dostępy (sh pod adres parzysty, sw pod podzielny przez 4).
//
// ODCZYT (load) — dmem_rdata to CAŁE słowo spod adresu addr & ~3
//   load_data = właściwy bajt / półsłowo przesunięte na pozycję 0
//               i rozszerzone znakiem (lb, lh) albo zerami (lbu, lhu); lw: całe słowo
module lsu import rv32i_pkg::*; (
  input  logic [31:0] addr,
  input  logic [2:0]  funct3,
  input  logic        mem_write,
  input  logic [31:0] store_data,   // rs2
  output logic [31:0] dmem_wdata,
  output logic [3:0]  dmem_wstrb,
  input  logic [31:0] dmem_rdata,
  output logic [31:0] load_data
);
  // TODO
  assign dmem_wdata = 32'd0;
  assign dmem_wstrb = 4'b0000;
  assign load_data  = 32'd0;
endmodule
