library ieee;
use ieee.std_logic_1164.all;
use work.pkg_system.all;

entity hex7seg is
  port (
  --ENTRADAS
  
    hex   : in  std_logic_vector(3 downto 0);  -- Digito hexadecimal
    dash  : in  std_logic;                     -- '1' -> muestra "-"
    blank : in  std_logic;                     -- '1' -> display apagado
	 
 --SALIDA
    seg   : out std_logic_vector(6 downto 0)   -- gfedcba, activo en bajo
  );
end entity hex7seg;

architecture rtl of hex7seg is
begin
  seg <= SEG_BLANK when blank = '1' else                -- si blank esta en 1 apaga todo el display
         SEG_DASH  when dash  = '1' else                -- si no y el dash esta en 1 muestra un guion
         hex_to_7seg(hex);                              -- si ninguno esta activo muestra el digito hexadecimal normal
end architecture rtl;
