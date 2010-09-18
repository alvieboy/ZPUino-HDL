--
--  ZPUINO implementation on Spartan3E Evaluation Board from Xilinx
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.zpupkg.all;
use work.zpuinopkg.all;

entity s3e_eval_zpuino is
  port (
    CLK:        in std_logic;
    RST:        in std_logic;

    SPI_SCK:    out std_logic;
    SPI_MISO:   in std_logic;
    SPI_MOSI:   out std_logic;
--    SPI_SS_B:   inout std_logic;

    LED:        inout std_logic_vector(7 downto 0);
    GPIO:       inout std_logic_vector(31 downto 0);
    -- UART
    UART_TX:    out std_logic;
    UART_RX:    in std_logic;

    -- Signals to disable (write '1')
    DAC_CS:     out std_logic;
    SF_CE0:     out std_logic;
    FPGA_INIT_B:out std_logic;
    AMP_CS:     out std_logic;
    -- Signals to disable (write '0')
    AD_CONV:    out std_logic
  );
end entity s3e_eval_zpuino;

architecture behave of s3e_eval_zpuino is

  component clkgen is
  port (
    clkin:  in std_logic;
    rstin:  in std_logic;
    clkout: out std_logic;
    rstout: out std_logic
  );
  end component clkgen;

component zpuino_top is
  port (
    clk:      in std_logic;
	 	areset:   in std_logic;

    -- SPI program flash
    spi_pf_miso:  in std_logic;
    spi_pf_mosi:  out std_logic;
    spi_pf_sck:   out std_logic;

    -- UART
    uart_rx:      in std_logic;
    uart_tx:      out std_logic;

    gpio:         inout std_logic_vector(31 downto 0)

  );
end component zpuino_top;


  signal gpio_i: std_logic_vector(31 downto 0);
  signal spi_mosi_i: std_logic;
  signal sysrst:      std_logic;
  signal sysclk:      std_logic;

begin

  clkgen_inst: clkgen
  port map (
    clkin   => clk,
    rstin   => rst,
    clkout  => sysclk,
    rstout  => sysrst
  );

    -- Signals to disable (write '1')
    DAC_CS <= '1';

    SF_CE0 <= '1';
    FPGA_INIT_B<='0';

    AMP_CS<='1';
    -- Signals to disable (write '0')
    AD_CONV<='0';

    SPI_MOSI <= spi_mosi_i;

    GPIO(31 downto 0) <= gpio_i(31 downto 0);
    
  zpuino:zpuino_top
  port map (
    clk           => sysclk,
	 	areset        => sysrst,

    -- SPI program flash
    spi_pf_miso   => SPI_MISO,
    spi_pf_mosi   => SPI_MOSI_i,
    spi_pf_sck    => SPI_SCK,

    -- UART
    uart_rx       => UART_RX,
    uart_tx       => UART_TX,

    gpio          => gpio_i
  );

end behave;
