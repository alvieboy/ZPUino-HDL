library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spiclkgen is
  port (
    clk:   in std_logic;
    rst:   in std_logic;
    en:    in std_logic;
    pres:  in std_logic_vector(1 downto 0);

    clkrise: out std_logic;
    clkfall: out std_logic;
    spiclk:  out std_logic

  );
end entity spiclkgen;



architecture behave of spiclkgen is

signal running_q: std_logic;
signal clkrise_i: std_logic;
signal clkfall_i: std_logic;

signal prescale_q: integer range 0 to 15;
signal prescale_load_q: integer range 0 to 15;
signal prescale_fall_cmp_q: integer range 0 to 8;

begin

clkrise <= clkrise_i;
clkfall <= clkfall_i;

genclk: process(clk)
begin
  if rising_edge(clk) then
    if rst='1' or en='0' then
      spiclk <= '0';
    else

      if clkrise_i='1' then
        spiclk<='1';
      end if;

      if clkfall_i='1' then
        spiclk<='0';
      end if;

    end if;
  end if;
end process;
    

process(clk)
begin
  if rising_edge(clk) then
    if rst='1' then
      prescale_load_q <= 0;
      prescale_fall_cmp_q <= 0;
      running_q <= '0';
    else
      if en='1' then
        if running_q='0' then
          -- Load data
          case pres is
            when "00" =>
              prescale_load_q <= 1;
              prescale_fall_cmp_q <= 1;
            when "01" =>
              prescale_load_q <= 3;
              prescale_fall_cmp_q <= 2;
            when "10" =>
              prescale_load_q <= 7;
              prescale_fall_cmp_q <= 4;
            when "11" =>
              prescale_load_q <= 15;
              prescale_fall_cmp_q <= 8;
            when others =>
          end case;
        end if;
        running_q <= '1';
      else
        running_q <= '0';
      end if;

    end if;
  end if;
end process;

process(clk)
begin
  if rising_edge(clk) then
    if rst='1' then
      prescale_q <= 0;
    else
      if running_q='1' then
        if prescale_q = 0 then
          prescale_q <= prescale_load_q;
        else
          prescale_q <= prescale_q - 1;
        end if;
      else
        prescale_q <= 0;
      end if;
    end if;
  end if;
end process;


process(clk)
begin
  if rising_edge(clk) then
    if rst='1' then
      clkrise_i<='0';
      clkfall_i<='0';
    else
      if running_q='1' and en='1' then
        if prescale_q=0 then
          clkrise_i <= '1';
        else
          clkrise_i <= '0';
        end if;

        if prescale_q = prescale_fall_cmp_q then
          clkfall_i <= '1';
        else
          clkfall_i <= '0';
        end if;
      else
        clkrise_i <= '0';
        clkfall_i <= '0';
      end if;
    end if;
  end if;
end process;

end behave;
