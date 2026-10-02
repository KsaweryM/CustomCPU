// ZADANIE 3.2 — bank rejestrów x0..x31: 2 porty odczytu, 1 port zapisu.
//
//   * odczyt KOMBINACYJNY: rs1_val = x[rs1], rs2_val = x[rs2]
//   * zapis na zboczu narastającym clk, gdy we = 1: x[rd] = rd_val
//   * x0 zawsze czyta się jako 0, a zapis do x0 jest ignorowany
//   * odczyt w tym samym takcie co zapis pod ten sam adres zwraca STARĄ
//     wartość (nowa pojawi się po zboczu) — nie dodawaj tu "bypassu"
//   * rejestry x1..x31 zainicjuj zerami blokiem `initial` (patrz README:
//     dlaczego to w porządku na FPGA/w symulacji, ale nie w ASIC)
module regfile (
  input  logic        clk,
  input  logic [4:0]  rs1,
  input  logic [4:0]  rs2,
  output logic [31:0] rs1_val,
  output logic [31:0] rs2_val,
  input  logic        we,
  input  logic [4:0]  rd,
  input  logic [31:0] rd_val
);
  // TODO
  assign rs1_val = 32'd0;
  assign rs2_val = 32'd0;
endmodule
