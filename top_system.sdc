# Restricciones de tiempo - reloj principal de 50 MHz de la DE0
create_clock -name clk -period 20.000 [get_ports {clk}]
derive_clock_uncertainty
# Entradas asincronas (se sincronizan internamente) y salidas lentas
set_false_path -from [get_ports {rst_n pir_in SW[*]}]
set_false_path -to   [get_ports {HEX* LEDG[*]}]
