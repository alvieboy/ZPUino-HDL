library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity prescaler is
  port (
    clk:    in std_logic;
    rst:    in std_logic;
    prescale:   in std_logic_vector(2 downto 0);
    event:  out std_logic                       
  );
end entity prescaler;

architecture behave of prescaler is

signal counter: unsigned(9 downto 0);

signal ck2:     std_logic;
signal ck4:     std_logic;
signal ck8:     std_logic;
signal ck16:     std_logic;
signal ck64:    std_logic;
signal ck256:   std_logic;
signal ck1024:  std_logic;

begin

ck2 <= counter(0);
ck4 <= counter(1);
ck8 <= counter(2);
ck16 <= counter(3);
ck64 <= counter(5);
ck256 <= counter(7);
ck1024 <= counter(9);

process(prescale,ck2,ck4,ck8,ck16,ck64,ck256,ck1024)
begin
  case prescale is
    when "000" =>
      event <= '1';
    when "001" =>
      event <= ck2;
    when "010" =>
      event <= ck4;
    when "011" =>
      event <= ck8;
    when "100" =>
      event <= ck16;
    when "101" =>
      event <= ck64;
    when "110" =>
      event <= ck256;
    when "111" =>
      event <= ck1024;
    when others =>
  end case;
end process;

process(clk)
begin
  if rising_edge(clk) then
    if rst='1' then
      counter <= (others=>'0');
    else
      counter<=counter + 1;
    end if;
  end if;
end process;

end behave;
