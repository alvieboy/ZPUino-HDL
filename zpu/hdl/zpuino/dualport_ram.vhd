library IEEE;
use IEEE.std_logic_1164.all; 
use IEEE.std_logic_unsigned.all; 
use ieee.numeric_std.all;

entity dualport_ram is
  port (
    clk:              in std_logic;
    memAWriteEnable:  in std_logic;
    memAAddr:         in std_logic_vector(14 downto 2);
    memAWrite:        in std_logic_vector(31 downto 0);
    memARead:         out std_logic_vector(31 downto 0);
    memBWriteEnable:  in std_logic;
    memBAddr:         in std_logic_vector(14 downto 2);
    memBWrite:        in std_logic_vector(31 downto 0);
    memBRead:         out std_logic_vector(31 downto 0)
  );
end entity dualport_ram;

architecture behave of dualport_ram is


  subtype RAM_WORD is STD_LOGIC_VECTOR (31 downto 0);
  type RAM_TABLE is array (0 to 8191) of RAM_WORD;

  shared variable RAM: RAM_TABLE;
--  signal read_a: std_logic_vector(12 downto 0);
--  signal read_b: std_logic_vector(12 downto 0);

begin

  process (clk)
--    variable ra: std_logic_vector(12 downto 0);
  begin
    if rising_edge(clk) then
--      ra(12 downto 0) := memAAddr(14 downto 2);
 --     read_a <= ra;
      if memAWriteEnable='1' then
        RAM( conv_integer(memAAddr) ) := memAWrite;
      end if;
      memARead <= RAM(conv_integer(memAAddr)) ;
    end if;
  end process;  

--  memARead <= RAM(conv_integer(read_a));

  process (clk)
--    variable rb: std_logic_vector(12 downto 0);
  begin
    if rising_edge(clk) then
--      rb(12 downto 0) := memBAddr(14 downto 2);
--      read_b <= rb;
      if memBWriteEnable='1' then
        RAM( conv_integer(memBAddr) ) := memBWrite;
      end if;
      memBRead <= RAM(conv_integer(memBAddr)) ;
    end if;
  end process;  

--  memBRead <= ROM(conv_integer(read_b));

end behave; 
