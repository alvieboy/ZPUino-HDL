library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.wishbonepkg.all;

entity ocram is
  generic (
    address_bits: natural := 11
  );
  port (
    syscon:     in wb_syscon_type;
    wbi:        in wb_mosi_type;
    wbo:        out wb_p_miso_type
  );
end entity ocram;

architecture behave of ocram is

  signal ack: std_logic;
  signal en:  std_logic;

begin

  wbo.int<='0';
  wbo.err<='0';
  wbo.ack<=ack;
  wbo.stall<='0';
  en<=wbi.cyc and wbi.stb;

  process(syscon.clk)
  begin
    if rising_edge(syscon.clk) then
      wbo.tag <= wbi.tag;
      if syscon.rst='1' then
        ack<='0';
      else
        ack<='0';
        if en='1' then
          ack<='1';
        end if;
      end if;
    end if;
  end process;

  raminst: entity work.generic_sp_ram
  generic map (
    address_bits => address_bits,
    data_bits    => 32
  )
  port map (
    clka    => syscon.clk,
    ena     => en,
    wea     => wbi.we,
    addra   => wbi.adr(address_bits+1 downto 2),
    dia     => wbi.dat,
    doa     => wbo.dat
  );                    

end behave;
