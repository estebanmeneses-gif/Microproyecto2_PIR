#!/usr/bin/env bash
# Compila y simula el proyecto con GHDL (https://github.com/ghdl/ghdl)
# Uso: ./sim/run_ghdl.sh    (desde la carpeta raiz del proyecto)
set -e
cd "$(dirname "$0")/.."
mkdir -p sim/out && cd sim/out
FLAGS="--std=93c --ieee=standard"
ghdl -a $FLAGS ../../rtl/pkg_system.vhd ../../rtl/reset_sync.vhd ../../rtl/pir_controller.vhd \
     ../../rtl/rom_memory.vhd ../../rtl/ram_memory.vhd ../../rtl/control_unit.vhd \
     ../../rtl/hex7seg.vhd ../../rtl/display_unit.vhd ../../rtl/top_system.vhd \
     ../tb_pir_controller.vhd ../tb_top_system.vhd
ghdl -e $FLAGS tb_pir_controller
ghdl -r $FLAGS tb_pir_controller --vcd=tb_pir_controller.vcd
ghdl -e $FLAGS tb_top_system
ghdl -r $FLAGS tb_top_system --vcd=tb_top_system.vcd
