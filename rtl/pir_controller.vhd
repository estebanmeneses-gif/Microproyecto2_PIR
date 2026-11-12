library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pkg_system.all;

entity pir_controller is
  generic (
    G_SYNC_STAGES   : positive := SYNC_STAGES;        -- Etapas del sincronizador 
    G_FILTER_CYCLES : positive := PIR_FILTER_CYCLES   -- Ciclos de estabilidad exigidos
  );
  port (
 --ENTRADA 
 
    clk       : in  std_logic;   -- Reloj 
    rst       : in  std_logic;   -- Reset sincrono 
    pir_in    : in  std_logic;   -- Salida fisica del sensor PIR 
 --SALIDA 
 
    pir_level : out std_logic;   -- Nivel filtrado 
    pir_pulse : out std_logic    -- Pulso de 1 ciclo por cada deteccion
  );
end entity pir_controller;

architecture rtl of pir_controller is

  -- Cadena del sincronizador multi-etapa
  signal sync_reg : std_logic_vector(G_SYNC_STAGES-1 downto 0) := (others => '0');  -- cadena de flip-flops por donde pasa la senal del sensor
  signal pir_sync : std_logic;                                                      -- salida de la senal ya sincronizada con el reloj

  -- Filtro por estabilidad
  signal filt_cnt : natural range 0 to G_FILTER_CYCLES := 0;                        -- cuenta cuantos ciclos lleva estable un cambio
  signal pir_filt : std_logic := '0';                                               -- valor del sensor ya filtrado y aceptado

  -- Detector de flanco
  signal pir_filt_d : std_logic := '0';                                             -- valor filtrado del ciclo anterior
  signal pulse_reg  : std_logic := '0';                                             -- registro que guarda el pulso de salida

  -- Indica a Quartus que la cadena es un sincronizador
  attribute altera_attribute : string;                                              -- declara un atributo de texto para Quartus
  attribute altera_attribute of sync_reg : signal is "-name SYNCHRONIZER_IDENTIFICATION ""FORCED IF ASYNCHRONOUS""";  -- marca sync_reg como sincronizador

begin                                                                               

  -- Etapa 1
 -- sincronizador de G_SYNC_STAGES flip-flops

  p_sync : process (clk)                                                            -- proceso que se activa con el reloj en cada flanco de subida
  begin
    if rising_edge(clk) then                                                        
      if rst = '1' then                                                             -- si hay reset limpia toda la cadena
        sync_reg <= (others => '0');                                                
      else
        sync_reg <= sync_reg(G_SYNC_STAGES-2 downto 0) & pir_in;                    -- corre la cadena y mete el valor nuevo del sensor
      end if;                                                                       
    end if;                                                                         
  end process p_sync;                                                               

  pir_sync <= sync_reg(G_SYNC_STAGES-1);                                            -- toma el ultimo flip-flop como senal sincronizada


  -- Etapa 2
  --filtro anti-rebote / anti-ruido por estabilidad

  p_filter : process (clk)                                                          -- proceso que se activa con el reloj en cada flanco de subida
  begin
    if rising_edge(clk) then                                                       
      if rst = '1' then                                                             -- si hay reset reinicia el contador de estabilidad
        filt_cnt <= 0;                                                              
        pir_filt <= '0';                                                            -- deja la salida filtrada en 0 si la entrada es distinta de lo que ya se acepto
      elsif pir_sync /= pir_filt then                                               
        -- La entrada difiere del valor aceptado: contar estabilidad
        if filt_cnt = G_FILTER_CYCLES-1 then                                        -- si el cambio ya duro todo el tiempo exigido reinicia el contador para el proximo cambio
          pir_filt <= pir_sync;   -- Cambio confirmado
          filt_cnt <= 0;                                                            
        else
          filt_cnt <= filt_cnt + 1;                                                 -- si aun no alcanza el tiempo, sigue contando
        end if;                                                                     -- fin de la comparacion del contador
      else
        -- Volvio al valor aceptado antes de tiempo: era un glitch
        filt_cnt <= 0;                                                              -- descarta el cambio y reinicia la cuenta
      end if;                                                                       -- fin de la comparacion de entrada y salida
    end if;                                                                         -- fin del flanco de reloj
  end process p_filter;                                                             -- fin del proceso del filtro


  -- Etapa 3
  -- detector de flanco de subida 
 
  p_edge : process (clk)                                                            -- proceso que se activa con el reloj
  begin
    if rising_edge(clk) then                                                        -- en cada flanco de subida del reloj
      if rst = '1' then                                                             -- si hay reset borra el valor del ciclo anterior borra y el pulso
        pir_filt_d <= '0';                                                          
        pulse_reg  <= '0';                                                          
      else
        pir_filt_d <= pir_filt;                                                     -- guarda el valor actual para compararlo en el siguiente ciclo
        pulse_reg  <= pir_filt and (not pir_filt_d);                                -- da un pulso solo cuando la senal pasa de 0 a 1
      end if;                                                                       -- fin del if del reset
    end if;                                                                         -- fin del flanco de reloj
  end process p_edge;                                                               -- fin del proceso del detector de flanco

  pir_level <= pir_filt;                                                            -- salida: nivel filtrado, indica que hay presencia
  pir_pulse <= pulse_reg;                                                           -- salida: pulso de un ciclo por cada movimiento nuevo

end architecture rtl;
