library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.zpu_config.all;
use work.zpupkg.all;
use work.zpuinopkg.all;

entity zpuino_gpio is
  port (
    clk:      in std_logic;
	 	areset:   in std_logic;
    read:     out std_logic_vector(wordSize-1 downto 0);
    write:    in std_logic_vector(wordSize-1 downto 0);
    address:  in std_logic_vector(0 downto 0);
    we:       in std_logic;
    re:       in std_logic;
    busy:     out std_logic;
    interrupt:out std_logic;

    gpio:     inout std_logic_vector(31 downto 0)
  );
end entity zpuino_gpio;


architecture behave of zpuino_gpio is

signal gpio_q: std_logic_vector(31 downto 0);
signal gpio_tris_q: std_logic_vector(31 downto 0);

begin

tgen: for i in 0 to 31 generate
  gpio(i) <= gpio_q(i) when gpio_tris_q(i)='0' else 'Z';
end generate;

process(address,gpio,gpio_tris_q)
begin
  read <= (others => '0');
  case address is
    when "0" =>
      read <= gpio;
    when "1" =>
      read <= gpio_tris_q;
    when others =>
  end case;
end process;

process(clk)
begin
  if rising_edge(clk) then
    if areset='1' then
      gpio_tris_q <= (others => '1');
    elsif we='1' then
      case address is
        when "0" =>
          gpio_q <= write;
        when "1" =>
          gpio_tris_q <= write;
        when others =>
      end case;
    end if;
  end if;
end process;

end behave;

