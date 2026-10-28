-- =============================================================================
-- Archivo      : control_unit.vhd
-- Proyecto     : Microproyecto 2 - Registro de Presencia con ROM/RAM y sensor PIR
--
-- Descripcion  :
--   Unidad de control: maquina de estados finitos tipo MOORE que coordina
--   el flujo de datos ROM -> RAM ante cada evento de presencia.
--
--   Estados:
--     S_IDLE      : espera el pulso del PIR (pir_pulse = '1').
--     S_READ_ROM  : habilita la ROM (rom_en = '1') en la direccion rom_ptr.
--     S_WAIT_ROM  : el codigo ya esta en rom_data -> se captura en data_reg.
--     S_WRITE_RAM : escribe data_reg en la RAM (ram_we = '1') en wr_ptr.
--     S_INC_ADDR  : incrementa automaticamente rom_ptr y wr_ptr,
--                   actualiza contadores y banderas, y vuelve a S_IDLE.
--
--   Estilo de codificacion (sin latches):
--     * p_state_reg : proceso SINCRONO (flanco de subida) con reset sincrono.
--                     Contiene el registro de estado y todos los registros
--                     de datos (punteros, contadores, banderas).
--     * p_next_state: proceso COMBINACIONAL. Asigna un valor por defecto a
--                     next_state al inicio y cubre todos los casos con
--                     "when others", por lo que NO se infieren latches.
--     * Salidas Moore: asignaciones concurrentes que dependen solo de state.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pkg_system.all;

entity control_unit is
  port (
    clk         : in  std_logic;                     -- Reloj de 50 MHz
    rst         : in  std_logic;                     -- Reset sincrono activo en alto
    pir_pulse   : in  std_logic;                     -- Evento de presencia (1 ciclo)

    -- Interfaz con la ROM
    rom_en      : out std_logic;                     -- Habilita lectura de ROM
    rom_addr    : out addr_t;                        -- Direccion de ROM
    rom_data    : in  data_t;                        -- Codigo leido de ROM

    -- Interfaz con la RAM (puerto de escritura)
    ram_we      : out std_logic;                     -- Habilita escritura en RAM
    ram_addr    : out addr_t;                        -- Direccion de escritura
    ram_data    : out data_t;                        -- Dato a escribir

    -- Estado del registro (hacia visualizacion)
    last_addr   : out addr_t;                        -- Ultima direccion escrita
    has_data    : out std_logic;                     -- '1' si ya hay al menos 1 registro
    ram_full    : out std_logic;                     -- '1' si la RAM ya se lleno (dio la vuelta)
    event_count : out std_logic_vector(7 downto 0);  -- Total de detecciones (satura en 255)
    state_code  : out std_logic_vector(2 downto 0)   -- Codigo del estado actual
  );
end entity control_unit;

architecture rtl of control_unit is

  type state_t is (S_IDLE, S_READ_ROM, S_WAIT_ROM, S_WRITE_RAM, S_INC_ADDR);
  signal state, next_state : state_t := S_IDLE;

  -- Registros de datos
  signal rom_ptr    : unsigned(ADDR_WIDTH-1 downto 0) := (others => '0');
  signal wr_ptr     : unsigned(ADDR_WIDTH-1 downto 0) := (others => '0');
  signal last_ptr   : unsigned(ADDR_WIDTH-1 downto 0) := (others => '0');
  signal data_reg   : data_t := (others => '0');
  signal ev_cnt     : unsigned(7 downto 0) := (others => '0');
  signal full_flag  : std_logic := '0';
  signal valid_flag : std_logic := '0';

begin

  -- ===========================================================================
  -- Proceso secuencial: registro de estado + ruta de datos
  -- ===========================================================================
  p_state_reg : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        -- Valores seguros ('0') tras el reset
        state      <= S_IDLE;
        rom_ptr    <= (others => '0');
        wr_ptr     <= (others => '0');
        last_ptr   <= (others => '0');
        data_reg   <= (others => '0');
        ev_cnt     <= (others => '0');
        full_flag  <= '0';
        valid_flag <= '0';
      else
        state <= next_state;

        case state is
          when S_WAIT_ROM =>
            -- El codigo de la ROM ya es valido: se captura
            data_reg <= rom_data;

          when S_INC_ADDR =>
            -- Incremento automatico de direcciones (aritmetica modulo 16)
            last_ptr   <= wr_ptr;
            wr_ptr     <= wr_ptr + 1;
            rom_ptr    <= rom_ptr + 1;
            valid_flag <= '1';
            if wr_ptr = to_unsigned(MEM_DEPTH-1, ADDR_WIDTH) then
              full_flag <= '1';
            end if;
            if ev_cnt /= x"FF" then
              ev_cnt <= ev_cnt + 1;
            end if;

          when others =>
            null;   -- Los registros mantienen su valor
        end case;
      end if;
    end if;
  end process p_state_reg;

  -- ===========================================================================
  -- Proceso combinacional: logica de estado siguiente
  -- ===========================================================================
  p_next_state : process (state, pir_pulse)
  begin
    next_state <= state;   -- Valor por defecto: evita latches

    case state is
      when S_IDLE =>
        if pir_pulse = '1' then
          next_state <= S_READ_ROM;
        end if;
      when S_READ_ROM  => next_state <= S_WAIT_ROM;
      when S_WAIT_ROM  => next_state <= S_WRITE_RAM;
      when S_WRITE_RAM => next_state <= S_INC_ADDR;
      when S_INC_ADDR  => next_state <= S_IDLE;
      when others      => next_state <= S_IDLE;
    end case;
  end process p_next_state;

  -- ===========================================================================
  -- Salidas Moore (dependen unicamente del estado actual)
  -- ===========================================================================
  rom_en <= '1' when state = S_READ_ROM  else '0';
  ram_we <= '1' when state = S_WRITE_RAM else '0';

  with state select
    state_code <= ST_CODE_IDLE when S_IDLE,
                  ST_CODE_RROM when S_READ_ROM,
                  ST_CODE_WROM when S_WAIT_ROM,
                  ST_CODE_WRAM when S_WRITE_RAM,
                  ST_CODE_INC  when S_INC_ADDR,
                  ST_CODE_IDLE when others;

  rom_addr    <= std_logic_vector(rom_ptr);
  ram_addr    <= std_logic_vector(wr_ptr);
  ram_data    <= data_reg;
  last_addr   <= std_logic_vector(last_ptr);
  has_data    <= valid_flag;
  ram_full    <= full_flag;
  event_count <= std_logic_vector(ev_cnt);

end architecture rtl;
