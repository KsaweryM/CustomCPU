// ---------------------------------------------------------------------------
// tb_common.svh — wspólne makra i zadania dla testbenchy jednostkowych.
//
// Dołączaj WEWNĄTRZ modułu testbenchu:
//
//   module tb_foo;
//     `include "tb_common.svh"
//     initial begin
//       tb_start();
//       ...
//       `CHECK_EQ(y, 8'h42, "opis sprawdzenia")
//       ...
//       tb_finish();
//     end
//   endmodule
//
// Uruchomienie z +wave=plik.vcd zapisuje przebiegi do pliku (make wave).
// ---------------------------------------------------------------------------
int tb_errors = 0;
int tb_checks = 0;

`ifndef TB_COMMON_MACROS
`define TB_COMMON_MACROS
// Porównanie z !== : X i Z też są wykrywane jako błąd.
`define CHECK_EQ(got, exp, what) \
  begin \
    tb_checks++; \
    if ((got) !== (exp)) begin \
      tb_errors++; \
      if (tb_errors <= 20) \
        $display("BŁĄD [t=%0t] %s: jest 0x%0h, oczekiwano 0x%0h", $time, what, got, exp); \
    end \
  end
`define CHECK(cond, what) \
  begin \
    tb_checks++; \
    if (!(cond)) begin \
      tb_errors++; \
      if (tb_errors <= 20) $display("BŁĄD [t=%0t] %s", $time, what); \
    end \
  end
`endif

// Watchdog: test, który się zawiesi (np. czeka na sygnał, który nigdy nie
// nadejdzie), kończy się po TB_TIMEOUT jednostkach czasu jako FAIL.
`ifndef TB_TIMEOUT
`define TB_TIMEOUT 10_000_000
`endif
initial begin
  #(`TB_TIMEOUT);
  $display("FAIL: TIMEOUT — test się zawiesił (czeka na coś, co nie następuje?)");
  $finish(0);
end

task automatic tb_start();
  string f;
  if ($value$plusargs("wave=%s", f)) begin
    $dumpfile(f);
    $dumpvars;
  end
endtask

task automatic tb_finish();
  if (tb_errors == 0)
    $display("PASS (%0d sprawdzeń)", tb_checks);
  else
    $display("FAIL (%0d błędów na %0d sprawdzeń)", tb_errors, tb_checks);
  $finish(0);
endtask
