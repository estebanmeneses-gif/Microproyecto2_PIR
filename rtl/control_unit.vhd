library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pkg_system.all;

entity control_unit is
 port (
    -- ENTRADAS
    clk         : in  std_logic;                     -- Reloj
    rst         : in  std_logic;                     -- Reset
    pir_pulse   : in  std_logic;                     -- Evento de presencia
    rom_data    : in  data_t;                        -- Codigo leido de la ROM

    -- SALIDAS
    -- la ROM
    rom_en      : out std_logic;                     -- Habilita lectura de la ROM
    rom_addr    : out addr_t;                        -- Direccion de la ROM

    -- a RAM
    ram_we      : out std_logic;                     -- Habilita escritura en RAM
    ram_addr    : out addr_t;                        -- Direccion de escritura
    ram_data    : out data_t;                        -- Dato a escribir

    -- Estado del registro
    last_addr   : out addr_t;                        -- Ultima direccion escrita
    has_data    : out std_logic;                     -- '1' si ya hay al menos 1 registro
    ram_full    : out std_logic;                     -- '1' si la RAM ya se lleno
    event_count : out std_logic_vector(7 downto 0);  -- Total de detecciones 
    state_code  : out std_logic_vector(2 downto 0)   -- Codigo del estado actual
  );
end entity control_unit;

architecture rtl of control_unit is

  type state_t is (S_IDLE, S_READ_ROM, S_WAIT_ROM, S_WRITE_RAM, S_INC_ADDR);  -- los 5 estados de la FSM
  signal state, next_state : state_t := S_IDLE;                                -- estado actual y estado siguiente

  -- Registros de datos
  signal rom_ptr    : unsigned(ADDR_WIDTH-1 downto 0) := (others => '0');      -- casilla de la ROM que se va a leer
  signal wr_ptr     : unsigned(ADDR_WIDTH-1 downto 0) := (others => '0');      -- casilla de la RAM donde se va a escribir
  signal last_ptr   : unsigned(ADDR_WIDTH-1 downto 0) := (others => '0');      -- ultima casilla escrita
  signal data_reg   : data_t := (others => '0');                               -- guarda el codigo que entrega a la ROM
  signal ev_cnt     : unsigned(7 downto 0) := (others => '0');                 -- cantidad de detecciones
  signal full_flag  : std_logic := '0';                                        -- avisa que ya se llenaron las 16 casillas
  signal valid_flag : std_logic := '0';                                        -- avisa que ya hay algo guardado

begin

  -- Proceso secuencial
  -- registro de estado y ruta de datos
  p_state_reg : process (clk)
  begin
    if rising_edge(clk) then                                       
      if rst = '1' then                                            
        -- Valores seguros ('0') tras el reset
        state      <= S_IDLE;                                      -- FSM en reposo
        rom_ptr    <= (others => '0');                             -- puntero de la ROM en 0
        wr_ptr     <= (others => '0');                             -- puntero de la RAM en 0
        last_ptr   <= (others => '0');                             -- ultima casilla en 0
        data_reg   <= (others => '0');                             -- dato guardado en 0
        ev_cnt     <= (others => '0');                             -- contador de eventos en 0
        full_flag  <= '0';                                         -- la RAM no esta llena
        valid_flag <= '0';                                         -- todavia no hay datos
      else
        state <= next_state;                                       -- pasa al siguiente estado

        case state is                                              -- segun el estado actual
          when S_WAIT_ROM =>
            -- El codigo de la ROM es valido se captura
            data_reg <= rom_data;                                  -- guarda el codigo que entrego la ROM

          when S_INC_ADDR =>
            -- Aumento de direcciones
            last_ptr   <= wr_ptr;                                  -- recuerda la casilla que se acaba de escribir
            wr_ptr     <= wr_ptr + 1;                              -- siguiente casilla de la RAM
            rom_ptr    <= rom_ptr + 1;                             -- siguiente codigo de la ROM
            valid_flag <= '1';                                     -- ya hay al menos un registro
            if wr_ptr = to_unsigned(MEM_DEPTH-1, ADDR_WIDTH) then  -- si se escribio la casilla 15
              full_flag <= '1';                                    -- la RAM se lleno
            end if;
            if ev_cnt /= x"FF" then                                -- mientras no llegue a 255 suma una deteccion
              ev_cnt <= ev_cnt + 1;                                
            end if;

          when others =>
            null;   -- Los registros mantienen su valor
        end case;
      end if;
    end if;
  end process p_state_reg;

  -- Proceso combinacional
  --logica del siguiente estado
  
  p_next_state : process (state, pir_pulse)
  begin
    next_state <= state;   -- Valor por defecto

    case state is
      when S_IDLE =>                                               -- esperando movimiento
        if pir_pulse = '1' then                                    -- llego un movimiento nuevo
          next_state <= S_READ_ROM;                                -- empieza el ciclo de registro
        end if;
      when S_READ_ROM  => next_state <= S_WAIT_ROM;                -- se le pide el codigo a la ROM
      when S_WAIT_ROM  => next_state <= S_WRITE_RAM;               -- se espera 1 ciclo y se captura el codigo
      when S_WRITE_RAM => next_state <= S_INC_ADDR;                -- se escribe el codigo en la RAM
      when S_INC_ADDR  => next_state <= S_IDLE;                    -- se actualizan los punteros y vuelve a reposo
      when others      => next_state <= S_IDLE;                    -- cualquier otro caso va a IDLE
    end case;
  end process p_next_state;

  -- Salidas Moore 
  
  rom_en <= '1' when state = S_READ_ROM  else '0';                 -- la ROM solamente se lee en READ_ROM
  ram_we <= '1' when state = S_WRITE_RAM else '0';                 -- la RAM solamente se escribe en WRITE_RAM

  with state select                                                -- numero del estado que se ve en HEX2
    state_code <= ST_CODE_IDLE when S_IDLE,                        -- IDLE      -> 0
                  ST_CODE_RROM when S_READ_ROM,                    -- READ_ROM  -> 1
                  ST_CODE_WROM when S_WAIT_ROM,                    -- WAIT_ROM  -> 2
                  ST_CODE_WRAM when S_WRITE_RAM,                   -- WRITE_RAM -> 3
                  ST_CODE_INC  when S_INC_ADDR,                    -- INC_ADDR  -> 4
                  ST_CODE_IDLE when others;                        -- cualquier otro caso -> 0

  rom_addr    <= std_logic_vector(rom_ptr);                        -- casilla de la ROM a leer
  ram_addr    <= std_logic_vector(wr_ptr);                         -- casilla de la RAM donde se escribe
  ram_data    <= data_reg;                                         -- dato que se escribe en la RAM
  last_addr   <= std_logic_vector(last_ptr);                       -- ultima casilla escrita
  has_data    <= valid_flag;                                       -- avisa si ya hay algo guardado
  ram_full    <= full_flag;                                        -- avisa si ya se llenaron las 16 casillas
  event_count <= std_logic_vector(ev_cnt);                         -- cantidad de detecciones

end architecture rtl;