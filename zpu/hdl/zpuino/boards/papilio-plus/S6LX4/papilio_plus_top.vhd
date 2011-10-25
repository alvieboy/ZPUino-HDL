--
--  ZPUINO implementation on Gadget Factory 'Papilio One' Board
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

library unisim;
use unisim.vcomponents.all;

entity papilio_plus_top is
  port (
    CLK:        in std_logic;
    --RST:        in std_logic; -- No reset on papilio

    SPI_SCK:    out std_logic;
    SPI_MISO:   in std_logic;
    SPI_MOSI:   out std_logic;
    SPI_CS:     out std_logic;

    WING_A:     inout std_logic_vector(15 downto 0);
    WING_B:     inout std_logic_vector(15 downto 0);
    WING_C:     inout std_logic_vector(15 downto 0);

--    GPIO:       inout std_logic_vector(47 downto 0);

    TXD:        out std_logic;
    RXD:        in std_logic;

    sram_addr:  out std_logic_vector(18 downto 0);
    sram_data:  inout std_logic_vector(15 downto 0);
    sram_ce:    out std_logic;
    sram_we:    out std_logic;
    sram_oe:    out std_logic;
    sram_be:    out std_logic;

    LED:        out std_logic
  );
end entity papilio_plus_top;

architecture behave of papilio_plus_top is

  signal vga_r_i: std_logic_vector(3 downto 0);
  signal vga_g_i: std_logic_vector(3 downto 0);
  signal vga_b_I: std_logic_vector(3 downto 0);

  signal VGA_RED: std_logic_vector(3 downto 0);
  signal VGA_GREEN: std_logic_vector(3 downto 0);
  signal VGA_BLUE: std_logic_vector(3 downto 0);
  signal VGA_HSYNC: std_logic;
  signal VGA_VSYNC: std_logic;


  component clkgen is
  port (
    clkin:  in std_logic;
    rstin:  in std_logic;
    clkout: out std_logic;
    vgaclkout: out std_logic;
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
    vgaclk:   in std_logic;
    gpio_o:   out std_logic_vector(zpuino_gpio_count-1 downto 0);
    gpio_t:   out std_logic_vector(zpuino_gpio_count-1 downto 0);
    gpio_i:   in std_logic_vector(zpuino_gpio_count-1 downto 0);

    tx:       out std_logic;
    rx:       in std_logic;
    -- SRAM signals
    sram_addr:  out std_logic_vector(18 downto 0);
    sram_data:  inout std_logic_vector(15 downto 0);
    sram_ce:    out std_logic;
    sram_we:    out std_logic;
    sram_oe:    out std_logic;
    sram_be:    out std_logic;

    vga_hsync: out std_logic;
    vga_vsync: out std_logic;
    vga_r: out std_logic_vector(3 downto 0);
    vga_g: out std_logic_vector(3 downto 0);
    vga_b: out std_logic_vector(3 downto 0)
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
  signal vgaclk:      std_logic;
  signal clkgen_rst:  std_logic;
  signal gpio_o:      std_logic_vector(zpuino_gpio_count-1 downto 0);
  signal gpio_t:      std_logic_vector(zpuino_gpio_count-1 downto 0);
  signal gpio_i:      std_logic_vector(zpuino_gpio_count-1 downto 0);

  signal rx: std_logic;
  signal tx: std_logic;

  constant spp_cap_in: std_logic_vector(zpuino_gpio_count-1 downto 0) :=
    "0111111111111111111111111111111111111111111111111111000";
  constant spp_cap_out: std_logic_vector(zpuino_gpio_count-1 downto 0) :=
    "0111111111111111111111111111111111111111111111111101111";

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
    --sysrst <= clkgen_rst;


  clkgen_inst: clkgen
  port map (
    clkin   => clk,
    rstin   => '0'  ,
    clkout  => sysclk,
    vgaclkout => vgaclk,
    rstout  => clkgen_rst
  );

  pin00: IOPAD port map(I => gpio_o(0),O => gpio_i(0),T => gpio_t(0),C => sysclk,PAD => WING_A(0) );
  pin01: IOPAD port map(I => gpio_o(1),O => gpio_i(1),T => gpio_t(1),C => sysclk,PAD => WING_A(1) );
  pin02: IOPAD port map(I => gpio_o(2),O => gpio_i(2),T => gpio_t(2),C => sysclk,PAD => WING_A(2) );
  pin03: IOPAD port map(I => gpio_o(3),O => gpio_i(3),T => gpio_t(3),C => sysclk,PAD => WING_A(3) );
  pin04: IOPAD port map(I => gpio_o(4),O => gpio_i(4),T => gpio_t(4),C => sysclk,PAD => WING_A(4) );
  pin05: IOPAD port map(I => gpio_o(5),O => gpio_i(5),T => gpio_t(5),C => sysclk,PAD => WING_A(5) );
  pin06: IOPAD port map(I => gpio_o(6),O => gpio_i(6),T => gpio_t(6),C => sysclk,PAD => WING_A(6) );
  pin07: IOPAD port map(I => gpio_o(7),O => gpio_i(7),T => gpio_t(7),C => sysclk,PAD => WING_A(7) );
  pin08: IOPAD port map(I => gpio_o(8),O => gpio_i(8),T => gpio_t(8),C => sysclk,PAD => WING_A(8) );
  pin09: IOPAD port map(I => gpio_o(9),O => gpio_i(9),T => gpio_t(9),C => sysclk,PAD => WING_A(9) );
  pin10: IOPAD port map(I => gpio_o(10),O => gpio_i(10),T => gpio_t(10),C => sysclk,PAD => WING_A(10) );
  pin11: IOPAD port map(I => gpio_o(11),O => gpio_i(11),T => gpio_t(11),C => sysclk,PAD => WING_A(11) );
  pin12: IOPAD port map(I => gpio_o(12),O => gpio_i(12),T => gpio_t(12),C => sysclk,PAD => WING_A(12) );
  pin13: IOPAD port map(I => gpio_o(13),O => gpio_i(13),T => gpio_t(13),C => sysclk,PAD => WING_A(13) );
  pin14: IOPAD port map(I => gpio_o(14),O => gpio_i(14),T => gpio_t(14),C => sysclk,PAD => WING_A(14) );
  pin15: IOPAD port map(I => gpio_o(15),O => gpio_i(15),T => gpio_t(15),C => sysclk,PAD => WING_A(15) );

  -- pin16: IOPAD port map(I => gpio_o(16),O => gpio_i(16),T => gpio_t(16),C => sysclk,PAD => WING_B(0) );
  pin16: OPAD port map (I => VGA_BLUE(0), PAD => WING_B(0) );

  -- pin17: IOPAD port map(I => gpio_o(17),O => gpio_i(17),T => gpio_t(17),C => sysclk,PAD => WING_B(1) );
  pin17: OPAD port map (I => VGA_BLUE(1), PAD => WING_B(1) );

  -- pin18: IOPAD port map(I => gpio_o(18),O => gpio_i(18),T => gpio_t(18),C => sysclk,PAD => WING_B(2) );
  pin18: OPAD port map (I => VGA_BLUE(2), PAD => WING_B(2) );

  -- pin19: IOPAD port map(I => gpio_o(19),O => gpio_i(19),T => gpio_t(19),C => sysclk,PAD => WING_B(3) );
  pin19: OPAD port map (I => VGA_BLUE(3), PAD => WING_B(3) );

  -- pin20: IOPAD port map(I => gpio_o(20),O => gpio_i(20),T => gpio_t(20),C => sysclk,PAD => WING_B(4) );
  pin20: OPAD port map (I => VGA_GREEN(0), PAD => WING_B(4) );

  -- pin21: IOPAD port map(I => gpio_o(21),O => gpio_i(11),T => gpio_t(21),C => sysclk,PAD => WING_B(5) );
  pin21: OPAD port map (I => VGA_GREEN(1), PAD => WING_B(5) );

  -- pin22: IOPAD port map(I => gpio_o(22),O => gpio_i(22),T => gpio_t(22),C => sysclk,PAD => WING_B(6) );
  pin22: OPAD port map (I => VGA_GREEN(2), PAD => WING_B(6) );

  -- pin23: IOPAD port map(I => gpio_o(23),O => gpio_i(23),T => gpio_t(23),C => sysclk,PAD => WING_B(7) );
  pin23: OPAD port map (I => VGA_GREEN(3), PAD => WING_B(7) );

  pin24: IOPAD port map(I => gpio_o(24),O => gpio_i(24),T => gpio_t(24),C => sysclk,PAD => WING_B(8) );
  pin25: IOPAD port map(I => gpio_o(25),O => gpio_i(25),T => gpio_t(25),C => sysclk,PAD => WING_B(9) );
  pin26: IOPAD port map(I => gpio_o(26),O => gpio_i(26),T => gpio_t(26),C => sysclk,PAD => WING_B(10) );
  pin27: IOPAD port map(I => gpio_o(27),O => gpio_i(27),T => gpio_t(27),C => sysclk,PAD => WING_B(11) );
  pin28: IOPAD port map(I => gpio_o(28),O => gpio_i(28),T => gpio_t(28),C => sysclk,PAD => WING_B(12) );
  pin29: IOPAD port map(I => gpio_o(29),O => gpio_i(29),T => gpio_t(29),C => sysclk,PAD => WING_B(13) );
  pin30: IOPAD port map(I => gpio_o(30),O => gpio_i(30),T => gpio_t(30),C => sysclk,PAD => WING_B(14) );
  pin31: IOPAD port map(I => gpio_o(31),O => gpio_i(31),T => gpio_t(31),C => sysclk,PAD => WING_B(15) );

  pin32: IOPAD port map(I => gpio_o(32),O => gpio_i(32),T => gpio_t(32),C => sysclk,PAD => WING_C(0) );
  pin33: IOPAD port map(I => gpio_o(33),O => gpio_i(33),T => gpio_t(33),C => sysclk,PAD => WING_C(1) );

  -- pin34: IOPAD port map(I => gpio_o(34),O => gpio_i(34),T => gpio_t(34),C => sysclk,PAD => WING_C(2) );
  pin34: OPAD port map (I => VGA_VSYNC, PAD => WING_C(2) );

  -- pin35: IOPAD port map(I => gpio_o(35),O => gpio_i(35),T => gpio_t(35),C => sysclk,PAD => WING_C(3) );
  pin35: OPAD port map (I => VGA_HSYNC, PAD => WING_C(3) );

  -- pin36: IOPAD port map(I => gpio_o(36),O => gpio_i(36),T => gpio_t(36),C => sysclk,PAD => WING_C(4) );
  pin36: OPAD  port map(I => VGA_RED(0), PAD=>WING_C(4));

  -- pin37: IOPAD port map(I => gpio_o(37),O => gpio_i(37),T => gpio_t(37),C => sysclk,PAD => WING_C(5) );
  pin37: OPAD  port map(I => VGA_RED(1), PAD=>WING_C(5));

  -- pin38: IOPAD port map(I => gpio_o(38),O => gpio_i(38),T => gpio_t(38),C => sysclk,PAD => WING_C(6) );
  pin38: OPAD  port map(I => VGA_RED(2), PAD=>WING_C(6));

  -- pin39: IOPAD port map(I => gpio_o(39),O => gpio_i(39),T => gpio_t(39),C => sysclk,PAD => WING_C(7) );
  pin39: OPAD  port map(I => VGA_RED(3), PAD=>WING_C(7));

  pin40: IOPAD port map(I => gpio_o(40),O => gpio_i(40),T => gpio_t(40),C => sysclk,PAD => WING_C(8) );
  pin41: IOPAD port map(I => gpio_o(41),O => gpio_i(41),T => gpio_t(41),C => sysclk,PAD => WING_C(9) );
  pin42: IOPAD port map(I => gpio_o(42),O => gpio_i(42),T => gpio_t(42),C => sysclk,PAD => WING_C(10) );
  pin43: IOPAD port map(I => gpio_o(43),O => gpio_i(43),T => gpio_t(43),C => sysclk,PAD => WING_C(11) );
  pin44: IOPAD port map(I => gpio_o(44),O => gpio_i(44),T => gpio_t(44),C => sysclk,PAD => WING_C(12) );
  pin45: IOPAD port map(I => gpio_o(45),O => gpio_i(45),T => gpio_t(45),C => sysclk,PAD => WING_C(13) );
  pin46: IOPAD port map(I => gpio_o(46),O => gpio_i(46),T => gpio_t(46),C => sysclk,PAD => WING_C(14) );
  pin47: IOPAD port map(I => gpio_o(47),O => gpio_i(47),T => gpio_t(47),C => sysclk,PAD => WING_C(15) );


  -- Other ports are special, we need to avoid outputs on input-only pins

  ibufrx:   IPAD port map ( PAD => RXD,        O => rx, C => sysclk );
  ibufmiso: IPAD port map ( PAD => SPI_MISO,   O => gpio_i(49), C => sysclk );

  obuftx:   OPAD port map ( I => tx,           PAD => TXD );
  ospiclk:  OPAD port map ( I => gpio_o(51),   PAD => SPI_SCK );
  ospics:   OPAD port map ( I => gpio_o(52),   PAD => SPI_CS );
  ospimosi: OPAD port map ( I => gpio_o(53),   PAD => SPI_MOSI );

  oled:     OPAD port map ( I => gpio_o(54),   PAD => LED );

  VGA_RED <= vga_r_i;--(0) or vga_r_i(1) or vga_r_i(2);
  VGA_GREEN <= vga_g_i;--(0) or vga_g_i(1) or vga_g_i(2);
  VGA_BLUE <= vga_b_i;--(0) or vga_b_i(1);


  zpuino:zpuino_top
  generic map (
    spp_cap_in => spp_cap_in,
    spp_cap_out => spp_cap_out
  )
  port map (
    clk           => sysclk,
	 	rst           => sysrst,
    vgaclk        => vgaclk,

    gpio_i        => gpio_i,
    gpio_t        => gpio_t,
    gpio_o        => gpio_o,

    rx => rx,
    tx => tx,

    sram_addr   => sram_addr,
    sram_data   => sram_data,
    sram_ce     => sram_ce,
    sram_be     => sram_be,
    sram_we     => sram_we,
    sram_oe     => sram_oe,

    vga_hsync     => VGA_HSYNC,
    vga_vsync     => VGA_VSYNC,
    vga_r         => vga_r_i,
    vga_g         => vga_g_i,
    vga_b         => vga_b_i
  );

end behave;
