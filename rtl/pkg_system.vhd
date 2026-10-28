-- =============================================================================
-- Archivo      : pkg_system.vhd
-- Proyecto     : Microproyecto 2 - Registro de Presencia con ROM/RAM y sensor PIR
-- Universidad  : Universidad del Cauca - Ing. Electronica y Telecomunicaciones
-- Tarjeta      : Terasic DE0 (Cyclone III EP3C16F484C6), reloj de 50 MHz
--
-- Descripcion  :
--   Paquete central del sistema. Agrupa en un solo lugar:
--     * Constantes globales (frecuencia de reloj, anchos de bus, tiempos).
--     * Subtipos de bus de datos y de direcciones.
--     * Tipos personalizados para las memorias ROM y RAM.
--     * Funcion de conversion hexadecimal -> 7 segmentos (activo en bajo).
--   Cambiando DATA_WIDTH o ADDR_WIDTH aqui, el cambio se propaga a todos
--   los modulos que usan "work.pkg_system.all".
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package pkg_system is

  -- ---------------------------------------------------------------------------
  -- Reloj del sistema
  -- ---------------------------------------------------------------------------
  constant CLK_FREQ_HZ : natural := 50_000_000;   -- Oscilador principal DE0

  -- ---------------------------------------------------------------------------
  -- Buses de datos y direcciones
  -- ---------------------------------------------------------------------------
  constant DATA_WIDTH : natural := 8;              -- Ancho de cada palabra (bits)
  constant ADDR_WIDTH : natural := 4;              -- Ancho de direccion (bits)
  constant MEM_DEPTH  : natural := 2**ADDR_WIDTH;  -- 16 posiciones

  subtype data_t is std_logic_vector(DATA_WIDTH-1 downto 0);
  subtype addr_t is std_logic_vector(ADDR_WIDTH-1 downto 0);

  -- Tipos personalizados de memoria (16 x 8 bits)
  type rom_array_t is array (0 to MEM_DEPTH-1) of data_t;
  type ram_array_t is array (0 to MEM_DEPTH-1) of data_t;

  -- ---------------------------------------------------------------------------
  -- Acondicionamiento del sensor PIR
  -- ---------------------------------------------------------------------------
  constant SYNC_STAGES       : natural := 3;    -- Flip-flops del sincronizador
  constant PIR_FILTER_MS     : natural := 20;   -- Tiempo de estabilidad exigido
  constant PIR_FILTER_CYCLES : natural := (CLK_FREQ_HZ / 1000) * PIR_FILTER_MS; -- 1_000_000

  -- ---------------------------------------------------------------------------
  -- Indicador visual de evento (LEDG1 encendido ~250 ms por cada deteccion)
  -- ---------------------------------------------------------------------------
  constant LED_STRETCH_CYCLES : natural := CLK_FREQ_HZ / 4;

  -- ---------------------------------------------------------------------------
  -- Codigos de estado de la FSM (se muestran en HEX2 para depuracion)
  -- ---------------------------------------------------------------------------
  constant ST_CODE_IDLE  : std_logic_vector(2 downto 0) := "000";
  constant ST_CODE_RROM  : std_logic_vector(2 downto 0) := "001";
  constant ST_CODE_WROM  : std_logic_vector(2 downto 0) := "010";
  constant ST_CODE_WRAM  : std_logic_vector(2 downto 0) := "011";
  constant ST_CODE_INC   : std_logic_vector(2 downto 0) := "100";

  -- Patron de display "-" (solo segmento g encendido, activo en bajo)
  constant SEG_DASH  : std_logic_vector(6 downto 0) := "0111111";
  constant SEG_BLANK : std_logic_vector(6 downto 0) := "1111111";

  -- ---------------------------------------------------------------------------
  -- Funcion: hex_to_7seg
  --   Convierte un nibble (0..F) al patron de 7 segmentos activo en bajo
  --   de la DE0. Orden de bits: (6)=g (5)=f (4)=e (3)=d (2)=c (1)=b (0)=a
  -- ---------------------------------------------------------------------------
  function hex_to_7seg(nibble : std_logic_vector(3 downto 0)) return std_logic_vector;

end package pkg_system;

package body pkg_system is

  function hex_to_7seg(nibble : std_logic_vector(3 downto 0)) return std_logic_vector is
    variable seg : std_logic_vector(6 downto 0);
  begin
    case nibble is
      when "0000" => seg := "1000000"; -- 0
      when "0001" => seg := "1111001"; -- 1
      when "0010" => seg := "0100100"; -- 2
      when "0011" => seg := "0110000"; -- 3
      when "0100" => seg := "0011001"; -- 4
      when "0101" => seg := "0010010"; -- 5
      when "0110" => seg := "0000010"; -- 6
      when "0111" => seg := "1111000"; -- 7
      when "1000" => seg := "0000000"; -- 8
      when "1001" => seg := "0010000"; -- 9
      when "1010" => seg := "0001000"; -- A
      when "1011" => seg := "0000011"; -- b
      when "1100" => seg := "1000110"; -- C
      when "1101" => seg := "0100001"; -- d
      when "1110" => seg := "0000110"; -- E
      when "1111" => seg := "0001110"; -- F
      when others => seg := "1111111"; -- apagado
    end case;
    return seg;
  end function hex_to_7seg;

end package body pkg_system;
