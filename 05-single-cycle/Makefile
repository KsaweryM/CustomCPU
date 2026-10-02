COMMON     := ../common
# Twoje moduły z poprzednich lekcji + nowe z tej
PREV       := ../03-alu-regfile/rtl/alu.sv ../03-alu-regfile/rtl/regfile.sv \
              ../03-alu-regfile/rtl/branch_cmp.sv ../04-isa-emulator/rtl/imm_gen.sv
SRCS       := $(PREV) rtl/control.sv rtl/lsu.sv
CORE_SRCS  := $(SRCS) rtl/core.sv
UNIT_TESTS := control lsu
LINT_TOPS  := control lsu core

test: unit progs
include $(COMMON)/mk/rules.mk
