library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package wishbonepkg is

constant CTI_CYCLE_CLASSIC:     std_logic_vector(2 downto 0) := "000";
constant CTI_CYCLE_CONSTADDR:   std_logic_vector(2 downto 0) := "001";
constant CTI_CYCLE_INCRADDR:    std_logic_vector(2 downto 0) := "010";
constant CTI_CYCLE_ENDOFBURST:  std_logic_vector(2 downto 0) := "111";

end wishbonepkg;
