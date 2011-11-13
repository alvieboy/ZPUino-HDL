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
    slot_we:    out slot_std_logic_type;
    slot_stb:   out slot_std_logic_type;
    slot_read:  in slot_cpuword_type;
    slot_write: out slot_cpuword_type;
    slot_address:  out slot_address_type;
    slot_ack:   in slot_std_logic_type;
    slot_interrupt: in slot_std_logic_type

  );
end entity zpuino_top;

architecture behave of zpuino_top is

  component zpuino_stack is
  port (
    stack_clk: in std_logic;
    stack_a_read: out std_logic_vector(wordSize-1 downto 0);
    stack_b_read: out std_logic_vector(wordSize-1 downto 0);
    stack_a_write: in std_logic_vector(wordSize-1 downto 0);
    stack_b_write: in std_logic_vector(wordSize-1 downto 0);
    stack_a_writeenable: in std_logic;
    stack_a_enable: in std_logic;
    stack_b_writeenable: in std_logic;
    stack_b_enable: in std_logic;
    stack_a_addr: in std_logic_vector(stackSize_bits-1 downto 0);
    stack_b_addr: in std_logic_vector(stackSize_bits-1 downto 0)
  );
  end component zpuino_stack;


  component clkgen is
  port (
    clkin:  in std_logic;
    rstin:  in std_logic;
    clkout: out std_logic;
    rstout: out std_logic
  );
  end component clkgen;

  component zpuino_debug is
  port (
    dbg_pc:         in std_logic_vector(maxAddrBit downto 0);
    dbg_opcode:     in std_logic_vector(7 downto 0);
    dbg_sp:         in std_logic_vector(10 downto 2);
    dbg_brk:        in std_logic;
    dbg_stacka:     in std_logic_vector(wordSize-1 downto 0);
    dbg_stackb:     in std_logic_vector(wordSize-1 downto 0)
  );
  end component;


  signal io_read:    std_logic_vector(wordSize-1 downto 0);
  signal io_write:   std_logic_vector(wordSize-1 downto 0);
  signal io_address: std_logic_vector(maxAddrBitIncIO downto 0);
  signal io_stb:     std_logic;
  signal io_cyc:     std_logic;
  signal io_we:       std_logic;
  signal io_ack:     std_logic;
  signal interrupt:  std_logic;
  signal poppc_inst: std_logic;

  signal dbg_pc:         std_logic_vector(maxAddrBit downto 0);
  signal dbg_opcode:     std_logic_vector(7 downto 0);
  signal dbg_sp:         std_logic_vector(10 downto 2);
  signal dbg_brk:        std_logic;
  signal dbg_stacka:     std_logic_vector(wordSize-1 downto 0);
  signal dbg_stackb:     std_logic_vector(wordSize-1 downto 0);

  signal stack_a_addr,stack_b_addr: std_logic_vector(stackSize_bits-1 downto 0);
  signal stack_a_writeenable, stack_b_writeenable, stack_a_enable,stack_b_enable: std_logic;
  signal stack_a_write,stack_b_write: std_logic_vector(31 downto 0);
  signal stack_a_read,stack_b_read: std_logic_vector(31 downto 0);
  signal stack_clk: std_logic;


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
	 		break         => open,

      stack_clk     => stack_clk,
      stack_a_read  => stack_a_read,
      stack_b_read  => stack_b_read,
      stack_a_write => stack_a_write,
      stack_b_write => stack_b_write,
      stack_a_writeenable => stack_a_writeenable,
      stack_b_writeenable => stack_b_writeenable,
      stack_a_enable => stack_a_enable,
      stack_b_enable => stack_b_enable,
      stack_a_addr  => stack_a_addr,
      stack_b_addr  => stack_b_addr,

      dbg_pc        => dbg_pc,
      dbg_opcode    => dbg_opcode,
      dbg_sp        => dbg_sp,
      dbg_brk       => dbg_brk,
      dbg_stacka    => dbg_stacka,
      dbg_stackb    => dbg_stackb

    );

  stack: zpuino_stack
  port map (
    stack_clk     => stack_clk,
    stack_a_read  => stack_a_read,
    stack_b_read  => stack_b_read,
    stack_a_write => stack_a_write,
    stack_b_write => stack_b_write,
    stack_a_writeenable => stack_a_writeenable,
    stack_b_writeenable => stack_b_writeenable,
    stack_a_enable => stack_a_enable,
    stack_b_enable => stack_b_enable,
    stack_a_addr  => stack_a_addr,
    stack_b_addr  => stack_b_addr
  );

--  dbg: zpuino_debug
--    port map (
--      dbg_pc        => dbg_pc,
--      dbg_opcode    => dbg_opcode,
--      dbg_sp        => dbg_sp,
--      dbg_brk       => dbg_brk,
--      dbg_stacka    => dbg_stacka,
--      dbg_stackb    => dbg_stackb
--   );

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
      slot_read     => slot_read,
      slot_write    => slot_write,
      slot_address  => slot_address,
      slot_ack      => slot_ack,
      slot_interrupt=> slot_interrupt

    );

end behave;
