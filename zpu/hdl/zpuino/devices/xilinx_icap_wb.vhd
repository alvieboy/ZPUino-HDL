library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library work;
use work.zpu_config.all;
use work.zpuino_config.all;
use work.zpupkg.all;
use work.zpuinopkg.all;

library unisim;
use unisim.vcomponents.all;

entity xilinx_icap_wb is
  port (
    wb_clk_i: in std_logic;
	 	wb_rst_i: in std_logic;
    wb_dat_o: out std_logic_vector(wordSize-1 downto 0);
    wb_dat_i: in std_logic_vector(wordSize-1 downto 0);
    wb_adr_i: in std_logic_vector(maxIOBit downto minIOBit);
    wb_we_i:  in std_logic;
    wb_cyc_i: in std_logic;
    wb_stb_i: in std_logic;
    wb_ack_o: out std_logic;
    wb_inta_o:out std_logic;
    id:       out slot_id
  );
end entity xilinx_icap_wb;

architecture behave of xilinx_icap_wb is

signal icap_o, icap_i: std_logic_vector(15 downto 0);
signal icap_ce: std_ulogic :='0';
signal icap_clk, icap_write, icap_busy: std_ulogic;
signal ack: std_logic := '0';

begin


  id <= x"08" & x"24";

  icapinst: ICAP_SPARTAN6 
  port map (
    BUSY  => icap_busy,
    O     => icap_o,
    CE    => icap_ce,
    CLK   => icap_clk,
    I     => icap_i,
    WRITE => icap_write
  );
  
  process(wb_clk_i)
  begin
    if rising_edge(wb_clk_i) then
      if wb_rst_i='1' then
        ack <= '0';
      else
        ack <= '0';
        if wb_cyc_i='1' and wb_stb_i='1' and ack='0' then
          ack <= not icap_busy;
        end if;
      end if;
    end if;
  end process;

  icap_ce <= not (wb_cyc_i and wb_stb_i and not ack);
  icap_clk <= wb_clk_i;
  -- Reversed bits...
  l1: for i in 0 to 7 generate
    icap_i(0+i) <= wb_dat_i(7-i);
    icap_i(8+i) <= wb_dat_i(15-i);
  end generate;

  --icap_i   <= wb_dat_i(15 downto 0);
  wb_dat_o(31 downto 0) <= (others => '0');
  --wb_dat_o(15 downto 0) <= icap_o;
  icap_write <= not wb_we_i;
  wb_ack_o<=ack;

end behave;

