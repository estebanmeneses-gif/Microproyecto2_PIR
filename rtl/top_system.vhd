library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pkg_system.all;

--SISTEMA DE REGISTRO DE PRESENCIA CON SENSOR PIR

-----------------------------------ENTITY-------------------------------------
entity top_system is
  generic (
    G_FILTER_CYCLES  : positive := PIR_FILTER_CYCLES;   -- 20 ms 
    G_STRETCH_CYCLES : positive := LED_STRETCH_CYCLES   -- 250 ms
  );
  port (
      -- ENTRADAS
    clk     : in  std_logic;                     -- CLOCK_50
    rst_n   : in  std_logic;                     -- BUTTON 0 
    pir_in  : in  std_logic;                     -- Sensor PIR HC-SR501 
    SW      : in  std_logic_vector(9 downto 0);  -- Interruptores 
	 
	  -- SALIDAS
    HEX0_D  : out std_logic_vector(6 downto 0);  -- Display 0 
    HEX1_D  : out std_logic_vector(6 downto 0);  -- Display 1
    HEX2_D  : out std_logic_vector(6 downto 0);  -- Display 2
    HEX3_D  : out std_logic_vector(6 downto 0);  -- Display 3
    HEX0_DP : out std_logic;                     -- Puntos decimales
    HEX1_DP : out std_logic;                     -- Puntos decimales
    HEX2_DP : out std_logic;                     -- Puntos decimales
    HEX3_DP : out std_logic;                     -- Puntos decimales
    LEDG    : out std_logic_vector(9 downto 0)   -- LEDS
   
  );
end entity top_system;
---------------------------------------------------------------------------------------

---------------------------------ARCHITECTURE------------------------------------------
architecture structural of top_system is

  signal rst         : std_logic;   -- reset interno
  signal pir_level   : std_logic;   -- existe presencia 
  signal pir_pulse   : std_logic;   -- pulso de un ciclo por cada movimiento nuevo

  signal rom_en      : std_logic;   -- permiso de lectura de la ROM
  signal rom_addr    : addr_t;      -- casilla de la ROM a leer
  signal rom_data    : data_t;      -- codigo que entrega la ROM

  signal ram_we      : std_logic;   -- permiso de escritura en la RAM
  signal ram_wr_addr : addr_t;      -- casilla de la RAM donde se escribe
  signal ram_wr_data : data_t;      -- dato que se escribe
  signal ram_rd_addr : addr_t;      -- casilla de la RAM que se quiere leer
  signal ram_rd_data : data_t;      -- dato leido de la RAM

  -- Informacion de la FSM para los displays y LEDS
  signal last_addr   : addr_t;
  signal has_data    : std_logic;
  signal ram_full    : std_logic;
  signal event_count : std_logic_vector(7 downto 0);
  signal state_code  : std_logic_vector(2 downto 0);

begin

  -- Reset
  u_rst : entity work.reset_sync
    port map (clk => clk, rst_n => rst_n, rst => rst);

  -- Acondicionamiento del sensor PIR
  -- Sincroniza y filtra la senal
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
  -- Lee la ROM guarda en la RAM y avanza la direccion
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
  -- Entrega el codigo que le pide la FSM
  u_rom : entity work.rom_memory                                                  -- Crea la ROM dentro del sistema
    port map (clk => clk, en => rom_en, addr => rom_addr, data_out => rom_data);  -- clk: reloj 

  -- Memoria RAM de eventos
  -- Guarda los codigos 
  u_ram : entity work.ram_memory     -- Crea la RAM dentro del sistema
    port map (
      clk      => clk,               -- Reloj del sistema
      we       => ram_we,            -- Permiso de escritura que da la FSM
      wr_addr  => ram_wr_addr,       -- Casilla donde se va a escribir
      data_in  => ram_wr_data,       -- Dato que se va a guardar
      rd_addr  => ram_rd_addr,       -- Casilla que el display quiere leer
      data_out => ram_rd_data        -- Dato leido que le llega al display
    );

  -- Lectura y visualizacion
  -- Lee la RAM, muestra datos y LEDS
  u_disp : entity work.display_unit                   -- Maneja displays y LEDS
    generic map (G_STRETCH_CYCLES => G_STRETCH_CYCLES) -- Tiempo que queda prendido el LED
    port map (
      clk         => clk,             -- Reloj
      rst         => rst,             -- Reset interno
      view_mode   => SW(9),           -- Switch 9
      sw_addr     => SW(3 downto 0),  -- Switches 3 a 0
      last_addr   => last_addr,       -- Ultima casilla escrita
      has_data    => has_data,        -- Avisa si ya hay algo guardado
      ram_full    => ram_full,        -- Avisa si ya se llenaron las 16 casillas
      event_count => event_count,     -- Cantidad de detecciones
      state_code  => state_code,      -- Numero del estado actual de la FSM
      pir_level   => pir_level,       -- Hay presencia en este momento
      pir_pulse   => pir_pulse,       -- Pulso de un movimiento nuevo
      ram_rd_addr => ram_rd_addr,     -- Salida
      ram_rd_data => ram_rd_data,     -- Entrada
      hex0        => HEX0_D,          -- Display 0
      hex1        => HEX1_D,          -- Display 1
      hex2        => HEX2_D,          -- Display 2
      hex3        => HEX3_D,          -- Display 3
      ledg        => LEDG             -- LEDS 
    );

  -- PUNTOS DECIMALES 
  HEX0_DP <= '1';   -- Punto del display 0 
  HEX1_DP <= '1';   -- Punto del display 1 
  HEX2_DP <= '1';   -- Punto del display 2 
  HEX3_DP <= '1';   -- Punto del display 3 

end architecture structural;
-----------------------------------------------------------------------------------------
