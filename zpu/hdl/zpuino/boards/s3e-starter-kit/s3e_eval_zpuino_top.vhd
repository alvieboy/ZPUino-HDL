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
use work.zpuino_config.all;
library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity s3e_eval_zpuino is
  port (
    CLK:          in std_logic;
    RST:          in std_logic;
    UART_RX:      in std_logic; -- gpio<0>
    GPIO:         inout std_logic_vector(zpuino_gpio_count-1 downto 1);
    FPGA_INIT_B:  out std_logic
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
    gpio_o:   out std_logic_vector(zpuino_gpio_count-1 downto 0);
    gpio_t:   out std_logic_vector(zpuino_gpio_count-1 downto 0);
    gpio_i:   in std_logic_vector(zpuino_gpio_count-1 downto 0)
  );
end component zpuino_top;



  signal sysrst:      std_logic;
  signal sysclk:      std_logic;

  signal gpio_o: std_logic_vector(zpuino_gpio_count-1 downto 0);
  signal gpio_i: std_logic_vector(zpuino_gpio_count-1 downto 0);
  signal gpio_t: std_logic_vector(zpuino_gpio_count-1 downto 0);


begin

  clkgen_inst: clkgen
  port map (
    clkin   => clk,
    rstin   => rst,
    clkout  => sysclk,
    rstout  => sysrst
  );

    -- Signals to disable (write '1')
--    DAC_CS <= '1';

--    SF_CE0 <= '1';
    FPGA_INIT_B<='0';

--    AMP_CS<='1';
    -- Signals to disable (write '0')
--    AD_CONV<='0';

--    SPI_MOSI <= spi_mosi_i;

  bufgen: for i in 1 to zpuino_gpio_count-1 generate
    iob: IOBUF
      generic map (
        IBUF_DELAY_VALUE => "0",
        SLEW => "FAST",
        DRIVE => 8,
        IFD_DELAY_VALUE => "0"
      )
      port map(
        I => gpio_o(i),
        O => gpio_i(i),
        T => gpio_t(i),
        IO => gpio(i)
      );
  end generate;

  ibufrx: IBUF
      port map (
        I => UART_RX,
        O => gpio_i(0)
      );
--  gpio_i(zpuino_gpio_count-1) <= UART_RX;


    
  zpuino:zpuino_top
  port map (
    clk           => sysclk,
	 	areset        => sysrst,
    gpio_i        =>  gpio_i,
    gpio_o        =>  gpio_o,
    gpio_t        =>  gpio_t
  );

end behave;
