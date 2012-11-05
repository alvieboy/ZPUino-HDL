library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
library work;
use work.zpu_config.all;
use work.wishbonepkg.all;

entity wbmux2 is
  generic (
    select_line: integer;
    address_high: integer:=31;
    address_low: integer:=2
  );
  port (
    syscon:   in wb_syscon_type;
    -- Master 
    mwbi:     in wb_mosi_type;
    mwbo:     out wb_miso_type;
    -- Slave 0 signals
    s0wbo:    out wb_mosi_type;
    s0wbi:    in wb_miso_type;
    -- Slave 1 signals
    s1wbo:    out wb_mosi_type;
    s1wbi:    in wb_miso_type
  );
end entity wbmux2;

architecture behave of wbmux2 is

signal select_zero: std_logic;

begin

select_zero<='1' when mwbi.adr(select_line)='0' else '0';

s0wbo.dat <= mwbi.dat;
s0wbo.adr <= mwbi.adr;
s0wbo.stb <= mwbi.stb;
s0wbo.we  <= mwbi.we;
s0wbo.cti <= mwbi.cti;
s0wbo.sel <= mwbi.sel;

s1wbo.dat <= mwbi.dat;
s1wbo.adr <= mwbi.adr;
s1wbo.stb <= mwbi.stb;
s1wbo.we  <= mwbi.we;
s1wbo.cti <= mwbi.cti;
s1wbo.sel <= mwbi.sel;

process(mwbi.cyc,select_zero)
begin
  if mwbi.cyc='0' then
    s0wbo.cyc<='0';
    s1wbo.cyc<='0';
  else
    s0wbo.cyc<=select_zero;
    s1wbo.cyc<=not select_zero;
  end if;
end process;

process(select_zero,s1wbi,s0wbi)
begin
  if select_zero='0' then
    mwbo.dat  <=s0wbi.dat;
    mwbo.ack  <=s0wbi.ack;
    mwbo.stall<=s0wbi.stall;
  else
    mwbo.dat  <=s1wbi.dat;
    mwbo.ack  <=s1wbi.ack;
    mwbo.stall<=s1wbi.stall;
  end if;
end process;

end behave;
