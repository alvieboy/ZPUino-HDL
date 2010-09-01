library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;

library work;
use work.zpu_config.all;
use work.zpupkg.all;

package zpuinopkg is

  component zpuino_io is
    port (
      clk:      in std_logic;
  	 	areset:   in std_logic;
      read:     out std_logic_vector(wordSize-1 downto 0);
      write:    in std_logic_vector(wordSize-1 downto 0);
      address:  in std_logic_vector(maxAddrBitIncIO downto 0);
      we:       in std_logic;
      re:       in std_logic;
      busy:     out std_logic;
      interrupt:out std_logic;

      -- SPI program flash
      spi_pf_miso:  in std_logic;
      spi_pf_mosi:  out std_logic;
      spi_pf_sck:   out std_logic;
      spi_pf_nsel:  out std_logic

    );
  end component zpuino_io;

  component zpuino_spi is
  port (
    clk:      in std_logic;
	 	areset:   in std_logic;
    read:     out std_logic_vector(wordSize-1 downto 0);
    write:    in std_logic_vector(wordSize-1 downto 0);
    address:  in std_logic_vector(0 downto 0);
    we:       in std_logic;
    re:       in std_logic;
    busy:     out std_logic;
    interrupt:out std_logic;

    mosi:     out std_logic;
    miso:     in std_logic;
    sck:      out std_logic;
    nsel:     out std_logic
  );
  end component zpuino_spi;

end package zpuinopkg;
