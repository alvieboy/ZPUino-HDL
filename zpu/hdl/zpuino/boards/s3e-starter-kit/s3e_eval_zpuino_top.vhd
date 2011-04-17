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
use work.pad.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity s3e_eval_zpuino is
  port (
    CLK:          in std_logic;
    RST:          in std_logic;
    UART_RX:      in std_logic;
    UART_TX:      out std_logic;
    GPIO:         inout std_logic_vector(zpuino_gpio_count-1 downto 0);
    FPGA_INIT_B:  out std_logic;
    -- Rotary signals
    ROT_A:        in std_logic;
    ROT_B:        in std_logic;
    ROT_CENTER:   in std_logic
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
  generic (
    spp_cap_in: std_logic_vector(zpuino_gpio_count-1 downto 0);
    spp_cap_out: std_logic_vector(zpuino_gpio_count-1 downto 0)
  );
  port (
    clk:      in std_logic;
	 	areset:   in std_logic;
    gpio_o:   out std_logic_vector(zpuino_gpio_count-1 downto 0);
    gpio_t:   out std_logic_vector(zpuino_gpio_count-1 downto 0);
    gpio_i:   in std_logic_vector(zpuino_gpio_count-1 downto 0);
    tx:       out std_logic;
    rx:       in std_logic
  );
  end component zpuino_top;

  component zpuino_serialreset is
  generic (
    SYSTEM_CLOCK_MHZ: integer := 96
  );
  port (
    clk:      in std_logic;
    rx:       in std_logic;
    rstin:    in std_logic;
    rstout:   out std_logic
  );
  end component zpuino_serialreset;



  signal sysrst:      std_logic;
  signal sysclk:      std_logic;
  signal clkgen_rst:  std_logic;

  signal gpio_o: std_logic_vector(zpuino_gpio_count-1 downto 0);
  signal gpio_i: std_logic_vector(zpuino_gpio_count-1 downto 0);
  signal gpio_t: std_logic_vector(zpuino_gpio_count-1 downto 0);

  signal rx: std_logic;
  signal tx: std_logic;

  constant spp_cap_in: std_logic_vector(zpuino_gpio_count-1 downto 0) :=
    "00000000001111111111111111111111111111111111111111111111";
  constant spp_cap_out: std_logic_vector(zpuino_gpio_count-1 downto 0) :=
    "00000000001111111111111111111111111111111111111111111111";


begin

  rstgen: zpuino_serialreset
    generic map (
      SYSTEM_CLOCK_MHZ  => 96
    )
    port map (
      clk       => sysclk,
      rx        => rx,
      rstin     => clkgen_rst,
      rstout    => sysrst
    );

  clkgen_inst: clkgen
  port map (
    clkin   => clk,
    rstin   => rst,
    clkout  => sysclk,
    rstout  => clkgen_rst
  );

  FPGA_INIT_B<='0';

  bufgen: for i in 0 to zpuino_gpio_count-1-3 generate
    iop: IOPAD
      port map(
        I => gpio_o(i),
        O => gpio_i(i),
        T => gpio_t(i),
        C => sysclk,
        PAD => gpio(i)
      );
  end generate;

  ibufrx: IPAD port map ( PAD => UART_RX,  O => rx,  C => sysclk );
  obuftx: OPAD port map ( I => tx,   PAD => UART_TX );

  -- Rotary encoder
  rotapad: IPAD port map ( PAD => ROT_A,  O => gpio_i(53),  C => sysclk );
  rotbpad: IPAD port map ( PAD => ROT_B,  O => gpio_i(54),  C => sysclk );
  rotcpad: IPAD port map ( PAD => ROT_CENTER,  O => gpio_i(55),  C => sysclk );
  
  zpuino:zpuino_top
  generic map (
    spp_cap_in    => spp_cap_in,
    spp_cap_out   => spp_cap_out
  )
  port map (
    clk           => sysclk,
	 	areset        => sysrst,
    gpio_i        =>  gpio_i,
    gpio_o        =>  gpio_o,
    gpio_t        =>  gpio_t,
    rx            =>  rx,
    tx            =>  tx
  );

end behave;
