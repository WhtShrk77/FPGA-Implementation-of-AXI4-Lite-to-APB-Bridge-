create_clock -period 15.000 -name sys_clk -waveform {0.000 7.500} [get_ports clk]

set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports resetn]
set_property IOSTANDARD LVCMOS33 [get_ports {s_axi_*}]

set_property PACKAGE_PIN E3 [get_ports clk]
set_property PACKAGE_PIN C12 [get_ports resetn]

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

set_false_path -from [get_ports resetn] -to [all_registers]
set_clock_uncertainty -setup 0.100 [get_clocks sys_clk]
set_clock_uncertainty -hold 0.050 [get_clocks sys_clk]