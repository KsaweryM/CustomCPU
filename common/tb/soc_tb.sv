// ---------------------------------------------------------------------------
// soc_tb — "komputer" wokół Twojego rdzenia: pamięć, urządzenia MMIO, zegar,
// reset, ślad wykonania i wykrywanie końca programu.
//
// Używany w modułach 05–08. Moduł rdzenia MUSI nazywać się `core` i mieć
// dokładnie te porty (opis w 05-single-cycle/README.md):
//
//   clk, rst,
//   imem_addr, imem_rdata,
//   dmem_addr, dmem_re, dmem_rdata, dmem_wstrb, dmem_wdata,
//   commit_valid, commit_pc, commit_instr, commit_rd, commit_rd_val
//
// Pamięć (64 KiB od adresu 0) ma ODCZYT KOMBINACYJNY (asynchroniczny)
// i zapis na zboczu narastającym zegara. Port instrukcji i port danych
// widzą tę samą pamięć.
//
// Plusargi:
//   +hex=plik.hex      program do załadowania (wymagany)
//   +trace=plik.txt    zapisz ślad wykonanych instrukcji (commit trace)
//   +wave=plik.vcd     zapisz przebiegi dla GTKWave
//   +timeout=N         limit cykli (domyślnie 1000000)
//   +quiet             nie wypisuj nic poza wynikiem
// ---------------------------------------------------------------------------
`timescale 1ns/1ps

module soc_tb;
  import rv32i_pkg::*;

  localparam int MEM_WORDS = RAM_SIZE / 4;

  // ---- zegar i reset --------------------------------------------------------
  logic clk = 1'b0;
  logic rst = 1'b1;
  always #5 clk = ~clk;

  // ---- sygnały rdzenia ------------------------------------------------------
  logic [31:0] imem_addr, imem_rdata;
  logic [31:0] dmem_addr, dmem_rdata, dmem_wdata;
  logic        dmem_re;
  logic [3:0]  dmem_wstrb;
  logic        commit_valid;
  logic [31:0] commit_pc, commit_instr, commit_rd_val;
  logic [4:0]  commit_rd;

  core dut (.*);

  // ---- pamięć ---------------------------------------------------------------
  logic [31:0] mem [0:MEM_WORDS-1];
  logic [63:0] cycles  = 0;
  logic [63:0] instret = 0;

  wire imem_in_ram = imem_addr < RAM_SIZE;
  wire dmem_in_ram = dmem_addr < RAM_SIZE;

  assign imem_rdata = imem_in_ram ? mem[imem_addr[15:2]] : 32'hDEAD_BEEF;
  assign dmem_rdata = dmem_in_ram                  ? mem[dmem_addr[15:2]] :
                      (dmem_addr == MMIO_CYCLES)   ? cycles[31:0]         :
                                                     32'hDEAD_BEEF;

  // ---- stan testu -------------------------------------------------------------
  int   trace_fd = 0;
  bit   quiet = 0;
  bit   done = 0;
  int   drain = 0;
  logic [31:0] tohost_val;
  longint timeout = 1000000;
  logic [31:0] last_pc = 32'hx;
  int          idle = 0;          // takty od ostatniego commitu

  task automatic finish_sim();
    real cpi;
    cpi = (instret == 0) ? 0.0 : real'(cycles) / real'(instret);
    if (trace_fd) $fclose(trace_fd);
    if (tohost_val == 32'd1)
      $display("PASS  cycles=%0d instret=%0d CPI=%0.3f", cycles, instret, cpi);
    else
      $display("FAIL: podtest %0d (gp=%0d)  cycles=%0d instret=%0d",
               tohost_val >> 1, tohost_val >> 1, cycles, instret);
    $finish(0);
  endtask

  task automatic fail_now(input string why);
    if (trace_fd) $fclose(trace_fd);
    $display("FAIL: %s  (cycles=%0d, ostatni commit pc=0x%08h)", why, cycles, last_pc);
    $finish(0);
  endtask

  // ---- zapisy do pamięci i MMIO -----------------------------------------------
  always @(posedge clk) begin
    if (!rst && !done && dmem_wstrb != 4'b0000) begin
      if ($isunknown(dmem_addr) || $isunknown(dmem_wstrb))
        fail_now("zapis pod adres X (niezainicjowany sygnał w rdzeniu?)");
      else if (dmem_in_ram) begin
        for (int i = 0; i < 4; i++)
          if (dmem_wstrb[i]) mem[dmem_addr[15:2]][8*i +: 8] <= dmem_wdata[8*i +: 8];
      end else if (dmem_addr == MMIO_TOHOST) begin
        tohost_val = dmem_wdata;
        done = 1;            // pozwól dokończyć instrukcje w potoku
      end else if (dmem_addr == MMIO_PUTCHAR) begin
        if (!quiet) $write("%c", dmem_wdata[7:0]);
        $fflush();
      end else
        fail_now($sformatf("zapis pod nieobsługiwany adres 0x%08h", dmem_addr));
    end
  end

  // ---- liczniki, ślad wykonania, timeout ----------------------------------------
  always @(posedge clk) begin
    if (!rst) begin
      cycles <= cycles + 1;
      if ($isunknown(commit_valid))
        fail_now("commit_valid = X");
      idle = commit_valid ? 0 : idle + 1;
      if (idle == 1000)
        fail_now("przez 1000 taktów żadna instrukcja się nie zakończyła (commit_valid = 0) — potok stoi?");
      if (commit_valid) begin
        instret <= instret + 1;
        last_pc = commit_pc;
        if (commit_pc >= RAM_SIZE)
          fail_now($sformatf("wykonano instrukcję spoza RAM (pc=0x%08h)", commit_pc));
        if (commit_instr == 32'h0)
          fail_now($sformatf("wykonano słowo 0x00000000 pod pc=0x%08h (skok w dane albo pustą pamięć?)", commit_pc));
        if (trace_fd) begin
          if (commit_rd != 5'd0)
            $fdisplay(trace_fd, "%08h %08h x%0d=%08h", commit_pc, commit_instr, commit_rd, commit_rd_val);
          else
            $fdisplay(trace_fd, "%08h %08h -", commit_pc, commit_instr);
        end
      end
      if (cycles == 4 && $isunknown(imem_addr))
        fail_now("imem_addr (PC) = X po resecie");
      if (done) begin
        drain++;
        if (drain == 8) finish_sim();
      end
      if (cycles >= timeout)
        fail_now($sformatf("TIMEOUT po %0d cyklach (program się zapętlił albo nie dotarł do pass/fail)", timeout));
    end
  end

  // ---- inicjalizacja ----------------------------------------------------------
  initial begin
    string hex, trace, wave;
    int fd, n;
    logic [31:0] w;

    for (int i = 0; i < MEM_WORDS; i++) mem[i] = 32'h0;

    quiet = $test$plusargs("quiet");
    void'($value$plusargs("timeout=%d", timeout));

    if (!$value$plusargs("hex=%s", hex)) begin
      $display("FAIL: brak +hex=plik.hex");
      $finish(0);
    end
    fd = $fopen(hex, "r");
    if (fd == 0) begin
      $display("FAIL: nie mogę otworzyć %s", hex);
      $finish(0);
    end
    n = 0;
    while (!$feof(fd) && n < MEM_WORDS) begin
      if ($fscanf(fd, "%h\n", w) == 1) begin
        mem[n] = w;
        n++;
      end else
        void'($fgetc(fd));
    end
    $fclose(fd);

    if ($value$plusargs("trace=%s", trace)) begin
      trace_fd = $fopen(trace, "w");
    end
    if ($value$plusargs("wave=%s", wave)) begin
      $dumpfile(wave);
      $dumpvars(0, soc_tb);
    end

    // reset przez 3 cykle; zdejmujemy go na zboczu opadającym,
    // żeby nie ścigać się z logiką taktowaną zboczem narastającym
    repeat (3) @(posedge clk);
    @(negedge clk) rst = 1'b0;
  end

endmodule
