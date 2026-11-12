library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pkg_system.all;

entity rom_memory is
  port (
  --ENTRADAS
    clk      : in  std_logic;   -- Reloj
    en       : in  std_logic;   -- Habilitacion de lectura
    addr     : in  addr_t;      -- Direccion
  --SALIDA 
    data_out : out data_t       -- Codigo leido 
  );
end entity rom_memory;

architecture rtl of rom_memory is

  -- Codigos de identificacion de evento
  constant ROM_CONTENT : rom_array_t := (
     0 => x"A1",   1 => x"B2",   2 => x"C3",   3 => x"D4",
     4 => x"E5",   5 => x"F6",   6 => x"07",   7 => x"18",
     8 => x"29",   9 => x"3A",  10 => x"4B",  11 => x"5C",
    12 => x"6D",  13 => x"7E",  14 => x"8F",  15 => x"90"
  );

  -- Registro de salida 
  signal q_reg : data_t := (others => '0');

begin

  -- Lectura sincrona
  --en = 1 carga el codigo de addr
  p_read : process (clk)
  begin
    if rising_edge(clk) then
      if en = '1' then   -- Habilitacion dada por la FSM 
        q_reg <= ROM_CONTENT(to_integer(unsigned(addr)));   -- addr (4 bits)
      end if;
    end if;
  end process p_read;
  data_out <= q_reg;

end architecture rtl;
