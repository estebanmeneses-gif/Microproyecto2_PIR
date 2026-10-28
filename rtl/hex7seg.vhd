-- =============================================================================
-- Archivo      : hex7seg.vhd
-- Proyecto     : Microproyecto 2 - Registro de Presencia con ROM/RAM y sensor PIR
--
-- Descripcion  :
--   Decodificador hexadecimal (0..F) a display de 7 segmentos activo en bajo
--   (displays HEX0..HEX3 de la DE0). Permite forzar un guion "-" o apagar.
--   Logica combinacional pura: todas las ramas asignan la salida (sin latches).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use work.pkg_system.all;

entity hex7seg is
  port (
    hex   : in  std_logic_vector(3 downto 0);  -- Digito hexadecimal
    dash  : in  std_logic;                     -- '1' -> muestra "-"
    blank : in  std_logic;                     -- '1' -> display apagado
    seg   : out std_logic_vector(6 downto 0)   -- gfedcba, activo en bajo
  );
end entity hex7seg;

architecture rtl of hex7seg is
begin
  seg <= SEG_BLANK when blank = '1' else
         SEG_DASH  when dash  = '1' else
         hex_to_7seg(hex);
end architecture rtl;
