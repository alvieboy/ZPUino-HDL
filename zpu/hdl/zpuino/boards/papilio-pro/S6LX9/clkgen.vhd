--
--  System Clock generator for ZPUINO (papilio one)
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
use IEEE.std_logic_1164.all; 
use IEEE.std_logic_unsigned.all; 
use ieee.numeric_std.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity clkgen is
  port (
    clkin:        in std_ulogic;
    rstin:        in std_ulogic;

    sysclk:       out std_ulogic;
    sysclk_shift: out std_ulogic;
    pixelclk:     out std_ulogic;
    tdmsclk_p:    out std_ulogic;
    tdmsclk_n:    out std_ulogic;
    rstout:       out std_ulogic
  );
end entity clkgen;

architecture behave of clkgen is

signal dcmlocked: std_ulogic;
signal dcmclock: std_ulogic;

signal rst1_q: std_ulogic := '1';
signal rst2_q: std_ulogic := '1';
signal clkout_i: std_ulogic;
signal sysclk_i: std_ulogic;
signal clkin_i: std_ulogic;

signal dcmin_clk0, dcmin_fb, clk_to_pll1: std_ulogic;
signal pll1_locked, pll2_locked, dcmin_locked: std_ulogic;
signal not_pll1_locked, not_dcmin_locked: std_ulogic;

signal sysclk_shift_i: std_ulogic;
signal pixelclk_i:     std_ulogic;
signal tdmsclk_p_i:    std_ulogic;
signal tdmsclk_n_i:    std_ulogic;

signal clk_to_pll2_i, clk_to_pll2: std_ulogic;
signal pll2_to_clkfb, clkfb_to_pll2: std_ulogic;
signal clkfb_to_pll1, pll1_to_clkfb: std_ulogic;

begin

  rstout <= rst1_q;
  sysclk <= clkout_i;

  process(clkout_i, rstin, dcmin_locked, pll1_locked, pll2_locked)
  begin
    if pll1_locked='0' or dcmin_locked='0' or pll2_locked='0' or rstin='1' then
      rst1_q <= '1';
      rst2_q <= '1';
    else
      if rising_edge(clkout_i) then
        rst1_q <= rst2_q;
        rst2_q <= '0';
      end if;
    end if;
  end process;

  -- Clock buffers - input

  clkin_inst: IBUFG  port map ( I => clkin,       O =>  clkin_i );

  -- Clock buffers - output

  clk0_inst: BUFG port map ( I => sysclk_i,       O => clkout_i );
  clk1_inst: BUFG port map ( I => sysclk_shift_i, O => sysclk_shift );
  clk2_inst: BUFG port map ( I => pixelclk_i,     O => pixelclk );
  clkp_inst: BUFG port map ( I => tdmsclk_p_i,    O => tdmsclk_p );
  clkn_inst: BUFG port map ( I => tdmsclk_n_i,    O => tdmsclk_n );

  -- Clock buffers - internal

  -- 1st DCM feedback clock
  dcmfb:      BUFG   port map ( I => dcmin_clk0,  O => dcmin_fb );

  -- pll1 to pll2 BUFG
  pll2_in_bufg_inst: BUFG port map ( I => clk_to_pll2_i, O => clk_to_pll2 );

  -- pll1 feedback clock
  pll1_fb_bufg_inst: BUFG port map ( I => pll1_to_clkfb, O => clkfb_to_pll1 );
  -- pll2 feedback clock
  pll2_fb_bufg_inst: BUFG port map ( I => pll2_to_clkfb, O => clkfb_to_pll2 );


  not_pll1_locked <= not pll1_locked;
  not_dcmin_locked <= not dcmin_locked;

  indcm: DCM
    generic map (
      CLKDV_DIVIDE => 2.0,
      CLKFX_DIVIDE => 32,--16,
      CLKFX_MULTIPLY => 27,--25,
      CLKIN_DIVIDE_BY_2 => FALSE,
      CLKIN_PERIOD => 31.250,
      CLKOUT_PHASE_SHIFT => "NONE",
      CLK_FEEDBACK => "1X"
  )
  port map (
    CLK0      => dcmin_clk0,
    CLKFX     => clk_to_pll1, -- no bufg
    LOCKED    => dcmin_locked,
    CLKFB     => dcmin_fb,
    CLKIN     => clkin_i,
    RST       => '0'
  );

pll_base_inst : PLL_ADV
  generic map
   (BANDWIDTH            => "OPTIMIZED",
    CLK_FEEDBACK         => "CLKFBOUT",
    COMPENSATION         => "DCM2PLL",
    DIVCLK_DIVIDE        => 1,
    CLKFBOUT_MULT        => 22,
    CLKFBOUT_PHASE       => 0.000,

    CLKOUT0_DIVIDE       => 6,      -- 99Mhz
    CLKOUT0_PHASE        => 120.000,
    CLKOUT0_DUTY_CYCLE   => 0.500,

    CLKOUT1_DIVIDE       => 6,      -- 99Mhz
    CLKOUT1_PHASE        => 10.0,--300.0,--155.52,--103.700,--343.125,
    CLKOUT1_DUTY_CYCLE   => 0.500,

    CLKOUT2_DIVIDE       => 8,  -- 74.25MHz - to next PLL
    CLKOUT2_PHASE        => 0.0,
    CLKOUT2_DUTY_CYCLE   => 0.500,

    CLKOUT3_DIVIDE       => 8,  -- 74.25MHz - pixel clock
    CLKOUT3_PHASE        => 0.0,
    CLKOUT3_DUTY_CYCLE   => 0.500,

    CLKIN1_PERIOD         => 37.037037, -- 27 MHz
   -- REF_JITTER           => 0.010,
    SIM_DEVICE           => "SPARTAN6")
  port map
    -- Output clocks
   (CLKFBOUT            => pll1_to_clkfb,
    CLKOUT0             => sysclk_i,
    CLKOUT1             => sysclk_shift_i,
    CLKOUT2             => clk_to_pll2_i,
    CLKOUT3             => pixelclk_i,
    LOCKED              => pll1_locked,
    RST                 => not_dcmin_locked,   -- Keep in reset while DCM does not lock
    -- Input clock control
    CLKFBIN             => clkfb_to_pll1,
    CLKIN1              => clk_to_pll1,
    CLKIN2 => '0',
    CLKINSEL => '1',
    DADDR => (others => '0'),
    DCLK => '0',
    DEN => '0',
    DI => (others => '0'),
    DWE => '0',
    REL => '0'
   );

pll_base_inst2 : PLL_ADV
  generic map
   (BANDWIDTH            => "OPTIMIZED",
    CLK_FEEDBACK         => "CLKFBOUT",
    COMPENSATION         => "SOURCE_SYNCHRONOUS",
    DIVCLK_DIVIDE        => 1,
    CLKFBOUT_MULT        => 10,
    CLKFBOUT_PHASE       => 0.000,

    CLKOUT0_DIVIDE       => 2,      -- 371.25Mhz
    CLKOUT0_PHASE        => 00.000,
    CLKOUT0_DUTY_CYCLE   => 0.500,

    CLKOUT1_DIVIDE       => 2,      -- 371.25Mhz, inverted clock
    CLKOUT1_PHASE        => 180.0,
    CLKOUT1_DUTY_CYCLE   => 0.500,

    CLKIN1_PERIOD         => 13.46, -- 74.25 MHz
    --REF_JITTER           => 0.010,
    SIM_DEVICE           => "SPARTAN6")
  port map
    -- Output clocks
   (CLKFBOUT            => pll2_to_clkfb,
    CLKOUT0             => tdmsclk_p_i,
    CLKOUT1             => tdmsclk_n_i,
    LOCKED              => pll2_locked,
    RST                 => not_pll1_locked, -- Keep reset while PLL1 does not lock
    -- Input clock control
    CLKFBIN             => clkfb_to_pll2,
    CLKIN1              => clk_to_pll2,
    CLKIN2 => '0',
    CLKINSEL => '1',
    DADDR => (others => '0'),
    DCLK => '0',
    DEN => '0',
    DI => (others => '0'),
    DWE => '0',
    REL => '0'
   );

end behave;
