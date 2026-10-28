-- =============================================================================
-- Archivo      : display_unit.vhd
-- Proyecto     : Microproyecto 2 - Registro de Presencia con ROM/RAM y sensor PIR
--
-- Descripcion  :
--   Unidad de lectura y visualizacion del contenido de la RAM.
--
--   Seleccion de direccion de lectura de la RAM:
--     view_mode = '0' (SW9 abajo) : MODO EN VIVO  -> muestra el ultimo
--                                   evento registrado (last_addr).
--     view_mode = '1' (SW9 arriba): MODO CONSULTA -> muestra la posicion
--                                   elegida con SW3..SW0.
--
--   Displays (activos en bajo):
--     HEX3 : direccion de la RAM que se esta mostrando (0..F)
--     HEX2 : codigo de estado de la FSM (0=IDLE 1=READ_ROM 2=WAIT_ROM
--            3=WRITE_RAM 4=INC_ADDR)
--     HEX1 : nibble alto del dato leido de la RAM
--     HEX0 : nibble bajo del dato leido de la RAM
--   En modo en vivo, mientras no exista ningun registro, HEX1/HEX0 muestran "--".
--
--   LEDs verdes:
--     LEDG0   : salida filtrada del PIR (presencia actual)
--     LEDG1   : destello de ~250 ms por cada evento registrado
--     LEDG2   : RAM llena (ya se escribieron las 16 posiciones)
--     LEDG3   : modo consulta activo
--     LEDG9..4: contador de eventos (6 bits menos significativos, binario)
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pkg_system.all;

entity display_unit is
  generic (
    G_STRETCH_CYCLES : positive := LED_STRETCH_CYCLES   -- Duracion del destello LEDG1
  );
  port (
    clk         : in  std_logic;
    rst         : in  std_logic;
    -- Seleccion de vista
    view_mode   : in  std_logic;
    sw_addr     : in  addr_t;
    -- Informacion de la unidad de control
    last_addr   : in  addr_t;
    has_data    : in  std_logic;
    ram_full    : in  std_logic;
    event_count : in  std_logic_vector(7 downto 0);
    state_code  : in  std_logic_vector(2 downto 0);
    -- Informacion del PIR
    pir_level   : in  std_logic;
    pir_pulse   : in  std_logic;
    -- Puerto de lectura de la RAM
    ram_rd_addr : out addr_t;
    ram_rd_data : in  data_t;
    -- Salidas fisicas
    hex0        : out std_logic_vector(6 downto 0);
    hex1        : out std_logic_vector(6 downto 0);
    hex2        : out std_logic_vector(6 downto 0);
    hex3        : out std_logic_vector(6 downto 0);
    ledg        : out std_logic_vector(9 downto 0)
  );
end entity display_unit;

architecture rtl of display_unit is

  signal rd_addr_s   : addr_t;
  signal data_dash   : std_logic;
  signal stretch_cnt : natural range 0 to G_STRETCH_CYCLES := 0;
  signal event_led   : std_logic;
  signal state_nib   : std_logic_vector(3 downto 0);

begin

  -- Multiplexor de direccion de lectura (combinacional, sin latches)
  rd_addr_s   <= sw_addr when view_mode = '1' else last_addr;
  ram_rd_addr <= rd_addr_s;

  -- Guion en los datos si estamos en vivo y aun no hay registros
  data_dash <= '1' when (view_mode = '0' and has_data = '0') else '0';

  state_nib <= '0' & state_code;

  -- Decodificadores de 7 segmentos
  u_hex0 : entity work.hex7seg
    port map (hex => ram_rd_data(3 downto 0), dash => data_dash, blank => '0', seg => hex0);
  u_hex1 : entity work.hex7seg
    port map (hex => ram_rd_data(7 downto 4), dash => data_dash, blank => '0', seg => hex1);
  u_hex2 : entity work.hex7seg
    port map (hex => state_nib, dash => '0', blank => '0', seg => hex2);
  u_hex3 : entity work.hex7seg
    port map (hex => rd_addr_s, dash => data_dash, blank => '0', seg => hex3);

  -- Estirador de pulso para que el evento sea visible en LEDG1
  p_stretch : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        stretch_cnt <= 0;
      elsif pir_pulse = '1' then
        stretch_cnt <= G_STRETCH_CYCLES;
      elsif stretch_cnt /= 0 then
        stretch_cnt <= stretch_cnt - 1;
      end if;
    end if;
  end process p_stretch;

  event_led <= '1' when stretch_cnt /= 0 else '0';

  ledg(0)          <= pir_level;
  ledg(1)          <= event_led;
  ledg(2)          <= ram_full;
  ledg(3)          <= view_mode;
  ledg(9 downto 4) <= event_count(5 downto 0);

end architecture rtl;
