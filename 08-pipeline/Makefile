# Moduł 08: 5-etapowy potok. Używa Twoich modułów z 03–05, ale własnego core.sv.
#
#   make progs PAD=4    etap 8.1 (bez forwardingu i stalli: 4 nop-y między instrukcjami)
#   make progs PAD=1    etap 8.2 (z forwardingiem, bez stalla load-use)
#   make progs          etap 8.3 (pełny potok)
#   make cosim / make fuzz N=100      porównanie z emulatorem
#   make synth T=core   porównaj z: make -C ../05-single-cycle synth T=core
COMMON     := ../common
SRCS       := ../03-alu-regfile/rtl/alu.sv ../03-alu-regfile/rtl/regfile.sv \
              ../03-alu-regfile/rtl/branch_cmp.sv ../04-isa-emulator/rtl/imm_gen.sv \
              ../05-single-cycle/rtl/control.sv ../05-single-cycle/rtl/lsu.sv
CORE_SRCS  := $(SRCS) rtl/core.sv
LINT_TOPS  := core

test: progs cosim
include $(COMMON)/mk/rules.mk
