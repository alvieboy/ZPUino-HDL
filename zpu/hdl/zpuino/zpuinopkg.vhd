--
--  ZPUINO package
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
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;

library work;
use work.zpu_config.all;
use work.zpupkg.all;
use work.zpuino_config.all;

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
      intready: in std_logic;

      -- GPIO
      gpio_o:         out std_logic_vector(zpuino_gpio_count-1 downto 0);
      gpio_t:         out std_logic_vector(zpuino_gpio_count-1 downto 0);
      gpio_i:         in std_logic_vector(zpuino_gpio_count-1 downto 0)

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

    enabled:  out std_logic
  );
  end component zpuino_spi;

  component zpuino_uart is
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

    enabled:  out std_logic;
    tx:       out std_logic;
    rx:       in std_logic
  );
  end component zpuino_uart;

  component zpuino_gpio is
  generic (
    gpio_count: integer := 32
  );
  port (
    clk:      in std_logic;
	 	areset:   in std_logic;
    read:     out std_logic_vector(wordSize-1 downto 0);
    write:    in std_logic_vector(wordSize-1 downto 0);
    address:  in std_logic_vector(8 downto 0);
    we:       in std_logic;
    re:       in std_logic;
    busy:     out std_logic;
    interrupt:out std_logic;
    spp_data: in std_logic_vector(gpio_count-1 downto 0);
    spp_read: out std_logic_vector(gpio_count-1 downto 0);
    spp_en:   in std_logic_vector(gpio_count-1 downto 0);
    gpio_o:   out std_logic_vector(gpio_count-1 downto 0);
    gpio_t:   out std_logic_vector(gpio_count-1 downto 0);
    gpio_i:   in std_logic_vector(gpio_count-1 downto 0)
  );
  end component zpuino_gpio;

  component zpuino_timers is
  port (
    clk:      in std_logic;
	 	areset:   in std_logic;
    read:     out std_logic_vector(wordSize-1 downto 0);
    write:    in std_logic_vector(wordSize-1 downto 0);
    address:  in std_logic_vector(2 downto 0);
    we:       in std_logic;
    re:       in std_logic;
    spp_data: out std_logic_vector(1 downto 0);
    spp_en:   out std_logic_vector(1 downto 0);

    busy:     out std_logic;
    interrupt:out std_logic_vector(1 downto 0)
  );
  end component zpuino_timers;

  component zpuino_intr is
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
    poppc_inst:in std_logic;

    ivecs:    in std_logic_vector(15 downto 0)
  );
  end component zpuino_intr;

  component zpuino_sigmadelta is
  generic (
    BITS: integer := 16
  );
	port (
    clk:      in std_logic;
	 	areset:   in std_logic;
    read:     out std_logic_vector(wordSize-1 downto 0);
    write:    in std_logic_vector(wordSize-1 downto 0);
    address:  in std_logic_vector(0 downto 0);
    we:       in std_logic;
    re:       in std_logic;

    -- Connection to GPIO pin
    spp_data: out std_logic_vector(1 downto 0);
    spp_en:   out std_logic_vector(1 downto 0);

    busy:     out std_logic;
    interrupt:out std_logic
  );
  end component zpuino_sigmadelta;

  component zpuino_crc16 is
  port (
    clk:      in std_logic;
	 	areset:   in std_logic;
    read:     out std_logic_vector(wordSize-1 downto 0);
    write:    in std_logic_vector(wordSize-1 downto 0);
    address:  in std_logic_vector(2 downto 0);
    we:       in std_logic;
    re:       in std_logic;
    busy:     out std_logic
  );
  end component zpuino_crc16;

  component zpuino_adc is
  port (
    clk:      in std_logic;
	 	areset:   in std_logic;
    read:     out std_logic_vector(wordSize-1 downto 0);
    write:    in std_logic_vector(wordSize-1 downto 0);
    address:  in std_logic_vector(2 downto 0);
    we:       in std_logic;
    re:       in std_logic;
    busy:     out std_logic;
    interrupt:out std_logic;

    -- GPIO SPI pins

    mosi:     out std_logic;
    miso:     in std_logic;
    sck:      out std_logic;
    seln:     out std_logic;
    enabled:  out std_logic
  );
  end component zpuino_adc;


end package zpuinopkg;
