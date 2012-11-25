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
use work.wishbonepkg.all;

entity zcorev3_top is
  port (
    syscon:   in wb_syscon_type;

    -- Connection to board IO module

    slot_cyc:   out slot_std_logic_type;
    slot_we:    out slot_std_logic_type;
    slot_stb:   out slot_std_logic_type;
    slot_read:  in slot_cpuword_type;
    slot_write: out slot_cpuword_type;
    slot_address:  out slot_address_type;
    slot_ack:   in slot_std_logic_type;
    slot_interrupt: in slot_std_logic_type;

    dbg_reset:  out std_logic;
    memory_enable: out std_logic;

    dma_wbo:    out wb_miso_type;
    dma_wbi:    in wb_mosi_type;

    -- Memory connection
    ram_wbo:    out wb_mosi_type;
    ram_wbi:    in wb_miso_type;

    -- ROM/Memory connection
    rom_wbo:    out wb_mosi_type;
    rom_wbi:    in wb_miso_type;

    jtag_data_chain_out: out std_logic_vector(98 downto 0);
    jtag_ctrl_chain_in: in std_logic_vector(11 downto 0)

  );
end entity zcorev3_top;

architecture behave of zcorev3_top is


  component zpuino_debug_core is
  port (
    clk: in std_logic;
    rst: in std_logic;

    dbg_in:         in zpu_dbg_out_type;
    dbg_out:        out zpu_dbg_in_type;
    dbg_reset:      out std_logic;

    jtag_data_chain_out: out std_logic_vector(98 downto 0);
    jtag_ctrl_chain_in: in std_logic_vector(11 downto 0)

  );
  end component;

  --signal interrupt:  std_logic;
  signal poppc_inst: std_logic;

  signal dbg_pc:         std_logic_vector(maxAddrBit downto 0);
  signal dbg_opcode:     std_logic_vector(7 downto 0);
  signal dbg_opcode_in:  std_logic_vector(7 downto 0);
  signal dbg_sp:         std_logic_vector(10 downto 2);
  signal dbg_brk:        std_logic;
  signal dbg_stacka:     std_logic_vector(wordSize-1 downto 0);
  signal dbg_stackb:     std_logic_vector(wordSize-1 downto 0);
  signal dbg_step:       std_logic := '0';
  signal dbg_freeze:     std_logic;
  signal dbg_flush:      std_logic;
  signal dbg_valid:      std_logic;
  signal dbg_ready:      std_logic;
  signal dbg_inject:     std_logic;
  signal dbg_injectmode: std_logic;
  signal dbg_idim:      std_logic;

  signal dbg_to_zpu:         zpu_dbg_in_type;
  signal dbg_from_zpu:       zpu_dbg_out_type;

  signal mwbo:  wb_mosi_type;
  signal mwbi:  wb_miso_type;
  signal iowbi:  wb_mosi_type;
  signal iowbo:  wb_miso_type;
  signal icache_flush: std_logic;
  signal dcache_flush: std_logic;
  signal rwbo: wb_mosi_type;
  signal rwbi: wb_miso_type;

  signal cpuramwbi: wb_mosi_type;
  signal cpuramwbo: wb_miso_type;

begin

-- 	rwbi.int     <= interrupt;

  core: zcorev3
    port map (
      syscon        => syscon,
      mwbi          => mwbi,
      mwbo          => mwbo,
      iowbi         => iowbo,
      iowbo         => iowbi,
      poppc_inst    => poppc_inst,
	 		break         => open,
      icache_flush   => icache_flush,
      dcache_flush   => dcache_flush,
      rwbi          => rwbi,
      rwbo          => rwbo,
      dbg_in        => dbg_to_zpu,
      dbg_out       => dbg_from_zpu
    );


  dbg: zpuino_debug_core
    port map (
      clk           => syscon.clk,
      rst           => syscon.rst,
      dbg_out       => dbg_to_zpu,
      dbg_in        => dbg_from_zpu,
      dbg_reset     => dbg_reset,

      jtag_data_chain_out => jtag_data_chain_out,
      jtag_ctrl_chain_in => jtag_ctrl_chain_in

   );

  io: zpuino_io
    port map (
      wb_clk_i      => syscon.clk,
	 	  wb_rst_i      => syscon.rst,
      wb_dat_o      => iowbo.dat,
      wb_dat_i      => iowbi.dat,
      wb_adr_i      => iowbi.adr(maxAddrBitIncIO downto 0),
      wb_cyc_i      => iowbi.cyc,
      wb_stb_i      => iowbi.stb,
      wb_ack_o      => iowbo.ack,
      wb_we_i       => iowbi.we,
      wb_inta_o     => iowbo.int,

      intready      => poppc_inst,
      icache_flush   => icache_flush,
      dcache_flush   => dcache_flush,
      memory_enable => memory_enable,

      slot_cyc      => slot_cyc,
      slot_we       => slot_we,
      slot_stb      => slot_stb,
      slot_read     => slot_read,
      slot_write    => slot_write,
      slot_address  => slot_address,
      slot_ack      => slot_ack,
      slot_interrupt=> slot_interrupt

    );

    rom_wbo <= rwbo;
    rwbi <= rom_wbi;
    ram_wbo <= mwbo;
    mwbi <= ram_wbi;

end behave;
