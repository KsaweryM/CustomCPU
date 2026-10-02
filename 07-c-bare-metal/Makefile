# Moduł 07: programy w C na Twoim procesorze.
#
#   make                    kompiluje wszystkie programy z prog/ do build/*.hex
#   make emu P=hello        uruchamia na emulatorze (moduł 04)
#   make run P=hello        uruchamia na Twoim rdzeniu (CORE=05 albo CORE=08)
#   make dis P=hello        disasembler (co naprawdę wygenerował kompilator)
#   make test               hello + muldiv_test + bench na emulatorze i na rdzeniu
#
# Toolchain jest wykrywany automatycznie:
#   1) riscv64-unknown-elf-gcc   (sudo apt install gcc-riscv64-unknown-elf)
#   2) clang + ld.lld            (sudo apt install lld; clang już masz)
COMMON := ../common
CORE   ?= 05
ARCH   ?= rv32i
BUILD  := build
PROGS  := $(patsubst prog/%.c,%,$(wildcard prog/*.c))
P      ?= hello

GCC_PREFIX ?= riscv64-unknown-elf-
ifneq ($(shell command -v $(GCC_PREFIX)gcc 2>/dev/null),)
  CC      := $(GCC_PREFIX)gcc
  RVLD    := $(GCC_PREFIX)ld
  OBJCOPY := $(GCC_PREFIX)objcopy
  OBJDUMP := $(GCC_PREFIX)objdump
  ARCHFLAGS := -march=$(ARCH) -mabi=ilp32 -msmall-data-limit=0
else
  CC      := clang --target=riscv32-unknown-elf
  find_tool = $(firstword $(shell for t in $(1); do command -v $$t; done 2>/dev/null) $(firstword $(1)))
  RVLD    ?= $(call find_tool,ld.lld ld.lld-18)
  OBJCOPY := $(call find_tool,llvm-objcopy llvm-objcopy-18)
  OBJDUMP := $(call find_tool,llvm-objdump llvm-objdump-18)
  ARCHFLAGS := -march=$(ARCH) -mabi=ilp32
endif

CFLAGS  := $(ARCHFLAGS) -O2 -g -mno-relax -ffreestanding -fno-builtin -nostdlib \
           -fno-pic -Wall -Wextra -Ilib
LDFLAGS := -m elf32lriscv -T link.ld --no-relax -nostdlib
LIBOBJS := $(BUILD)/crt0.o $(BUILD)/rt.o $(BUILD)/muldiv.o

SOC_DIR := ../06-weryfikacja
EMU     := ../04-isa-emulator/build/rv32sim

.PHONY: all emu run dis test clean check-tools
.SECONDARY:

all: check-tools $(addprefix $(BUILD)/,$(addsuffix .hex,$(PROGS)))

check-tools:
	@command -v $(firstword $(CC)) > /dev/null || { echo "Brak kompilatora: $(CC)"; exit 1; }
	@command -v $(RVLD) > /dev/null || { echo "Brak linkera $(RVLD). Zainstaluj: sudo apt install lld  (albo gcc-riscv64-unknown-elf)"; exit 1; }

$(BUILD):
	@mkdir -p $@

$(BUILD)/crt0.o: crt0.S | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@
$(BUILD)/%.o: lib/%.c lib/rt.h | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@
$(BUILD)/prog_%.o: prog/%.c lib/rt.h | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/%.elf: $(BUILD)/prog_%.o $(LIBOBJS) link.ld
	$(RVLD) $(LDFLAGS) -o $@ $(LIBOBJS) $<

$(BUILD)/%.hex: $(BUILD)/%.elf
	@$(OBJCOPY) -O binary $< $(BUILD)/$*.bin
	@python3 $(COMMON)/tools/rvtool.py bin2hex $(BUILD)/$*.bin -o $@
	@$(OBJDUMP) -d $< > $(BUILD)/$*.dis
	@printf "  %-12s %6d bajtów kodu+danych\n" $* $$(stat -c %s $(BUILD)/$*.bin)

emu: check-tools $(BUILD)/$(P).hex
	@$(MAKE) -s --no-print-directory -C ../04-isa-emulator emu BUILD=build
	@$(EMU) $(BUILD)/$(P).hex -t $(BUILD)/$(P).emu.trace

run: check-tools $(BUILD)/$(P).hex
	@$(MAKE) -s --no-print-directory -C $(SOC_DIR) CORE=$(CORE) build/core$(CORE)/soc.vvp
	@vvp -n $(SOC_DIR)/build/core$(CORE)/soc.vvp +hex=$(BUILD)/$(P).hex +trace=$(BUILD)/$(P).trace

dis: $(BUILD)/$(P).hex
	@less $(BUILD)/$(P).dis

test: all
	@$(MAKE) -s --no-print-directory -C ../04-isa-emulator emu BUILD=build
	@$(MAKE) -s --no-print-directory -C $(SOC_DIR) CORE=$(CORE) build/core$(CORE)/soc.vvp
	@fail=0; for p in hello muldiv_test bench; do \
	  e=$$($(EMU) $(BUILD)/$$p.hex -q | tail -1); \
	  r=$$(vvp -n $(SOC_DIR)/build/core$(CORE)/soc.vvp +hex=$(BUILD)/$$p.hex +quiet | grep -E '^(PASS|FAIL)'); \
	  printf "  %-12s emulator: %-28s rdzeń %s: %s\n" $$p "$$e" $(CORE) "$$r"; \
	  echo "$$e$$r" | grep -q FAIL && fail=1; \
	done; exit $$fail

clean:
	rm -rf $(BUILD)
