library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library work;
use work.zpu_config.all;
use work.zpupkg.all;
use work.zpuinopkg.all;

entity zpuino_top is
  port (
    clk:      in std_logic;
	 	areset:   in std_logic;

    -- SPI program flash
    spi_pf_miso:  in std_logic;
    spi_pf_mosi:  out std_logic;
    spi_pf_sck:   out std_logic;
    spi_pf_nsel:  out std_logic;

    -- UART
    uart_rx:      in std_logic;
    uart_tx:      out std_logic;

    gpio:         inout std_logic_vector(31 downto 0)

  );
end entity zpuino_top;

architecture behave of zpuino_top is

  signal mem_read:    std_logic_vector(wordSize-1 downto 0);
  signal mem_write:   std_logic_vector(wordSize-1 downto 0);
  signal mem_address: std_logic_vector(maxAddrBitIncIO downto 0);
  signal mem_we:      std_logic;
  signal mem_re:      std_logic;
  signal mem_busy:    std_logic;
  signal interrupt:   std_logic;
  signal poppc_inst:  std_logic;

  signal io_we:       std_logic;
  signal io_re:       std_logic;

begin

  io_we <= mem_we;-- and mem_address(maxAddrBitIncIO-1);
  io_re <= mem_re;-- and mem_address(maxAddrBitIncIO-1);

  core: zpu_core
    port map (
      clk           => clk,
	 		areset        => areset,
	 		enable        => '1',
	 		in_mem_busy   => mem_busy,
	 		mem_read      => mem_read,
	 		mem_write     => mem_write,
	 		out_mem_addr  => mem_address,
			out_mem_writeEnable => mem_we,
			out_mem_readEnable  => mem_re,
	 		mem_writeMask => open,
	 		interrupt     => interrupt,
      poppc_inst    => poppc_inst,
	 		break         => open
    );


  io: zpuino_io
    port map (
      clk           => clk,
	 	  areset        => areset,
      read          => mem_read,
      write         => mem_write,
      address       => mem_address,
      we            => io_we,
      re            => io_re,
      busy          => mem_busy,
      interrupt     => interrupt,
      intready      => poppc_inst,

      spi_pf_miso   => spi_pf_miso,
      spi_pf_mosi   => spi_pf_mosi,
      spi_pf_sck    => spi_pf_sck,
      spi_pf_nsel   => spi_pf_nsel,

      uart_rx       => uart_rx,
      uart_tx       => uart_tx,

      gpio          => gpio
    );

end behave;
