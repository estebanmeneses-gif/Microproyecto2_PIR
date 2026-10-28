-- =============================================================================
-- Archivo      : rom_memory.vhd
-- Proyecto     : Microproyecto 2 - Registro de Presencia con ROM/RAM y sensor PIR
--
-- Descripcion  :
--   Memoria ROM sincrona de 16 x 8 bits con los CODIGOS DE IDENTIFICACION
--   de evento predefinidos. Cada vez que el PIR detecta presencia, la FSM
--   lee el siguiente codigo y lo guarda en la RAM.
--   Lectura sincrona: con en = '1', el dato de "addr" aparece en "data_out"
--   despues del siguiente flanco de subida (latencia de 1 ciclo).
--   Quartus la infiere en un bloque M9K del Cyclone III.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pkg_system.all;

entity rom_memory is
  port (
    clk      : in  std_logic;   -- Reloj de 50 MHz
    en       : in  std_logic;   -- Habilitacion de lectura
    addr     : in  addr_t;      -- Direccion (4 bits)
    data_out : out data_t       -- Codigo leido (8 bits)
  );
end entity rom_memory;

architecture rtl of rom_memory is

  -- Codigos de identificacion de evento (contenido fijo)
  constant ROM_CONTENT : rom_array_t := (
     0 => x"A1",   1 => x"B2",   2 => x"C3",   3 => x"D4",
     4 => x"E5",   5 => x"F6",   6 => x"07",   7 => x"18",
     8 => x"29",   9 => x"3A",  10 => x"4B",  11 => x"5C",
    12 => x"6D",  13 => x"7E",  14 => x"8F",  15 => x"90"
  );

  signal q_reg : data_t := (others => '0');

begin

  p_read : process (clk)
  begin
    if rising_edge(clk) then
      if en = '1' then
        q_reg <= ROM_CONTENT(to_integer(unsigned(addr)));
      end if;
    end if;
  end process p_read;

  data_out <= q_reg;

end architecture rtl;
