# ---------------------------------------------------------------------------
# rules.mk — wspólne reguły dla Makefile'i modułów kursu.
#
# Makefile modułu ustawia:
#   COMMON      ścieżka do katalogu common/
#   SRCS        pliki RTL modułu (i modułów, z których korzysta)
#   UNIT_TESTS  nazwy testów jednostkowych: tb/tb_<nazwa>.sv
#   LINT_TOPS   moduły do sprawdzenia `make lint` (domyślnie = UNIT_TESTS)
# a dla modułów z procesorem dodatkowo:
#   CORE_SRCS   pliki RTL rdzenia (moduł `core`)
#
# Cele:
#   make unit              wszystkie testy jednostkowe (albo T=nazwa)
#   make wave T=nazwa      test jednostkowy + GTKWave
#   make lint              Verilator --lint-only dla LINT_TOPS
#   make synth T=moduł     synteza Yosysem: liczba bramek i najdłuższa ścieżka
#   make progs             wszystkie programy z common/sw/tests na Twoim rdzeniu
#   make prog P=08_fib     jeden program, z wyjściem i śladem (build/08_fib.trace)
#   make wave P=08_fib     program + GTKWave
#   make cosim             porównanie śladu z emulatorem (moduł 04) dla programów
#   make fuzz N=50         losowe programy (rvgen) + porównanie z emulatorem
#   make clean
# Zmienne:
#   PAD=4                  wstaw 4 nop-y przed każdą instrukcją programów
#   SIM=verilator          programy symuluj Verilatorem zamiast Icarusa
# ---------------------------------------------------------------------------

BUILD    ?= build
PKG      := $(COMMON)/rtl/rv32i_pkg.sv
TOOLS    := $(COMMON)/tools
IVERILOG := iverilog -g2012 -Wall -Wno-timescale -I$(COMMON)/tb
VVP      := vvp -n
PYTHON   := python3
LINT_TOPS ?= $(UNIT_TESTS)
ALL_RTL  = $(sort $(SRCS) $(CORE_SRCS))
T ?=
P ?=
PAD ?= 0
SIM ?= icarus

GREEN := \033[32m
RED   := \033[31m
DIM   := \033[2m
RST   := \033[0m

.PHONY: unit wave lint synth progs prog cosim fuzz clean vsim emu-bin
.SECONDARY:

$(BUILD):
	@mkdir -p $@

# ---------------------------------------------------------------- testy jednostkowe
$(BUILD)/tb_%.vvp: tb/tb_%.sv $(SRCS) $(PKG) $(COMMON)/tb/tb_common.svh | $(BUILD)
	@$(IVERILOG) -s tb_$* -o $@ $(PKG) $(SRCS) $< 2> $(BUILD)/tb_$*.compile.log || \
	  { grep -v "sorry: constant selects" $(BUILD)/tb_$*.compile.log; rm -f $@; exit 1; }

UNIT_RUN := $(if $(T),$(T),$(UNIT_TESTS))

unit: | $(BUILD)
	@fail=0; for t in $(UNIT_RUN); do \
	  if ! $(MAKE) -s --no-print-directory $(BUILD)/tb_$$t.vvp > $(BUILD)/tb_$$t.log 2>&1; then \
	    printf "  $(RED)BŁĄD KOMPILACJI$(RST)  %s\n" $$t; sed 's/^/      /' $(BUILD)/tb_$$t.log | head -20; fail=1; continue; \
	  fi; \
	  out=$$($(VVP) $(BUILD)/tb_$$t.vvp 2>&1); \
	  if echo "$$out" | grep -q '^PASS'; then \
	    printf "  $(GREEN)PASS$(RST)  %-14s $(DIM)%s$(RST)\n" $$t "$$(echo "$$out" | grep '^PASS')"; \
	  else \
	    printf "  $(RED)FAIL$(RST)  %s\n" $$t; echo "$$out" | grep -v '^PASS' | head -25 | sed 's/^/      /'; fail=1; \
	  fi; \
	done; exit $$fail

lint:
	@for m in $(LINT_TOPS); do \
	  printf "== lint: %s\n" $$m; \
	  verilator --lint-only -Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
	    -Wno-PINCONNECTEMPTY $(PKG) $(ALL_RTL) --top-module $$m && echo "   OK"; \
	done

synth: | $(BUILD)
	@test -n "$(T)" || { echo "Podaj moduł: make synth T=nazwa_modułu"; exit 1; }
	@$(PYTHON) $(TOOLS)/yosys_prep.py -o $(BUILD)/synth_in.sv $(PKG) $(ALL_RTL)
	@yosys -q -l $(BUILD)/synth_$(T).log -p "read_verilog -sv $(BUILD)/synth_in.sv; \
	  synth -flatten -top $(T); tee -o $(BUILD)/synth_$(T).stat stat; \
	  tee -o $(BUILD)/synth_$(T).ltp ltp -noff" > /dev/null 2>&1 || { tail -20 $(BUILD)/synth_$(T).log; exit 1; }
	@sed -n '/Number of wires/,$$p' $(BUILD)/synth_$(T).stat
	@grep -i "longest topological path" $(BUILD)/synth_$(T).ltp | sed 's/^/   /'
	@echo "   (pełny raport: $(BUILD)/synth_$(T).log)"

# ---------------------------------------------------------------- procesor + programy
ifneq ($(strip $(CORE_SRCS)),)

TESTS_DIR := $(COMMON)/sw/tests
ALL_PROGS := $(sort $(patsubst $(TESTS_DIR)/%.S,%,$(wildcard $(TESTS_DIR)/[0-9]*.S)))
PROGS     ?= $(ALL_PROGS)
HEXDIR    := $(BUILD)/hex$(if $(filter-out 0,$(PAD)),-pad$(PAD))
SOC_VVP   := $(BUILD)/soc.vvp
VSOC      := $(BUILD)/vl/vsoc
SIMBIN    := $(if $(filter verilator,$(SIM)),$(VSOC),$(VVP) $(SOC_VVP))
SIMDEP    := $(if $(filter verilator,$(SIM)),$(VSOC),$(SOC_VVP))

$(SOC_VVP): $(CORE_SRCS) $(PKG) $(COMMON)/tb/soc_tb.sv | $(BUILD)
	@$(IVERILOG) -s soc_tb -o $@ $(PKG) $(CORE_SRCS) $(COMMON)/tb/soc_tb.sv 2> $(BUILD)/soc.compile.log || \
	  { grep -v "sorry: constant selects" $(BUILD)/soc.compile.log; rm -f $@; exit 1; }

$(VSOC): $(CORE_SRCS) $(PKG) $(COMMON)/tb/soc_tb.sv | $(BUILD)
	@echo "Verilator: kompilacja symulatora (kilka sekund)..."
	@verilator --binary --timing -j 0 -O2 -Wno-fatal -Wno-lint -Wno-style --top-module soc_tb \
	  -Mdir $(BUILD)/vl -o vsoc $(PKG) $(CORE_SRCS) $(COMMON)/tb/soc_tb.sv > $(BUILD)/vl.log 2>&1 || \
	  { tail -30 $(BUILD)/vl.log; exit 1; }

vsim: $(VSOC)

$(HEXDIR)/%.hex: $(TESTS_DIR)/%.S $(TESTS_DIR)/test_end.S $(TOOLS)/rvtool.py
	@mkdir -p $(HEXDIR)
	@$(PYTHON) $(TOOLS)/rvtool.py asm $< -I $(TESTS_DIR) --pad-nops $(PAD) -o $@ -l $(HEXDIR)/$*.lst

progs: $(SIMDEP) $(addprefix $(HEXDIR)/,$(addsuffix .hex,$(PROGS)))
	@fail=0; for p in $(PROGS); do \
	  out=$$($(SIMBIN) +hex=$(HEXDIR)/$$p.hex +quiet 2>&1 | grep -E '^(PASS|FAIL)'); \
	  if echo "$$out" | grep -q '^PASS'; then printf "  $(GREEN)PASS$(RST)  %-14s $(DIM)%s$(RST)\n" $$p "$$out"; \
	  else printf "  $(RED)FAIL$(RST)  %-14s %s\n" $$p "$$out"; fail=1; fi; \
	done; exit $$fail

prog: $(SIMDEP)
	@test -n "$(P)" || { echo "Podaj program: make prog P=08_fib"; exit 1; }
	@$(MAKE) -s --no-print-directory $(HEXDIR)/$(P).hex
	@$(SIMBIN) +hex=$(HEXDIR)/$(P).hex +trace=$(BUILD)/$(P).trace | grep -v '\$$finish'
	@echo "   ślad: $(BUILD)/$(P).trace    listing: $(HEXDIR)/$(P).lst"

ifneq ($(P),)
wave: $(SOC_VVP)
	@$(MAKE) -s --no-print-directory $(HEXDIR)/$(P).hex
	@$(VVP) $(SOC_VVP) +hex=$(HEXDIR)/$(P).hex +wave=$(BUILD)/$(P).vcd +quiet | grep -E '^(PASS|FAIL)'
	@echo "   przebiegi: $(BUILD)/$(P).vcd"
	@gtkwave $(BUILD)/$(P).vcd > /dev/null 2>&1 &
endif

# ---- weryfikacja względem emulatora z modułu 04
EMU_DIR := $(COMMON)/../04-isa-emulator
EMU     := $(EMU_DIR)/build/rv32sim
COSIM_SKIP ?= 12_mmio

emu-bin:
	@$(MAKE) -s --no-print-directory -C $(EMU_DIR) emu BUILD=build

cosim: emu-bin $(SIMDEP) $(addprefix $(HEXDIR)/,$(addsuffix .hex,$(PROGS)))
	@fail=0; for p in $(filter-out $(COSIM_SKIP),$(PROGS)); do \
	  if ! $(EMU) $(HEXDIR)/$$p.hex -q -t $(BUILD)/$$p.ref.trace > $(BUILD)/$$p.emu.log 2>&1; then \
	    printf "  $(RED)EMULATOR$(RST) %-14s %s\n" $$p "$$(tail -1 $(BUILD)/$$p.emu.log) — najpierw popraw emulator (moduł 04)"; fail=1; continue; fi; \
	  $(SIMBIN) +hex=$(HEXDIR)/$$p.hex +quiet +trace=$(BUILD)/$$p.trace > /dev/null 2>&1; \
	  if out=$$($(PYTHON) $(TOOLS)/tracecmp.py $(BUILD)/$$p.ref.trace $(BUILD)/$$p.trace); then \
	    printf "  $(GREEN)ZGODNE$(RST)   %-14s $(DIM)%s$(RST)\n" $$p "$$out"; \
	  else printf "  $(RED)RÓŻNICA$(RST)  %s\n" $$p; echo "$$out" | sed 's/^/      /'; fail=1; fi; \
	done; exit $$fail

N    ?= 20
SEED ?= 1
LEN  ?= 300
FUZZ_FLAGS ?=
FUZZDIR := $(BUILD)/fuzz

fuzz: emu-bin $(SIMDEP)
	@mkdir -p $(FUZZDIR)
	@fail=0; ok=0; for i in $$(seq $(SEED) $$(($(SEED) + $(N) - 1))); do \
	  f=$(FUZZDIR)/r$$i; \
	  $(PYTHON) $(TOOLS)/rvgen.py --seed $$i -n $(LEN) $(FUZZ_FLAGS) -o $$f.S && \
	  $(PYTHON) $(TOOLS)/rvtool.py asm $$f.S -I $(TESTS_DIR) --pad-nops $(PAD) -o $$f.hex -l $$f.lst || exit 1; \
	  if ! $(EMU) $$f.hex -q -t $$f.ref.trace > $$f.emu.log 2>&1; then \
	    echo "  emulator nie przeszedł programu $$f.S: $$(tail -1 $$f.emu.log) — popraw emulator (moduł 04)"; exit 1; fi; \
	  $(SIMBIN) +hex=$$f.hex +quiet +trace=$$f.trace > /dev/null 2>&1; \
	  if out=$$($(PYTHON) $(TOOLS)/tracecmp.py $$f.ref.trace $$f.trace); then ok=$$((ok+1)); \
	  else printf "  $(RED)RÓŻNICA$(RST)  seed=%s  (program: %s.S, listing: %s.lst)\n" $$i $$f $$f; \
	    echo "$$out" | sed 's/^/      /'; fail=$$((fail+1)); [ $$fail -ge 3 ] && break; fi; \
	done; \
	printf "fuzz: $(GREEN)%d zgodnych$(RST), $(RED)%d różnych$(RST)\n" $$ok $$fail; [ $$fail -eq 0 ]

endif

# ---------------------------------------------------------------- przebiegi testu jednostkowego
ifeq ($(P),)
wave:
	@test -n "$(T)" || { echo "Podaj test: make wave T=nazwa  (albo P=program)"; exit 1; }
	@$(MAKE) -s --no-print-directory $(BUILD)/tb_$(T).vvp
	@$(VVP) $(BUILD)/tb_$(T).vvp +wave=$(BUILD)/$(T).vcd | grep -E '^(PASS|FAIL|BŁĄD)' | head -5
	@echo "   przebiegi: $(BUILD)/$(T).vcd"
	@gtkwave $(BUILD)/$(T).vcd > /dev/null 2>&1 &
endif

clean:
	rm -rf $(BUILD)
