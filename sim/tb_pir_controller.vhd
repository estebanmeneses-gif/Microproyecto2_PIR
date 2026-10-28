-- =============================================================================
-- Archivo      : tb_pir_controller.vhd
-- Proyecto     : Microproyecto 2 - Registro de Presencia con ROM/RAM y sensor PIR
--
-- Descripcion  :
--   Testbench unitario del controlador PIR. Verifica:
--     1) Glitches/rebotes mas cortos que el filtro NO generan pulso.
--     2) Una senal estable genera EXACTAMENTE un pulso de 1 ciclo.
--     3) La latencia total (sincronizador + filtro + flanco) es acotada.
--     4) El reset limpia el estado interno.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_pir_controller is
end entity tb_pir_controller;

architecture sim of tb_pir_controller is

  constant CLK_PERIOD : time     := 20 ns;
  constant FILTER_CYC : positive := 10;

  signal clk       : std_logic := '0';
  signal rst       : std_logic := '1';
  signal pir_in    : std_logic := '0';
  signal pir_level : std_logic;
  signal pir_pulse : std_logic;
  signal done      : boolean := false;

  signal pulse_count : natural := 0;
  signal pulse_width : natural := 0;
  signal max_width   : natural := 0;

begin

  DUT : entity work.pir_controller
    generic map (G_SYNC_STAGES => 3, G_FILTER_CYCLES => FILTER_CYC)
    port map (clk => clk, rst => rst, pir_in => pir_in,
              pir_level => pir_level, pir_pulse => pir_pulse);

  clk <= not clk after CLK_PERIOD/2 when not done else '0';

  -- Monitor: cuenta pulsos y mide su ancho
  mon : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        pulse_count <= 0;
        pulse_width <= 0;
        max_width   <= 0;
      elsif pir_pulse = '1' then
        if pulse_width = 0 then
          pulse_count <= pulse_count + 1;
        end if;
        pulse_width <= pulse_width + 1;
        if pulse_width + 1 > max_width then
          max_width <= pulse_width + 1;
        end if;
      else
        pulse_width <= 0;
      end if;
    end if;
  end process mon;

  stim : process
    variable errs : natural := 0;
    variable lat  : natural := 0;
  begin
    wait for 5 * CLK_PERIOD;
    wait until rising_edge(clk);
    rst <= '0';

    -- 1) Rebotes cortos
    for i in 1 to 8 loop
      pir_in <= '1'; wait for (FILTER_CYC - 3) * CLK_PERIOD;
      pir_in <= '0'; wait for 2 * CLK_PERIOD;
    end loop;
    wait for 4 * FILTER_CYC * CLK_PERIOD;
    if pulse_count /= 0 then
      errs := errs + 1;
      report "FALLO: un rebote genero pulso" severity error;
    end if;

    -- 2) y 3) Senal estable: medir latencia
    wait until rising_edge(clk);
    pir_in <= '1';
    lat := 0;
    while pir_pulse /= '1' and lat < 100 loop
      wait until rising_edge(clk);
      lat := lat + 1;
    end loop;
    report "Latencia entrada->pulso = " & integer'image(lat) & " ciclos" severity note;
    if lat > FILTER_CYC + 6 then
      errs := errs + 1;
      report "FALLO: latencia excesiva" severity error;
    end if;
    wait for 10 * FILTER_CYC * CLK_PERIOD;
    pir_in <= '0';
    wait for 4 * FILTER_CYC * CLK_PERIOD;
    if pulse_count /= 1 or max_width /= 1 then
      errs := errs + 1;
      report "FALLO: se esperaba exactamente 1 pulso de 1 ciclo" severity error;
    end if;

    -- 4) Reset
    pir_in <= '1';
    wait for 2 * FILTER_CYC * CLK_PERIOD;
    rst <= '1';
    wait for 3 * CLK_PERIOD;
    if pir_level /= '0' then
      errs := errs + 1;
      report "FALLO: el reset no limpio el nivel filtrado" severity error;
    end if;
    rst <= '0';
    pir_in <= '0';
    wait for 4 * FILTER_CYC * CLK_PERIOD;

    if errs = 0 then
      report "RESULTADO tb_pir_controller: TODAS LAS PRUEBAS PASARON" severity note;
    else
      report "RESULTADO tb_pir_controller: " & integer'image(errs) & " ERRORES" severity error;
    end if;
    done <= true;
    wait;
  end process stim;

end architecture sim;
