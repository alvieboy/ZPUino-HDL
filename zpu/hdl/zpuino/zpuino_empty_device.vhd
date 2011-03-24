library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library work;
use work.zpu_config.all;
use work.zpuino_config.all;
use work.zpupkg.all;
use work.zpuinopkg.all;

entity zpuino_empty_device is
  port (
    clk:      in std_logic;
	 	rst:      in std_logic;
    read:     out std_logic_vector(wordSize-1 downto 0);
    write:    in std_logic_vector(wordSize-1 downto 0);
    address:  in std_logic_vector(10 downto 2);
    we:       in std_logic;
    re:       in std_logic;
    busy:     out std_logic;
    interrupt:out std_logic
  );
end entity zpuino_empty_device;

architecture behave of zpuino_empty_device is

begin

  busy <= '0';
  interrupt <= '0';
  read <= (others => DontCareValue);


end behave;

