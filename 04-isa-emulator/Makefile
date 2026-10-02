COMMON     := ../common
SRCS       := rtl/imm_gen.sv
UNIT_TESTS := imm_gen

test: unit emu-test
include $(COMMON)/mk/rules.mk

# ---------------------------------------------------------------- emulator (zadanie 4.3)
CC       ?= gcc
CFLAGS   ?= -O2 -g -Wall -Wextra
EMU_BIN  := $(BUILD)/rv32sim
TESTS_DIR := $(COMMON)/sw/tests
EMU_PROGS := $(sort $(patsubst $(TESTS_DIR)/%.S,%,$(wildcard $(TESTS_DIR)/[0-9]*.S)))

.PHONY: emu emu-test emu-test-m

emu: $(EMU_BIN)

$(EMU_BIN): emu/rv32sim.c | $(BUILD)
	$(CC) $(CFLAGS) -o $@ $<

$(BUILD)/hex/%.hex: $(TESTS_DIR)/%.S $(TESTS_DIR)/test_end.S $(TOOLS)/rvtool.py
	@mkdir -p $(BUILD)/hex
	@$(PYTHON) $(TOOLS)/rvtool.py asm $< -I $(TESTS_DIR) -o $@ -l $(BUILD)/hex/$*.lst

# make emu-test            wszystkie programy z common/sw/tests
# make emu-test P=08_fib   jeden program, z wyjściem i śladem w build/08_fib.trace
emu-test: $(EMU_BIN) $(addprefix $(BUILD)/hex/,$(addsuffix .hex,$(EMU_PROGS)))
ifeq ($(P),)
	@fail=0; for p in $(EMU_PROGS); do \
	  out=$$($(EMU_BIN) $(BUILD)/hex/$$p.hex -q 2>&1 | tail -1); \
	  if echo "$$out" | grep -q '^PASS'; then printf "  $(GREEN)PASS$(RST)  %-14s $(DIM)%s$(RST)\n" $$p "$$out"; \
	  else printf "  $(RED)FAIL$(RST)  %-14s %s\n" $$p "$$out"; fail=1; fi; \
	done; exit $$fail
else
	@$(EMU_BIN) $(BUILD)/hex/$(P).hex -t $(BUILD)/$(P).trace
	@echo "   ślad: $(BUILD)/$(P).trace    listing: $(BUILD)/hex/$(P).lst"
endif

# Opcjonalnie (moduł 09): rozszerzenie M
emu-test-m: $(EMU_BIN)
	@mkdir -p $(BUILD)/hex
	@$(PYTHON) $(TOOLS)/rvtool.py asm $(COMMON)/sw/tests_m/m_ext.S -I $(TESTS_DIR) -o $(BUILD)/hex/m_ext.hex
	@$(EMU_BIN) $(BUILD)/hex/m_ext.hex -q
