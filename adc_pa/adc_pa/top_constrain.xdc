
create_clock -period 50.000 -name clk_input -add [get_ports clk_120_i]

set_property -dict {PACKAGE_PIN Y23 IOSTANDARD LVCMOS33} [get_ports clk_120_i]




# ADC LTC1407

set_property IOSTANDARD LVCMOS33 [get_ports adc_conv_o]
set_property PACKAGE_PIN V24 [get_ports adc_conv_o]

set_property IOSTANDARD LVCMOS33 [get_ports adc_sck_o]
set_property PACKAGE_PIN W24 [get_ports adc_sck_o]

set_property IOSTANDARD LVCMOS33 [get_ports adc_sdo_i]
set_property PACKAGE_PIN W25 [get_ports adc_sdo_i]

 