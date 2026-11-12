library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pkg_system.all;

entity ram_memory is
  port (
  --ENTRADAS
    clk      : in  std_logic;   -- Reloj 
    we       : in  std_logic;   -- Habilitacion de escritura
    wr_addr  : in  addr_t;      -- Direccion de escritura
    data_in  : in  data_t;      -- Dato a escribir
    rd_addr  : in  addr_t;      -- Direccion de lectura
  --SALIDA	 
    data_out : out data_t       -- Dato leido 
  );
end entity ram_memory;

architecture rtl of ram_memory is

  signal mem   : ram_array_t := (others => (others => '0'));  -- la memoria de 16 casillas de 8 bits y todas empiezan en 0
  signal q_reg : data_t := (others => '0');                   -- registro donde queda guardado 

  attribute ramstyle : string;                                -- declara un atributo de texto para Quartus
  attribute ramstyle of mem : signal is "M9K";                -- le pide a Quartus que use un bloque de memoria

begin                                                        

  p_ram : process (clk)                                       -- proceso que se activa con el reloj en cada flanco de subida del reloj
  begin
    if rising_edge(clk) then                                  
      if we = '1' then                                        -- si la FSM da permiso de escribir  guarda el dato en la casilla indicada por la direccion de escritura
        mem(to_integer(unsigned(wr_addr))) <= data_in;        
      end if;                                                 -- fin del permiso de escritura
      q_reg <= mem(to_integer(unsigned(rd_addr)));            -- siempre lee la casilla de la direccion de lectura y la guarda en q_reg
    end if;                                                   -- fin del flanco de reloj
  end process p_ram;                                          -- fin del proceso de la RAM

  data_out <= q_reg;                                          -- salida: el dato leido, que sale un ciclo despues de pedir la direccion

end architecture rtl;
