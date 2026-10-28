-- =============================================================================
-- Archivo      : pir_controller.vhd
-- Proyecto     : Microproyecto 2 - Registro de Presencia con ROM/RAM y sensor PIR
--
-- Descripcion  :
--   Acondicionamiento de la senal digital del sensor PIR HC-SR501.
--   La senal llega de forma ASINCRONA y puede traer ruido/rebotes por el
--   cableado, por lo que se procesa en tres etapas:
--
--   1) Sincronizador de G_SYNC_STAGES flip-flops (3 por defecto):
--      evita metaestabilidad al pasar la senal al dominio de 50 MHz.
--   2) Filtro digital por estabilidad (anti-rebote):
--      un cambio solo se acepta si la entrada permanece en el nuevo valor
--      durante G_FILTER_CYCLES ciclos consecutivos (20 ms por defecto).
--      Cualquier pulso o glitch mas corto se descarta.
--   3) Detector de flanco de subida:
--      genera un pulso limpio de UN solo ciclo de reloj (pir_pulse) cuando
--      la senal filtrada pasa de '0' a '1'. Asi, un solo movimiento produce
--      un solo registro aunque el sensor mantenga su salida en alto varios
--      segundos.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pkg_system.all;

entity pir_controller is
  generic (
    G_SYNC_STAGES   : positive := SYNC_STAGES;        -- Etapas del sincronizador (>= 2)
    G_FILTER_CYCLES : positive := PIR_FILTER_CYCLES   -- Ciclos de estabilidad exigidos
  );
  port (
    clk       : in  std_logic;   -- Reloj de 50 MHz
    rst       : in  std_logic;   -- Reset sincrono activo en alto
    pir_in    : in  std_logic;   -- Salida fisica del sensor PIR (asincrona)
    pir_level : out std_logic;   -- Nivel filtrado (para LED indicador)
    pir_pulse : out std_logic    -- Pulso de 1 ciclo por cada deteccion
  );
end entity pir_controller;

architecture rtl of pir_controller is

  -- Cadena del sincronizador multi-etapa
  signal sync_reg : std_logic_vector(G_SYNC_STAGES-1 downto 0) := (others => '0');
  signal pir_sync : std_logic;

  -- Filtro por estabilidad
  signal filt_cnt : natural range 0 to G_FILTER_CYCLES := 0;
  signal pir_filt : std_logic := '0';

  -- Detector de flanco
  signal pir_filt_d : std_logic := '0';
  signal pulse_reg  : std_logic := '0';

  -- Indica a Quartus que la cadena es un sincronizador (analisis de MTBF)
  attribute altera_attribute : string;
  attribute altera_attribute of sync_reg : signal is "-name SYNCHRONIZER_IDENTIFICATION ""FORCED IF ASYNCHRONOUS""";

begin

  -- ---------------------------------------------------------------------------
  -- Etapa 1: sincronizador de G_SYNC_STAGES flip-flops
  -- ---------------------------------------------------------------------------
  p_sync : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        sync_reg <= (others => '0');
      else
        sync_reg <= sync_reg(G_SYNC_STAGES-2 downto 0) & pir_in;
      end if;
    end if;
  end process p_sync;

  pir_sync <= sync_reg(G_SYNC_STAGES-1);

  -- ---------------------------------------------------------------------------
  -- Etapa 2: filtro anti-rebote / anti-ruido por estabilidad
  -- ---------------------------------------------------------------------------
  p_filter : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        filt_cnt <= 0;
        pir_filt <= '0';
      elsif pir_sync /= pir_filt then
        -- La entrada difiere del valor aceptado: contar estabilidad
        if filt_cnt = G_FILTER_CYCLES-1 then
          pir_filt <= pir_sync;   -- Cambio confirmado
          filt_cnt <= 0;
        else
          filt_cnt <= filt_cnt + 1;
        end if;
      else
        -- Volvio al valor aceptado antes de tiempo: era un glitch
        filt_cnt <= 0;
      end if;
    end if;
  end process p_filter;

  -- ---------------------------------------------------------------------------
  -- Etapa 3: detector de flanco de subida -> pulso de 1 ciclo
  -- ---------------------------------------------------------------------------
  p_edge : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        pir_filt_d <= '0';
        pulse_reg  <= '0';
      else
        pir_filt_d <= pir_filt;
        pulse_reg  <= pir_filt and (not pir_filt_d);
      end if;
    end if;
  end process p_edge;

  pir_level <= pir_filt;
  pir_pulse <= pulse_reg;

end architecture rtl;
