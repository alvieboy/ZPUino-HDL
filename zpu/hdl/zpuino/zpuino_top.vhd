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
  port (
    clk:      in std_logic;
	 	rst:      in std_logic;

    -- Connection to board IO module

    slot_cyc:   out slot_std_logic_type;
    slot_we:    out std_logic;
    slot_stb:   out std_logic;
    slot_0_read:      in cpuword_type := (others => DontCareValue);
    slot_1_read:      in cpuword_type := (others => DontCareValue);
    slot_2_read:      in cpuword_type := (others => DontCareValue);
    slot_3_read:      in cpuword_type := (others => DontCareValue);
    slot_4_read:      in cpuword_type := (others => DontCareValue);
    slot_5_read:      in cpuword_type := (others => DontCareValue);
    slot_6_read:      in cpuword_type := (others => DontCareValue);
    slot_7_read:      in cpuword_type := (others => DontCareValue);
    slot_8_read:      in cpuword_type := (others => DontCareValue);
    slot_9_read:      in cpuword_type := (others => DontCareValue);
    slot_10_read:      in cpuword_type := (others => DontCareValue);
    slot_11_read:      in cpuword_type := (others => DontCareValue);
    slot_12_read:      in cpuword_type := (others => DontCareValue);
    slot_13_read:      in cpuword_type := (others => DontCareValue);
    slot_14_read:      in cpuword_type := (others => DontCareValue);
    slot_15_read:      in cpuword_type := (others => DontCareValue);
    slot_write: out std_logic_vector(wordSize-1 downto 0);
    slot_address:  out address_type;
    slot_ack:   in slot_std_logic_type;
    slot_interrupt: in slot_std_logic_type

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
  signal io_stb:     std_logic;
  signal io_cyc:     std_logic;
  signal io_we:       std_logic;
  signal io_ack:     std_logic;
  signal interrupt:  std_logic;
  signal poppc_inst: std_logic;

begin

  core: zpu_core_small
    port map (
      wb_clk_i      => clk,
	 		wb_rst_i      => rst,
	 		wb_ack_i      => io_ack,
	 		wb_dat_i      => io_read,
	 		wb_dat_o      => io_write,
      wb_adr_o      => io_address,
			wb_cyc_o      => io_cyc,
			wb_stb_o      => io_stb,
      wb_we_o       => io_we,
	 		wb_inta_i     => interrupt,

      poppc_inst    => poppc_inst,
	 		break         => open
    );

  io: zpuino_io
    port map (
      wb_clk_i      => clk,
	 	  wb_rst_i      => rst,
      wb_dat_o      => io_read,
      wb_dat_i      => io_write,
      wb_adr_i      => io_address,
      wb_cyc_i      => io_cyc,
      wb_stb_i      => io_stb,
      wb_ack_o      => io_ack,
      wb_we_i       => io_we,
      wb_inta_o     => interrupt,

      intready      => poppc_inst,

      slot_cyc      => slot_cyc,
      slot_we       => slot_we,
      slot_stb      => slot_stb,
      slot_0_read     => slot_0_read,
      slot_1_read     => slot_1_read,
      slot_2_read     => slot_2_read,
      slot_3_read     => slot_3_read,
      slot_4_read     => slot_4_read,
      slot_5_read     => slot_5_read,
      slot_6_read     => slot_6_read,
      slot_7_read     => slot_7_read,
      slot_8_read     => slot_8_read,
      slot_9_read     => slot_9_read,
      slot_10_read     => slot_10_read,
      slot_11_read     => slot_11_read,
      slot_12_read     => slot_12_read,
      slot_13_read     => slot_13_read,
      slot_14_read     => slot_14_read,
      slot_15_read     => slot_14_read,
      slot_write    => slot_write,
      slot_address  => slot_address,
      slot_ack      => slot_ack,
      slot_interrupt=> slot_interrupt

    );

end behave;
