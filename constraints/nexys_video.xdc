# Nexys Video xc7a200tsbg484-1
# ddr3 pins vivado/mig
# clk ddr3 bank
# rst active-high btnC
# sw on VADJ

set_property PACKAGE_PIN R4 [get_ports clk]
set_property IOSTANDARD LVCMOS15 [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

set_property PACKAGE_PIN B22 [get_ports rst]
set_property IOSTANDARD LVCMOS12 [get_ports rst]

set_property PACKAGE_PIN V18 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]
set_property PACKAGE_PIN AA19 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]

set_property PACKAGE_PIN E22 [get_ports {sw[0]}]
set_property IOSTANDARD LVCMOS12 [get_ports {sw[0]}]
set_property PACKAGE_PIN F21 [get_ports {sw[1]}]
set_property IOSTANDARD LVCMOS12 [get_ports {sw[1]}]
set_property PACKAGE_PIN G21 [get_ports {sw[2]}]
set_property IOSTANDARD LVCMOS12 [get_ports {sw[2]}]
set_property PACKAGE_PIN G22 [get_ports {sw[3]}]
set_property IOSTANDARD LVCMOS12 [get_ports {sw[3]}]
set_property PACKAGE_PIN H17 [get_ports {sw[4]}]
set_property IOSTANDARD LVCMOS12 [get_ports {sw[4]}]
set_property PACKAGE_PIN J16 [get_ports {sw[5]}]
set_property IOSTANDARD LVCMOS12 [get_ports {sw[5]}]
set_property PACKAGE_PIN K13 [get_ports {sw[6]}]
set_property IOSTANDARD LVCMOS12 [get_ports {sw[6]}]
set_property PACKAGE_PIN M17 [get_ports {sw[7]}]
set_property IOSTANDARD LVCMOS12 [get_ports {sw[7]}]

set_property PACKAGE_PIN T14 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS25 [get_ports {led[0]}]
set_property PACKAGE_PIN T15 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS25 [get_ports {led[1]}]
set_property PACKAGE_PIN T16 [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS25 [get_ports {led[2]}]
set_property PACKAGE_PIN U16 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports {led[3]}]
set_property PACKAGE_PIN V15 [get_ports {led[4]}]
set_property IOSTANDARD LVCMOS25 [get_ports {led[4]}]
set_property PACKAGE_PIN W16 [get_ports {led[5]}]
set_property IOSTANDARD LVCMOS25 [get_ports {led[5]}]
set_property PACKAGE_PIN W15 [get_ports {led[6]}]
set_property IOSTANDARD LVCMOS25 [get_ports {led[6]}]
set_property PACKAGE_PIN Y13 [get_ports {led[7]}]
set_property IOSTANDARD LVCMOS25 [get_ports {led[7]}]

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
