# test case of the asynchronous noc set up as a 4x4 configuration with swapped ports

test_tiled_4x4_swap: clean test_tiled_4x4_swap_setup async_rtl_asic noc_tiled
	$(PREFIX) vcom $(OPTIONS) $(TESTDIR)/bench/tiled_noc_tb.vhd
	$(PREFIX) vcom $(OPTIONS) $(SRCDIR)/noc/tiled/fake_entities/processor_traffic_generator.vhd
	$(PREFIX) vsim -t 10ps -voptargs=+acc -do $(TESTDIR)/testcases/netlist_tiled/tile_netlist_rtl.do tiled_noc_tb

test_tiled_4x4_swap_setup: work
	$(PREFIX) vcom $(OPTIONS) $(TESTDIR)/testcases/test_tiled_4x4_swap/config.vhd 

test_tiled_4x4_swap_description:
	@echo "test_tiled_4x4_swap "
	@echo "     testcase for a tiled 4x4 noc with swapped ports"
	@echo "     for better routeability"

# append this testcase to the list of active testcases
TESTCASE_LIST += test_tiled_4x4_swap
TESTCASE_DESCRIPTIONS += test_tiled_4x4_swap_description
