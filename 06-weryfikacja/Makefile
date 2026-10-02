# Moduł 06 nie ma własnego RTL — weryfikujesz rdzeń z modułu 05 (domyślnie)
# albo potokowy z modułu 08:   make cosim CORE=08
COMMON    := ../common
CORE      ?= 05
SRCS      := ../03-alu-regfile/rtl/alu.sv ../03-alu-regfile/rtl/regfile.sv \
             ../03-alu-regfile/rtl/branch_cmp.sv ../04-isa-emulator/rtl/imm_gen.sv \
             ../05-single-cycle/rtl/control.sv ../05-single-cycle/rtl/lsu.sv
ifeq ($(CORE),08)
CORE_SRCS := $(SRCS) ../08-pipeline/rtl/core.sv
else
CORE_SRCS := $(SRCS) ../05-single-cycle/rtl/core.sv
endif
BUILD     := build/core$(CORE)
LINT_TOPS := core

test: cosim fuzz
include $(COMMON)/mk/rules.mk
