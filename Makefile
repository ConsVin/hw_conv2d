SIM ?= verilator
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES += $(PWD)/window_buffer.sv \
					$(PWD)/window_buffer_v2.sv \
				  $(PWD)/kernel_1b_nxor.sv \
				  $(PWD)/conv2d_binary.sv 

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = conv2d_binary

# MODULE is the basename of the Python test file
MODULE = test_conv2d_binary
# Trace all
EXTRA_ARGS = --trace --trace-structs

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim