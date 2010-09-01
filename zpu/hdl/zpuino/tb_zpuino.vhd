library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_zpuino is
end entity;

architecture behave of tb_zpuino is

  constant period : time := 20 ns;

  signal w_clk : std_logic := '0';
  signal w_rst : std_logic := '0';

  component zpuino_top is
  port (
    clk:      in std_logic;
	 	areset:   in std_logic;

    -- SPI program flash
    spi_pf_miso:  in std_logic;
    spi_pf_mosi:  out std_logic;
    spi_pf_sck:   out std_logic;
    spi_pf_nsel:  out std_logic

  );
  end component zpuino_top;


begin

  top: zpuino_top
    port map (
      clk     => w_clk,
	 	  areset   => w_rst,
      spi_pf_miso => '0'
  );

  w_clk <= not w_clk after period/2;

  stimuli : process
   begin
      w_rst   <= '0';
      wait for 1 ns;
      w_rst   <= '1';
      wait for 80 ns;
      w_rst   <= '0';
      wait;
   end process;

end behave;
