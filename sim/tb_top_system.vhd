-- =============================================================================
-- Archivo      : tb_top_system.vhd
-- Proyecto     : Microproyecto 2 - Registro de Presencia con ROM/RAM y sensor PIR
--
-- Descripcion  :
--   Testbench AUTOVERIFICABLE del sistema completo (top_system).
--   Se reducen los genericos de tiempo (filtro de 16 ciclos en lugar de
--   20 ms) para que la simulacion sea corta; la logica es identica.
--
--   Pruebas (validaciones obligatorias del enunciado):
--     T1  Reset del sistema      : tras reset, FSM en IDLE (HEX2=0), contador = 0
--                                  y displays de datos en "--".
--     T2  Sincronizacion/filtrado: rafaga de rebotes/glitches mas cortos que el
--                                  filtro -> NO se registra ningun evento.
--     T3  Lectura ROM + escritura RAM: 5 detecciones reales; despues de cada una
--                                  el display en vivo muestra la direccion i y el
--                                  codigo ROM(i).
--     T4  Un solo registro por movimiento: PIR mantenido en alto mucho tiempo
--                                  -> solo 1 evento (detector de flanco).
--     T5  Lectura y visualizacion: modo consulta (SW9=1) recorre la RAM con
--                                  SW3..0 y compara con los codigos esperados.
--     T6  Memoria llena          : se completan 16 eventos -> LEDG2 = '1' y
--                                  el puntero da la vuelta a la direccion 0.
--     T7  Reset en mitad de uso  : punteros y contador vuelven a 0 y el
--                                  siguiente evento se guarda en la direccion 0.
--
--   Al final se imprime el numero de errores. 0 errores = diseno correcto.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pkg_system.all;

entity tb_top_system is
end entity tb_top_system;

architecture sim of tb_top_system is

  constant CLK_PERIOD   : time     := 20 ns;   -- 50 MHz
  constant FILTER_CYC   : positive := 16;      -- Filtro reducido para simulacion
  constant STRETCH_CYC  : positive := 8;

  -- Copia de los codigos de la ROM (modelo de referencia)
  constant ROM_REF : rom_array_t := (
     0 => x"A1",   1 => x"B2",   2 => x"C3",   3 => x"D4",
     4 => x"E5",   5 => x"F6",   6 => x"07",   7 => x"18",
     8 => x"29",   9 => x"3A",  10 => x"4B",  11 => x"5C",
    12 => x"6D",  13 => x"7E",  14 => x"8F",  15 => x"90"
  );

  signal clk     : std_logic := '0';
  signal rst_n   : std_logic := '1';
  signal pir_in  : std_logic := '0';
  signal SW      : std_logic_vector(9 downto 0) := (others => '0');
  signal HEX0_D, HEX1_D, HEX2_D, HEX3_D : std_logic_vector(6 downto 0);
  signal HEX0_DP, HEX1_DP, HEX2_DP, HEX3_DP : std_logic;
  signal LEDG    : std_logic_vector(9 downto 0);

  signal sim_done : boolean := false;
  signal errors   : natural := 0;

begin

  -- ---------------------------------------------------------------------------
  -- Dispositivo bajo prueba
  -- ---------------------------------------------------------------------------
  DUT : entity work.top_system
    generic map (G_FILTER_CYCLES => FILTER_CYC, G_STRETCH_CYCLES => STRETCH_CYC)
    port map (
      clk => clk, rst_n => rst_n, pir_in => pir_in, SW => SW,
      HEX0_D => HEX0_D, HEX1_D => HEX1_D, HEX2_D => HEX2_D, HEX3_D => HEX3_D,
      HEX0_DP => HEX0_DP, HEX1_DP => HEX1_DP, HEX2_DP => HEX2_DP, HEX3_DP => HEX3_DP,
      LEDG => LEDG
    );

  -- Reloj de 50 MHz
  clk <= not clk after CLK_PERIOD/2 when not sim_done else '0';

  -- ---------------------------------------------------------------------------
  -- Estimulos y verificacion
  -- ---------------------------------------------------------------------------
  stim : process

    variable err_v : natural := 0;

    procedure wait_clk(n : natural) is
    begin
      for i in 1 to n loop
        wait until rising_edge(clk);
      end loop;
    end procedure;

    procedure check(cond : boolean; msg : string) is
    begin
      if not cond then
        err_v := err_v + 1;
        errors <= err_v;
        report "FALLO: " & msg severity error;
      end if;
    end procedure;

    -- Movimiento real: el PIR se mantiene en alto bastante mas que el filtro
    procedure pir_event is
    begin
      pir_in <= '1';
      wait_clk(4 * FILTER_CYC);
      pir_in <= '0';
      wait_clk(4 * FILTER_CYC);
    end procedure;

    -- Ruido/rebotes: pulsos mas cortos que el tiempo de filtro
    procedure pir_bounce is
    begin
      for i in 1 to 6 loop
        pir_in <= '1';  wait_clk(3);
        pir_in <= '0';  wait_clk(2);
        pir_in <= '1';  wait_clk(FILTER_CYC/2);
        pir_in <= '0';  wait_clk(5);
      end loop;
      wait_clk(4 * FILTER_CYC);
    end procedure;

    procedure press_reset is
    begin
      rst_n <= '0';
      wait_clk(5);
      rst_n <= '1';
      wait_clk(5);
    end procedure;

    -- Verifica lo que se ve en los displays
    procedure check_display(addr : natural; data : std_logic_vector(7 downto 0); tag : string) is
    begin
      check(HEX3_D = hex_to_7seg(std_logic_vector(to_unsigned(addr, 4))),
            tag & ": HEX3 no muestra la direccion " & integer'image(addr));
      check(HEX1_D = hex_to_7seg(data(7 downto 4)),
            tag & ": HEX1 (nibble alto) incorrecto en direccion " & integer'image(addr));
      check(HEX0_D = hex_to_7seg(data(3 downto 0)),
            tag & ": HEX0 (nibble bajo) incorrecto en direccion " & integer'image(addr));
    end procedure;

    impure function ev_count return natural is
    begin
      return to_integer(unsigned(LEDG(9 downto 4)));
    end function;

  begin
    -- =========================================================================
    -- T1: Reset del sistema
    -- =========================================================================
    report "T1: reset inicial" severity note;
    press_reset;
    check(HEX2_D = hex_to_7seg("0000"), "T1: la FSM no esta en IDLE tras reset");
    check(LEDG(9 downto 4) = "000000", "T1: contador de eventos distinto de 0");
    check(HEX0_D = SEG_DASH and HEX1_D = SEG_DASH, "T1: displays deberian mostrar --");
    check(HEX0_DP = '1', "T1: punto decimal deberia estar apagado");

    -- =========================================================================
    -- T2: Inmunidad a rebotes y ruido
    -- =========================================================================
    report "T2: rafaga de rebotes/glitches en pir_in" severity note;
    pir_bounce;
    check(ev_count = 0, "T2: un glitch genero un evento (filtro no funciona)");
    check(LEDG(0) = '0', "T2: nivel filtrado del PIR deberia ser 0");

    -- =========================================================================
    -- T3: Lectura ROM -> escritura RAM en direcciones consecutivas
    -- =========================================================================
    report "T3: 5 detecciones validas" severity note;
    for i in 0 to 4 loop
      pir_event;
      check(ev_count = i + 1, "T3: contador de eventos incorrecto");
      check(HEX2_D = hex_to_7seg("0000"), "T3: FSM no regreso a IDLE");
      check_display(i, ROM_REF(i), "T3");
    end loop;

    -- =========================================================================
    -- T4: Senal en alto prolongada -> un solo evento
    -- =========================================================================
    report "T4: PIR sostenido en alto" severity note;
    pir_in <= '1';
    wait_clk(40 * FILTER_CYC);
    check(LEDG(0) = '1', "T4: nivel filtrado deberia ser 1");
    pir_in <= '0';
    wait_clk(4 * FILTER_CYC);
    check(ev_count = 6, "T4: se registro mas de un evento por un solo movimiento");
    check_display(5, ROM_REF(5), "T4");

    -- =========================================================================
    -- T5: Modo consulta: lectura de la RAM con los interruptores
    -- =========================================================================
    report "T5: recorrido de la RAM en modo consulta" severity note;
    SW(9) <= '1';
    for k in 0 to 5 loop
      SW(3 downto 0) <= std_logic_vector(to_unsigned(k, 4));
      wait_clk(3);
      check(LEDG(3) = '1', "T5: LEDG3 deberia indicar modo consulta");
      check_display(k, ROM_REF(k), "T5");
    end loop;
    SW(9) <= '0';
    SW(3 downto 0) <= "0000";
    wait_clk(3);

    -- =========================================================================
    -- T6: Llenado completo de la RAM y vuelta a la direccion 0
    -- =========================================================================
    report "T6: llenado de las 16 posiciones" severity note;
    check(LEDG(2) = '0', "T6: RAM marcada como llena antes de tiempo");
    for i in 6 to 15 loop
      pir_event;
    end loop;
    check(LEDG(2) = '1', "T6: LEDG2 (RAM llena) no se activo");
    check_display(15, ROM_REF(15), "T6");
    pir_event;   -- evento 17: vuelve a la direccion 0 con el codigo ROM(0)
    check_display(0, ROM_REF(0), "T6 vuelta");
    check(ev_count = 17 mod 64, "T6: contador de eventos incorrecto");

    -- =========================================================================
    -- T7: Reset con el sistema en uso
    -- =========================================================================
    report "T7: reset en mitad del funcionamiento" severity note;
    pir_in <= '1';                 -- reset mientras hay presencia
    wait_clk(FILTER_CYC/2);
    press_reset;
    pir_in <= '0';
    wait_clk(4 * FILTER_CYC);
    check(ev_count = 0, "T7: el contador no volvio a 0");
    check(LEDG(2) = '0', "T7: bandera de RAM llena no se limpio");
    check(HEX2_D = hex_to_7seg("0000"), "T7: FSM no esta en IDLE");
    check(HEX0_D = SEG_DASH, "T7: display deberia mostrar -- tras reset");
    pir_event;
    check_display(0, ROM_REF(0), "T7: primer evento tras reset");
    pir_event;
    check_display(1, ROM_REF(1), "T7: segundo evento tras reset");

    -- =========================================================================
    -- Resumen
    -- =========================================================================
    if err_v = 0 then
      report "RESULTADO: TODAS LAS PRUEBAS PASARON (0 errores)" severity note;
    else
      report "RESULTADO: " & integer'image(err_v) & " ERRORES" severity error;
    end if;

    sim_done <= true;
    wait;
  end process stim;

end architecture sim;
