library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pkg_system.all;

entity display_unit is
  generic (
    G_STRETCH_CYCLES : positive := LED_STRETCH_CYCLES   -- Duracion del destello LEDG1
  );
  port (
    -- ENTRADAS
	 
    clk         : in  std_logic;                        -- reloj 
    rst         : in  std_logic;                        -- reset sincrono
    -- Seleccion de vista
    view_mode   : in  std_logic;                        -- 0 modo en vivo, 1 modo consulta
    sw_addr     : in  addr_t;                           -- casilla que se quiere consultar
    -- Informacion de la unidad de control
    last_addr   : in  addr_t;                           -- ultima casilla escrita
    has_data    : in  std_logic;                        -- informa si ya hay algo guardado
    ram_full    : in  std_logic;                        -- informa si ya se llenaron las 16 casillas
    event_count : in  std_logic_vector(7 downto 0);     -- cantidad de detecciones
    state_code  : in  std_logic_vector(2 downto 0);     -- numero del estado actual de la FSM
    -- Informacion del PIR
    pir_level   : in  std_logic;                        -- hay presencia en este momento
    pir_pulse   : in  std_logic;                        -- pulso de un movimiento nuevo
    -- Puerto de lectura de la RAM
    ram_rd_data : in  data_t;                           -- dato leido de la RAM

    -- SALIDAS

    -- Puerto de lectura de la RAM
    ram_rd_addr : out addr_t;                           -- casilla de la RAM que se quiere leer
    -- Salidas fisicas
    hex0        : out std_logic_vector(6 downto 0);     -- display 0 
    hex1        : out std_logic_vector(6 downto 0);     -- display 1 
    hex2        : out std_logic_vector(6 downto 0);     -- display 2 
    hex3        : out std_logic_vector(6 downto 0);     -- display 3 
    ledg        : out std_logic_vector(9 downto 0)      -- LEDS
  );
end entity display_unit;

architecture rtl of display_unit is

  signal rd_addr_s   : addr_t;
  signal data_dash   : std_logic;
  signal stretch_cnt : natural range 0 to G_STRETCH_CYCLES := 0;
  signal event_led   : std_logic;
  signal state_nib   : std_logic_vector(3 downto 0);

begin

  -- Multiplexor de direccion de lectura
  rd_addr_s   <= sw_addr when view_mode = '1' else last_addr;     -- si el switch esta arriba usa la casilla de los switches si no usa la ultima guardada
  ram_rd_addr <= rd_addr_s;                                       -- es la casilla elegida que le pedimos a la RAM

  -- Guion en los datos si estamos en el momento y aun no hay registros
  data_dash <= '1' when (view_mode = '0' and has_data = '0') else '0';  -- activa los guiones

  state_nib <= '0' & state_code;                                  

  -- Decodificadores de 7 segmentos
  u_hex0 : entity work.hex7seg                                    -- display 0: muestra la mitad baja del dato de la RAM
    port map (hex => ram_rd_data(3 downto 0), dash => data_dash, blank => '0', seg => hex0);
  u_hex1 : entity work.hex7seg                                    -- display 1: muestra la mitad alta del dato de la RAM
    port map (hex => ram_rd_data(7 downto 4), dash => data_dash, blank => '0', seg => hex1);
  u_hex2 : entity work.hex7seg                                    -- display 2: muestra el numero del estado actual de la FSM
    port map (hex => state_nib, dash => '0', blank => '0', seg => hex2);
  u_hex3 : entity work.hex7seg                                    -- display 3: muestra el numero de la casilla que se esta viendo
    port map (hex => rd_addr_s, dash => data_dash, blank => '0', seg => hex3);

  -- pulso para que el evento sea visible en LEDG1
  p_stretch : process (clk)
  begin
    if rising_edge(clk) then                                      -- ocurre en cada flanco de subida del reloj
      if rst = '1' then                                           -- si se presiona el reset el contador se pone en 0 y el LED se apaga
        stretch_cnt <= 0;                                        
      elsif pir_pulse = '1' then                                  -- si llega un movimiento nuevo del sensor carga el tiempo completo que debe durar el destello
        stretch_cnt <= G_STRETCH_CYCLES;                          
      elsif stretch_cnt /= 0 then                                 -- si todavia queda tiempo de destello le resta un ciclo hasta llegar a 0
        stretch_cnt <= stretch_cnt - 1;                           
      end if;
    end if;
  end process p_stretch;

  event_led <= '1' when stretch_cnt /= 0 else '0';                -- el LED de evento esta prendido mientras el contador no haya llegado a 0

  ledg(0)          <= pir_level;                                  -- LEDG0: prendido mientras el sensor detecta presencia
  ledg(1)          <= event_led;                                  -- LEDG1: destello visible cada vez que se registra un movimiento
  ledg(2)          <= ram_full;                                   -- LEDG2: prendido cuando ya se llenaron las 16 casillas
  ledg(3)          <= view_mode;                                  -- LEDG3: prendido cuando se esta en modo consulta
  ledg(9 downto 4) <= event_count(5 downto 0);                    -- LEDG9 a LEDG4: total de detecciones en binario (solo caben 6 bits)

end architecture rtl;
