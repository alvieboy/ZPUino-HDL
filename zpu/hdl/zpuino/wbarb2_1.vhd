library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
library work;
use work.zpu_config.all;
use work.wishbonepkg.all;

entity wbarb2_1 is
  generic (
    ADDRESS_HIGH: integer := maxIObit;
    ADDRESS_LOW: integer := maxIObit
  );
  port (
    syscon:   in wb_syscon_type;
    -- Master 0 signals
    m0wbi:    in wb_mosi_type;
    m0wbo:    out wb_miso_type;
    -- Master 1 signals
    m1wbi:    in wb_mosi_type;
    m1wbo:    out wb_miso_type;
    -- Slave signals
    s0wbi:    in wb_miso_type;
    s0wbo:    out wb_mosi_type
  );
end entity wbarb2_1;



architecture behave of wbarb2_1 is

signal current_master: std_logic;
signal next_master: std_logic;
begin

process(syscon.clk)
begin
  if rising_edge(syscon.clk) then
    if syscon.rst='1' then
      current_master <= '0';
    else
      current_master <= next_master;
    end if;
  end if;
end process;


process(current_master, m0wbi.cyc, m1wbi.cyc)
begin
  next_master <= current_master;

  case current_master is
    when '0' =>
      if m0wbi.cyc='0' then
        if m1wbi.cyc='1' then
          next_master <= '1';
        end if;
      end if;
    when '1' =>
      if m1wbi.cyc='0' then
        if m0wbi.cyc='1' then
          next_master <= '0';
        end if;
      end if;
    when others =>
  end case;
end process;

-- Muxers for slave

process(current_master, m0wbi, m1wbi)
begin
  case current_master is
    when '0' =>
      s0wbo <= m0wbi;
    when '1' =>
      s0wbo <= m1wbi;
    when others =>
      null;
  end case;
end process;

-- Muxers/sel for masters

m0wbo.dat <= s0wbi.dat;
m1wbo.dat <= s0wbi.dat;

-- Ack

m0wbo.ack <= s0wbi.ack when current_master='0' else '0';
m1wbo.ack <= s0wbi.ack when current_master='1' else '0';

m0wbo.stall <= s0wbi.stall when current_master='0' else '1';
m1wbo.stall <= s0wbi.stall when current_master='1' else '1';

m0wbo.int <= s0wbi.int;
m1wbo.int <= s0wbi.int;

end behave;
