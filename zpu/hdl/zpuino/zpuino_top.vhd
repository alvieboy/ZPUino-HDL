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
use work.zpuino_config.all;

entity zpuino_top is
  generic (
    spp_cap_in: std_logic_vector(zpuino_gpio_count-1 downto 0);
    spp_cap_out: std_logic_vector(zpuino_gpio_count-1 downto 0)
  );
  port (
    clk:      in std_logic;
	 	areset:   in std_logic;

    gpio_o:         out std_logic_vector(zpuino_gpio_count-1 downto 0);
    gpio_t:         out std_logic_vector(zpuino_gpio_count-1 downto 0);
    gpio_i:         in std_logic_vector(zpuino_gpio_count-1 downto 0);

    rx:       in std_logic;
    tx:       out std_logic
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


  signal io_read:    std_logic_vector(wordSize-1 downto 0);
  signal io_write:   std_logic_vector(wordSize-1 downto 0);
  signal io_address: std_logic_vector(maxAddrBitIncIO downto 0);
  signal io_we:      std_logic;
  signal io_re:      std_logic;
  signal io_busy:    std_logic;
  signal interrupt:   std_logic;
  signal poppc_inst:  std_logic;

begin

  core: zpu_core_small
    port map (
      clk           => clk,
	 		rst           => areset,
	 		io_busy       => io_busy,
	 		io_read       => io_read,
	 		io_write      => io_write,
      io_addr       => io_address,
			io_wr         => io_we,
			io_rd         => io_re,
	 		interrupt     => interrupt,
      poppc_inst    => poppc_inst,
	 		break         => open
    );

  io: zpuino_io
    generic map (
      spp_cap_in => spp_cap_in,
      spp_cap_out => spp_cap_out
    )
    port map (
      clk           => clk,
	 	  areset        => areset,
      read          => io_read,
      write         => io_write,
      address       => io_address,
      we            => io_we,
      re            => io_re,
      busy          => io_busy,
      interrupt     => interrupt,
      intready      => poppc_inst,
      gpio_i        => gpio_i,
      gpio_o        => gpio_o,
      gpio_t        => gpio_t,
      rx            => rx,
      tx            => tx
    );

end behave;
