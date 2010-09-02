library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

entity uart_brgen is
  port (
     clk:     in std_logic;
     rst:     in std_logic;
     en:      in std_logic;
     count:   in std_logic_vector(15 downto 0);
     clkout:  out std_logic
     );
end entity uart_brgen;

architecture behave of uart_brgen is

signal cnt: integer range 0 to 65535;

begin
  process (clk)
  begin
    if rising_edge(clk) then
      clkout <= '0';
      if rst='1' then
        cnt <= conv_integer(count);
      elsif en='1' then
        if cnt=0 then
          clkout <= '1';
          cnt <= conv_integer(count);
        else
          cnt <= cnt - 1;
        end if;
      end if;
    end if;
  end process;

end behave;
