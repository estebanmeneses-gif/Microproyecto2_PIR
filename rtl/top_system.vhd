-- =============================================================================
-- Archivo      : top_system.vhd
-- Proyecto     : Microproyecto 2 - Registro de Presencia con ROM/RAM y sensor PIR
-- Tarjeta      : Terasic DE0 - Cyclone III EP3C16F484C6
--
-- Descripcion  :
--   Entidad de nivel superior (puramente ESTRUCTURAL). Interconecta:
--     reset_sync -> pir_controller -> control_unit <-> rom_memory
--                                                  <-> ram_memory
--                                     display_unit <-> ram_memory (lectura)
--   y los pines fisicos de la tarjeta.
--
--   Pines (ver top_system.qsf):
--     clk     : CLOCK_50  (PIN_G21)  oscilador principal de 50 MHz
--     rst_n   : BUTTON0   (PIN_H2)   pulsador, activo en BAJO
--     pir_in  : GPIO0_D0  (PIN_AB16) header GPIO0 (J4) pin 2
--     SW(9)   : modo consulta, SW(3..0): direccion a consultar
--     HEX0..3 : displays de 7 segmentos (activos en bajo)
--     LEDG    : indicadores
--
--   Todo el sistema trabaja con el MISMO reloj de 50 MHz (sin relojes
--   derivados) y con reset sincrono.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pkg_system.all;

entity top_system is
  generic (
    G_FILTER_CYCLES  : positive := PIR_FILTER_CYCLES;   -- 20 ms (se reduce en simulacion)
    G_STRETCH_CYCLES : positive := LED_STRETCH_CYCLES   -- 250 ms (se reduce en simulacion)
  );
  port (
    clk     : in  std_logic;                     -- CLOCK_50
    rst_n   : in  std_logic;                     -- BUTTON0 (activo en bajo)
    pir_in  : in  std_logic;                     -- Sensor PIR HC-SR501 (GPIO0_D0)
    SW      : in  std_logic_vector(9 downto 0);  -- Interruptores
    HEX0_D  : out std_logic_vector(6 downto 0);
    HEX1_D  : out std_logic_vector(6 downto 0);
    HEX2_D  : out std_logic_vector(6 downto 0);
    HEX3_D  : out std_logic_vector(6 downto 0);
    HEX0_DP : out std_logic;
    HEX1_DP : out std_logic;
    HEX2_DP : out std_logic;
    HEX3_DP : out std_logic;
    LEDG    : out std_logic_vector(9 downto 0)
  );
end entity top_system;

architecture structural of top_system is

  signal rst         : std_logic;
  signal pir_level   : std_logic;
  signal pir_pulse   : std_logic;

  signal rom_en      : std_logic;
  signal rom_addr    : addr_t;
  signal rom_data    : data_t;

  signal ram_we      : std_logic;
  signal ram_wr_addr : addr_t;
  signal ram_wr_data : data_t;
  signal ram_rd_addr : addr_t;
  signal ram_rd_data : data_t;

  signal last_addr   : addr_t;
  signal has_data    : std_logic;
  signal ram_full    : std_logic;
  signal event_count : std_logic_vector(7 downto 0);
  signal state_code  : std_logic_vector(2 downto 0);

begin

  -- Reset: pulsador activo en bajo -> reset interno sincrono activo en alto
  u_rst : entity work.reset_sync
    port map (clk => clk, rst_n => rst_n, rst => rst);

  -- Acondicionamiento del sensor PIR
  u_pir : entity work.pir_controller
    generic map (G_SYNC_STAGES => SYNC_STAGES, G_FILTER_CYCLES => G_FILTER_CYCLES)
    port map (
      clk       => clk,
      rst       => rst,
      pir_in    => pir_in,
      pir_level => pir_level,
      pir_pulse => pir_pulse
    );

  -- Unidad de control (FSM)
  u_ctrl : entity work.control_unit
    port map (
      clk         => clk,
      rst         => rst,
      pir_pulse   => pir_pulse,
      rom_en      => rom_en,
      rom_addr    => rom_addr,
      rom_data    => rom_data,
      ram_we      => ram_we,
      ram_addr    => ram_wr_addr,
      ram_data    => ram_wr_data,
      last_addr   => last_addr,
      has_data    => has_data,
      ram_full    => ram_full,
      event_count => event_count,
      state_code  => state_code
    );

  -- Memoria ROM de codigos
  u_rom : entity work.rom_memory
    port map (clk => clk, en => rom_en, addr => rom_addr, data_out => rom_data);

  -- Memoria RAM de eventos
  u_ram : entity work.ram_memory
    port map (
      clk      => clk,
      we       => ram_we,
      wr_addr  => ram_wr_addr,
      data_in  => ram_wr_data,
      rd_addr  => ram_rd_addr,
      data_out => ram_rd_data
    );

  -- Lectura y visualizacion
  u_disp : entity work.display_unit
    generic map (G_STRETCH_CYCLES => G_STRETCH_CYCLES)
    port map (
      clk         => clk,
      rst         => rst,
      view_mode   => SW(9),
      sw_addr     => SW(3 downto 0),
      last_addr   => last_addr,
      has_data    => has_data,
      ram_full    => ram_full,
      event_count => event_count,
      state_code  => state_code,
      pir_level   => pir_level,
      pir_pulse   => pir_pulse,
      ram_rd_addr => ram_rd_addr,
      ram_rd_data => ram_rd_data,
      hex0        => HEX0_D,
      hex1        => HEX1_D,
      hex2        => HEX2_D,
      hex3        => HEX3_D,
      ledg        => LEDG
    );

  -- Puntos decimales apagados (activos en bajo)
  HEX0_DP <= '1';
  HEX1_DP <= '1';
  HEX2_DP <= '1';
  HEX3_DP <= '1';

end architecture structural;
