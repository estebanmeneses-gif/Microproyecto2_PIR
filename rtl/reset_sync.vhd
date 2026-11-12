library ieee;
use ieee.std_logic_1164.all;

entity reset_sync is
  port (
  --ENTRADAS
    clk   : in  std_logic;   -- Reloj
    rst_n : in  std_logic;   -- Pulsador fisico
  --SALIDA 
    rst   : out std_logic    -- Reset interno
  );
end entity reset_sync;

architecture rtl of reset_sync is
  -- Flip-flops del sincronizador del reset
  signal ff1 : std_logic := '1';
  signal ff2 : std_logic := '1';
begin

  -- Sincronizador de 2 etapas al reloj
  process (clk)
  begin
    if rising_edge(clk) then
      ff1 <= not rst_n;   -- Boton presionado 0 Y reset activo 1
      ff2 <= ff1;         -- Segunda etapa: reduce el riesgo de metaestabilidad
    end if;
  end process;

  -- Reset interno sincronizado
  rst <= ff2;

end architecture rtl;
