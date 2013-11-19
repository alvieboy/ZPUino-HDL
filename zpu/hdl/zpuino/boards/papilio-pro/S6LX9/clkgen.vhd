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
    clkin:  in std_logic;
    rstin:  in std_logic;
    clkout: out std_ulogic;
    clkout1: out std_ulogic;
    clkout2: out std_ulogic;
    clkvga: out std_ulogic;
    clkp:   out std_ulogic;
    clkn:   out std_ulogic;
    rstout: out std_ulogic
  );
end entity clkgen;

architecture behave of clkgen is

signal dcmlocked: std_ulogic;
signal dcmclock: std_ulogic;

signal rst1_q: std_logic := '1';
signal rst2_q: std_logic := '1';
signal clkout_i: std_ulogic;
signal clkin_i: std_ulogic;
signal clkfb: std_ulogic;
signal clk0: std_ulogic;
signal clk1: std_ulogic;
signal clk2: std_ulogic;
signal clkin_i_2: std_logic;

signal clkvga_i, clkp_i, clkn_i: std_ulogic;
signal dcmin_clk0, dcmin_fb, clk_to_pll, dcmin_locked: std_ulogic;

begin

  clkout <= clkout_i;

  rstout <= rst1_q;

  process(dcmlocked, clkout_i, rstin, dcmin_locked)
  begin
    if dcmlocked='0' or dcmin_locked='0' or rstin='1' then
      rst1_q <= '1';
      rst2_q <= '1';
    else
      if rising_edge(clkout_i) then
        rst1_q <= rst2_q;
        rst2_q <= '0';
      end if;
    end if;
  end process;

  -- Clock buffers

  clkfx_inst: BUFG
    port map (
      I =>  clk0,
      O =>  clkout_i
    );
   
  clkin_inst: IBUFG
    port map (
      I =>  clkin,
      O =>  clkin_i
    );
   
  clkfb_inst: BUFG
    port map (
      I=> dcmclock,
      O=> clkfb
    );

  clk1_inst: BUFG port map ( I => clk1, O => clkout1 );
  clk2_inst: BUFG port map ( I => clk2, O => clkout2 );
  clkvga_inst: BUFG port map ( I => clkvga_i, O => clkvga );
  clkp_inst: BUFG port map ( I => clkp_i, O => clkp );
  clkn_inst: BUFG port map ( I => clkn_i, O => clkn );

  -- x25 / 16 == 50Mhz

  indcm: DCM
    generic map (
      CLKDV_DIVIDE => 2.0,
      CLKFX_DIVIDE => 16,
      CLKFX_MULTIPLY => 25,
      CLKIN_DIVIDE_BY_2 => FALSE,
      CLKIN_PERIOD => 31.250,
      CLKOUT_PHASE_SHIFT => "NONE",
      CLK_FEEDBACK => "1X"
  )
  port map (
    CLK0      => dcmin_clk0,
    CLKFX     => clk_to_pll,
    LOCKED    => dcmin_locked,
    CLKFB     => dcmin_fb,
    CLKIN     => clkin_i,
    RST       => '0'
  );

  dcmfb: BUFG PORT MAP ( I => dcmin_clk0, O => dcmin_fb );




pll_base_inst : PLL_ADV
  generic map
   (BANDWIDTH            => "OPTIMIZED",
    CLK_FEEDBACK         => "CLKFBOUT",
    COMPENSATION         => "DCM2PLL",
    DIVCLK_DIVIDE        => 1,
    CLKFBOUT_MULT        => 10,
    CLKFBOUT_PHASE       => 0.000,

    CLKOUT0_DIVIDE       => 5,
    CLKOUT0_PHASE        => 0.000,
    CLKOUT0_DUTY_CYCLE   => 0.500,

    CLKOUT1_DIVIDE       => 5,
    CLKOUT1_PHASE        => 250.0,--300.0,--155.52,--103.700,--343.125,
    CLKOUT1_DUTY_CYCLE   => 0.500,

    CLKOUT2_DIVIDE       => 5,
    CLKOUT2_PHASE        => 0.0,
    CLKOUT2_DUTY_CYCLE   => 0.500,

    CLKOUT3_DIVIDE       => 20,  -- 125MHz
    CLKOUT3_PHASE        => 0.0,
    CLKOUT3_DUTY_CYCLE   => 0.500,

    CLKOUT4_DIVIDE       => 4,  -- 25MHz
    CLKOUT4_PHASE        => 0.0,
    CLKOUT4_DUTY_CYCLE   => 0.500,

    CLKOUT5_DIVIDE       => 4,  -- 25MHz
    CLKOUT5_PHASE        => 180.0,
    CLKOUT5_DUTY_CYCLE   => 0.500,

    CLKIN1_PERIOD         => 20.0, -- 50 MHz
    REF_JITTER           => 0.010,
    SIM_DEVICE           => "SPARTAN6")
  port map
    -- Output clocks
   (CLKFBOUT            => dcmclock,
    CLKOUT0             => clk0,
    CLKOUT1             => clk1,
    CLKOUT2             => clk2,
    CLKOUT3             => clkvga_i,
    CLKOUT4             => clkp_i,
    CLKOUT5             => clkn_i,
    LOCKED              => dcmlocked,
    RST                 => '0',
    -- Input clock control
    CLKFBIN             => clkfb,
    CLKIN1               => clk_to_pll,
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
