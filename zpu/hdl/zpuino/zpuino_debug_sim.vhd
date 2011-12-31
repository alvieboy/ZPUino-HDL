library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library work;
use work.zpu_config.all;
use work.zpupkg.all;
use work.zpuinopkg.all;
use work.zpuino_config.all;
use work.txt_util.all;

entity zpuino_debug_sim is
  port (
    jtag_data_chain_in: in std_logic_vector(97 downto 0);
    jtag_ctrl_chain_out: out std_logic_vector(9 downto 0)
  );
end entity;

architecture behave of zpuino_debug_sim is

  alias jtag_debug:  std_logic is jtag_ctrl_chain_out(0);
  alias jtag_inject: std_logic is jtag_ctrl_chain_out(1);
  alias jtag_opcode: std_logic_vector(7 downto 0) is jtag_ctrl_chain_out(9 downto 2);

begin

  process
  begin
    jtag_debug <= '0';
    jtag_inject <= '0';

    wait for 150 ns;

    loop
     wait for 30 ns;
      jtag_debug <= '1';
      wait for 40 ns;
      --
      jtag_opcode <= x"88";  -- IM 8
      jtag_inject <= '1';
      wait for 10 ns;
      jtag_inject <= '0';
      wait for 80 ns;

      jtag_opcode <= x"08";  -- LOAD
      jtag_inject <= '1';
      wait for 10 ns;
      jtag_inject <= '0';
      wait for 80 ns;

      jtag_opcode <= x"50";  -- STORESP 0
      jtag_inject <= '1';
      wait for 10 ns;
      jtag_inject <= '0';
      wait for 80 ns;


      jtag_debug<='0';
      wait for 60 ns;
    end loop;

    wait;

  end process;

end behave;
