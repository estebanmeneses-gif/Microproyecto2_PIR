# Script de simulacion para ModelSim / Questa (Intel FPGA Edition)
# Uso: en la consola de ModelSim -> cd <carpeta del proyecto>  ;  do sim/run_modelsim.do
vlib work
vcom -93 rtl/pkg_system.vhd rtl/reset_sync.vhd rtl/pir_controller.vhd rtl/rom_memory.vhd \
         rtl/ram_memory.vhd rtl/control_unit.vhd rtl/hex7seg.vhd rtl/display_unit.vhd \
         rtl/top_system.vhd sim/tb_top_system.vhd
vsim -t ns work.tb_top_system
add wave -divider "Entradas"
add wave sim:/tb_top_system/clk sim:/tb_top_system/rst_n sim:/tb_top_system/pir_in
add wave -divider "PIR"
add wave sim:/tb_top_system/DUT/pir_level sim:/tb_top_system/DUT/pir_pulse
add wave -divider "FSM"
add wave sim:/tb_top_system/DUT/u_ctrl/state
add wave sim:/tb_top_system/DUT/rom_en -radix hex sim:/tb_top_system/DUT/rom_addr sim:/tb_top_system/DUT/rom_data
add wave sim:/tb_top_system/DUT/ram_we -radix hex sim:/tb_top_system/DUT/ram_wr_addr sim:/tb_top_system/DUT/ram_wr_data
add wave -divider "Visualizacion"
add wave -radix hex sim:/tb_top_system/SW sim:/tb_top_system/DUT/ram_rd_addr sim:/tb_top_system/DUT/ram_rd_data
add wave sim:/tb_top_system/HEX3_D sim:/tb_top_system/HEX2_D sim:/tb_top_system/HEX1_D sim:/tb_top_system/HEX0_D
add wave -radix unsigned sim:/tb_top_system/DUT/event_count
add wave sim:/tb_top_system/LEDG
run -all
wave zoom full
