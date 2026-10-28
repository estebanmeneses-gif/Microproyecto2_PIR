-- =============================================================================
-- Archivo      : reset_sync.vhd
-- Proyecto     : Microproyecto 2 - Registro de Presencia con ROM/RAM y sensor PIR
--
-- Descripcion  :
--   Acondiciona el pulsador de reinicio de la DE0 (BUTTON0, activo en BAJO).
--   1) Invierte la polaridad: rst = '1' cuando el boton esta presionado.
--   2) Sincroniza la senal con dos flip-flops al reloj de 50 MHz para que
--      todos los registros del sistema usen un reset SINCRONO y limpio.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;

entity reset_sync is
  port (
    clk   : in  std_logic;   -- Reloj de 50 MHz
    rst_n : in  std_logic;   -- Pulsador fisico (activo en bajo)
    rst   : out std_logic    -- Reset interno sincronizado (activo en alto)
  );
end entity reset_sync;

architecture rtl of reset_sync is
  signal ff1 : std_logic := '1';
  signal ff2 : std_logic := '1';
begin

  process (clk)
  begin
    if rising_edge(clk) then
      ff1 <= not rst_n;   -- Boton presionado (0) -> reset activo (1)
      ff2 <= ff1;
    end if;
  end process;

  rst <= ff2;

end architecture rtl;
