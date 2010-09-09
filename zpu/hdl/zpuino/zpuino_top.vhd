--
--  Top module for ZPUINO
-- 
--  Copyright 2010 Alvaro Lopes <alvieboy@alvie.com>
-- 
--  Version: 1.0
-- 
--  The FreeBSD license
--  
--  Redistribution and use in source and binary forms, with or without
--  modification, are permitted provided that the following conditions
--  are met:
--  
--  1. Redistributions of source code must retain the above copyright
--     notice, this list of conditions and the following disclaimer.
--  2. Redistributions in binary form must reproduce the above
--     copyright notice, this list of conditions and the following
--     disclaimer in the documentation and/or other materials
--     provided with the distribution.
--  
--  THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY
--  EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
--  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
--  PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
--  ZPU PROJECT OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
--  INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
--  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
--  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
--  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
--  STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
--  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
--  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--  
--
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

  component clkgen is
  port (
    clkin:  in std_logic;
    rstin:  in std_logic;
    clkout: out std_logic;
    rstout: out std_logic
  );
  end component clkgen;


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

  signal sysrst:      std_logic;
  signal sysclk:      std_logic;

begin

  clkgen_inst: clkgen
  port map (
    clkin   => clk,
    rstin   => areset,
    clkout  => sysclk,
    rstout  => sysrst
  );
                      
  io_we <= mem_we;-- and mem_address(maxAddrBitIncIO-1);
  io_re <= mem_re;-- and mem_address(maxAddrBitIncIO-1);

  core: zpu_core
    port map (
      clk           => sysclk,
	 		areset        => sysrst,
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
      clk           => sysclk,
	 	  areset        => sysrst,
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
