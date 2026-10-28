-- =============================================================================
-- Archivo      : ram_memory.vhd
-- Proyecto     : Microproyecto 2 - Registro de Presencia con ROM/RAM y sensor PIR
--
-- Descripcion  :
--   Memoria RAM sincrona de doble puerto simple (16 x 8 bits):
--     * Puerto de ESCRITURA (we, wr_addr, data_in): lo usa la FSM para
--       guardar cada evento de presencia en posiciones consecutivas.
--     * Puerto de LECTURA (rd_addr, data_out): lo usa la unidad de
--       visualizacion para mostrar el contenido en los displays.
--   Ambas operaciones son sincronas al flanco de subida del reloj.
--   La lectura tiene latencia de 1 ciclo. Quartus la infiere en un M9K.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pkg_system.all;

entity ram_memory is
  port (
    clk      : in  std_logic;   -- Reloj de 50 MHz
    we       : in  std_logic;   -- Habilitacion de escritura
    wr_addr  : in  addr_t;      -- Direccion de escritura
    data_in  : in  data_t;      -- Dato a escribir
    rd_addr  : in  addr_t;      -- Direccion de lectura
    data_out : out data_t       -- Dato leido (registrado)
  );
end entity ram_memory;

architecture rtl of ram_memory is

  signal mem   : ram_array_t := (others => (others => '0'));
  signal q_reg : data_t := (others => '0');

  attribute ramstyle : string;
  attribute ramstyle of mem : signal is "M9K";

begin

  p_ram : process (clk)
  begin
    if rising_edge(clk) then
      if we = '1' then
        mem(to_integer(unsigned(wr_addr))) <= data_in;
      end if;
      q_reg <= mem(to_integer(unsigned(rd_addr)));
    end if;
  end process p_ram;

  data_out <= q_reg;

end architecture rtl;
