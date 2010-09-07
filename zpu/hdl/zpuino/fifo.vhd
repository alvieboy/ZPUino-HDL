library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.std_logic_unsigned.all; 


entity fifo is
  port (
    clk:      in std_logic;
    rst:      in std_logic;
    wr:       in std_logic;
    rd:       in std_logic;
    write:    in std_logic_vector(7 downto 0);
    read :    out std_logic_vector(7 downto 0);
    full:     out std_logic;
    empty:    out std_logic
  );
end entity fifo;

architecture behave of fifo is

  type mem_t is array (0 to 15) of std_logic_vector(7 downto 0);

  signal memory:  mem_t;

  signal wraddr: unsigned(3 downto 0);
  signal rdaddr: unsigned(3 downto 0);

begin

  read <= memory( conv_integer(std_logic_vector(rdaddr)) );

  process(clk,rdaddr,wraddr)
    variable full_v: std_logic;
    variable empty_v: std_logic;
  begin
  
    if rdaddr=wraddr then
      empty_v:='1';
    else
      empty_v:='0';
    end if;

    if wraddr=rdaddr-1 then
      full_v:='1';
    else
      full_v:='0';
    end if;

    if rst='1' then
      wraddr <= (others => '0');
      rdaddr <= (others => '0');
    elsif rising_edge(clk) then

      if wr='1' and full_v='0' then
        memory(conv_integer(std_logic_vector(wraddr) ) ) <= write;
        wraddr <= wraddr+1;
      end if;

      if rd='1' and empty_v='0' then
        rdaddr <= rdaddr+1;
      end if;
    end if;

    full <= full_v;
    empty <= empty_v;

  end process;
end behave;

