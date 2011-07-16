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
	 	rst:      in std_logic;
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
    "00000000001111000001111100000000111111111111111111111111";
  constant spp_cap_out: std_logic_vector(zpuino_gpio_count-1 downto 0) :=
    "00000000001111000001111100000000111111111111111111111111";


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


  buf0: IOPAD port map (I => gpio_o(0),  O => gpio_i(0),  T => gpio_t(0), C => sysclk, PAD => GPIO(0) );
  buf1: IOPAD port map (I => gpio_o(1),  O => gpio_i(1),  T => gpio_t(1), C => sysclk, PAD => GPIO(1) );
  buf2: IOPAD port map (I => gpio_o(2),  O => gpio_i(2),  T => gpio_t(2), C => sysclk, PAD => GPIO(2) );
  buf3: IOPAD port map (I => gpio_o(3),  O => gpio_i(3),  T => gpio_t(3), C => sysclk, PAD => GPIO(3) );
  buf4: IOPAD port map (I => gpio_o(4),  O => gpio_i(4),  T => gpio_t(4), C => sysclk, PAD => GPIO(4) );
  buf5: IOPAD port map (I => gpio_o(5),  O => gpio_i(5),  T => gpio_t(5), C => sysclk, PAD => GPIO(5) );
  buf6: IOPAD port map (I => gpio_o(6),  O => gpio_i(6),  T => gpio_t(6), C => sysclk, PAD => GPIO(6) );
  buf7: IOPAD port map (I => gpio_o(7),  O => gpio_i(7),  T => gpio_t(7), C => sysclk, PAD => GPIO(7) );
  buf8: IOPAD port map (I => gpio_o(8),  O => gpio_i(8),  T => gpio_t(8), C => sysclk, PAD => GPIO(8) );
  buf9: IOPAD port map (I => gpio_o(9),  O => gpio_i(9),  T => gpio_t(9), C => sysclk, PAD => GPIO(9) );
  buf10: IOPAD port map (I => gpio_o(10),  O => gpio_i(10),  T => gpio_t(10), C => sysclk, PAD => GPIO(10) );
  buf11: IOPAD port map (I => gpio_o(11),  O => gpio_i(11),  T => gpio_t(11), C => sysclk, PAD => GPIO(11) );
  buf12: IOPAD port map (I => gpio_o(12),  O => gpio_i(12),  T => gpio_t(12), C => sysclk, PAD => GPIO(12) );
  buf13: IOPAD port map (I => gpio_o(13),  O => gpio_i(13),  T => gpio_t(13), C => sysclk, PAD => GPIO(13) );
  buf14: IOPAD port map (I => gpio_o(14),  O => gpio_i(14),  T => gpio_t(14), C => sysclk, PAD => GPIO(14) );
  buf15: IOPAD port map (I => gpio_o(15),  O => gpio_i(15),  T => gpio_t(15), C => sysclk, PAD => GPIO(15) );
  buf16: IOPAD port map (I => gpio_o(16),  O => gpio_i(16),  T => gpio_t(16), C => sysclk, PAD => GPIO(16) );
  buf17: IOPAD port map (I => gpio_o(17),  O => gpio_i(17),  T => gpio_t(17), C => sysclk, PAD => GPIO(17) );
  buf18: IOPAD port map (I => gpio_o(18),  O => gpio_i(18),  T => gpio_t(18), C => sysclk, PAD => GPIO(18) );
  buf19: IOPAD port map (I => gpio_o(19),  O => gpio_i(19),  T => gpio_t(19), C => sysclk, PAD => GPIO(19) );
  buf20: IOPAD port map (I => gpio_o(20),  O => gpio_i(20),  T => gpio_t(20), C => sysclk, PAD => GPIO(20) );
  buf21: IOPAD port map (I => gpio_o(21),  O => gpio_i(21),  T => gpio_t(21), C => sysclk, PAD => GPIO(21) );
  buf22: IOPAD port map (I => gpio_o(22),  O => gpio_i(22),  T => gpio_t(22), C => sysclk, PAD => GPIO(22) );
  buf23: IOPAD port map (I => gpio_o(23),  O => gpio_i(23),  T => gpio_t(23), C => sysclk, PAD => GPIO(23) );

  -- LEDs use Output buffers only

  buf24:  OPAD port map (I => gpio_o(24), PAD => GPIO(24) );
  buf25:  OPAD port map (I => gpio_o(25), PAD => GPIO(25) );
  buf26:  OPAD port map (I => gpio_o(26), PAD => GPIO(26) );
  buf27:  OPAD port map (I => gpio_o(27), PAD => GPIO(27) );
  buf28:  OPAD port map (I => gpio_o(28), PAD => GPIO(28) );
  buf29:  OPAD port map (I => gpio_o(29), PAD => GPIO(29) );
  buf30:  OPAD port map (I => gpio_o(30), PAD => GPIO(30) );
  buf31:  OPAD port map (I => gpio_o(31), PAD => GPIO(31) );

  buf32: IOPAD port map (I => gpio_o(32),  O => gpio_i(32),  T => gpio_t(32), C => sysclk, PAD => GPIO(32) );
  buf33: IOPAD port map (I => gpio_o(33),  O => gpio_i(33),  T => gpio_t(33), C => sysclk, PAD => GPIO(33) );
  buf34: IOPAD port map (I => gpio_o(34),  O => gpio_i(34),  T => gpio_t(34), C => sysclk, PAD => GPIO(34) );
  buf35: IOPAD port map (I => gpio_o(35),  O => gpio_i(35),  T => gpio_t(35), C => sysclk, PAD => GPIO(35) );

  buf36:  OPAD port map (I => gpio_o(36), PAD => GPIO(36) ); -- AD_CONV
  buf37:  OPAD port map (I => gpio_o(37), PAD => GPIO(37) ); -- DAC_CS
  buf38:  OPAD port map (I => gpio_o(38), PAD => GPIO(38) ); -- AMP_CS
  buf39:  OPAD port map (I => gpio_o(39), PAD => GPIO(39) ); -- SF_CE0
  buf40:  OPAD port map (I => gpio_o(40), PAD => GPIO(40) ); -- SPI_SS_B

  buf41: IOPAD port map (I => gpio_o(41),  O => gpio_i(41),  T => gpio_t(41), C => sysclk, PAD => GPIO(41) );
  buf42: IOPAD port map (I => gpio_o(42),  O => gpio_i(42),  T => gpio_t(42), C => sysclk, PAD => GPIO(42) );
  buf43: IOPAD port map (I => gpio_o(43),  O => gpio_i(43),  T => gpio_t(43), C => sysclk, PAD => GPIO(43) );
  buf44: IOPAD port map (I => gpio_o(44),  O => gpio_i(44),  T => gpio_t(44), C => sysclk, PAD => GPIO(44) );

  buf45:  OPAD port map (I => gpio_o(45), PAD => GPIO(45) ); -- AMP_SHDN
  buf46:  OPAD port map (I => gpio_o(46), PAD => GPIO(46) ); -- LCD_RS
  buf47:  OPAD port map (I => gpio_o(47), PAD => GPIO(47) ); -- LCD_RW

  buf48: IOPAD port map (I => gpio_o(48),  O => gpio_i(48),  T => gpio_t(48), C => sysclk, PAD => GPIO(48) );
  buf49: IOPAD port map (I => gpio_o(49),  O => gpio_i(49),  T => gpio_t(49), C => sysclk, PAD => GPIO(49) );
  buf50: IOPAD port map (I => gpio_o(50),  O => gpio_i(50),  T => gpio_t(50), C => sysclk, PAD => GPIO(50) );
  buf51: IOPAD port map (I => gpio_o(51),  O => gpio_i(51),  T => gpio_t(51), C => sysclk, PAD => GPIO(51) );

  buf52:  OPAD port map (I => gpio_o(52), PAD => GPIO(52) ); -- LCD_E

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
	 	rst           => sysrst,
    gpio_i        =>  gpio_i,
    gpio_o        =>  gpio_o,
    gpio_t        =>  gpio_t,
    rx            =>  rx,
    tx            =>  tx
  );

end behave;
