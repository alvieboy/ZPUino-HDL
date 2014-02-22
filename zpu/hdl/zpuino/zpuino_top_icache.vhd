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

entity zpuino_top_icache is
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
    slot_interrupt: in slot_std_logic_type;

    dbg_reset:  out std_logic;
    memory_enable: out std_logic;

    -- Memory accesses (for DMA)
    -- This is a master interface

    m_wb_dat_o: out std_logic_vector(wordSize-1 downto 0);
    m_wb_dat_i: in std_logic_vector(wordSize-1 downto 0);
    m_wb_adr_i: in std_logic_vector(maxAddrBitIncIO downto 0);
    m_wb_we_i:  in std_logic;
    m_wb_cyc_i: in std_logic;
    m_wb_stb_i: in std_logic;
    m_wb_ack_o: out std_logic;
    m_wb_stall_o: out std_logic;

    -- Memory connection

    ram_wb_ack_i:       in std_logic;
    ram_wb_stall_i:     in std_logic;
    ram_wb_dat_i:       in std_logic_vector(wordSize-1 downto 0);
    ram_wb_dat_o:       out std_logic_vector(wordSize-1 downto 0);
    ram_wb_adr_o:       out std_logic_vector(maxAddrBit downto 0);
    ram_wb_cyc_o:       out std_logic;
    ram_wb_stb_o:       out std_logic;
    ram_wb_sel_o:       out std_logic_vector(3 downto 0);
    ram_wb_we_o:        out std_logic;

    rom_wb_ack_i:       in std_logic;
    rom_wb_stall_i:     in std_logic;
    rom_wb_dat_i:       in std_logic_vector(wordSize-1 downto 0);
    rom_wb_adr_o:       out std_logic_vector(maxAddrBit downto 0);
    rom_wb_cyc_o:       out std_logic;
    rom_wb_cti_o:       out std_logic_vector(2 downto 0);
    rom_wb_stb_o:       out std_logic;


    jtag_data_chain_out: out std_logic_vector(98 downto 0);
    jtag_ctrl_chain_in: in std_logic_vector(11 downto 0)

  );
end entity zpuino_top_icache;

architecture behave of zpuino_top_icache is

  component zpuino_stack is
  port (
    stack_clk: in std_logic;
    stack_a_read: out std_logic_vector(wordSize-1 downto 0);
    stack_b_read: out std_logic_vector(wordSize-1 downto 0);
    stack_a_write: in std_logic_vector(wordSize-1 downto 0);
    stack_b_write: in std_logic_vector(wordSize-1 downto 0);
    stack_a_writeenable: in std_logic_vector(3 downto 0);
    stack_a_enable: in std_logic;
    stack_b_writeenable: in std_logic_vector(3 downto 0);
    stack_b_enable: in std_logic;
    stack_a_addr: in std_logic_vector(stackSize_bits-1 downto 2);
    stack_b_addr: in std_logic_vector(stackSize_bits-1 downto 2)
  );
  end component zpuino_stack;

  component wbarb2_1 is
  generic (
    ADDRESS_HIGH: integer := maxIObit;
    ADDRESS_LOW: integer := maxIObit
  );
  port (
    wb_clk_i: in std_logic;
	 	wb_rst_i: in std_logic;

    -- Master 0 signals

    m0_wb_dat_o: out std_logic_vector(31 downto 0);
    m0_wb_dat_i: in std_logic_vector(31 downto 0);
    m0_wb_adr_i: in std_logic_vector(ADDRESS_HIGH downto ADDRESS_LOW);
    m0_wb_sel_i: in std_logic_vector(3 downto 0);
    m0_wb_cti_i: in std_logic_vector(2 downto 0);
    m0_wb_we_i:  in std_logic;
    m0_wb_cyc_i: in std_logic;
    m0_wb_stb_i: in std_logic;
    m0_wb_ack_o: out std_logic;
    m0_wb_stall_o: out std_logic;

    -- Master 1 signals

    m1_wb_dat_o: out std_logic_vector(31 downto 0);
    m1_wb_dat_i: in std_logic_vector(31 downto 0);
    m1_wb_adr_i: in std_logic_vector(ADDRESS_HIGH downto ADDRESS_LOW);
    m1_wb_sel_i: in std_logic_vector(3 downto 0);
    m1_wb_cti_i: in std_logic_vector(2 downto 0);
    m1_wb_we_i:  in std_logic;
    m1_wb_cyc_i: in std_logic;
    m1_wb_stb_i: in std_logic;
    m1_wb_ack_o: out std_logic;
    m1_wb_stall_o: out std_logic;

    -- Slave signals

    s0_wb_dat_i: in std_logic_vector(31 downto 0);
    s0_wb_dat_o: out std_logic_vector(31 downto 0);
    s0_wb_adr_o: out std_logic_vector(ADDRESS_HIGH downto ADDRESS_LOW);
    s0_wb_sel_o: out std_logic_vector(3 downto 0);
    s0_wb_cti_o: out std_logic_vector(2 downto 0);
    s0_wb_we_o:  out std_logic;
    s0_wb_cyc_o: out std_logic;
    s0_wb_stb_o: out std_logic;
    s0_wb_ack_i: in std_logic;
    s0_wb_stall_i: in std_logic
  );
  end component;

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

  component wbmux2 is
  generic (
    select_line: integer;
    address_high: integer:=31;
    address_low: integer:=2
  );
  port (
    wb_clk_i: in std_logic;
	 	wb_rst_i: in std_logic;

    -- Master 

    m_wb_dat_o: out std_logic_vector(31 downto 0);
    m_wb_dat_i: in std_logic_vector(31 downto 0);
    m_wb_adr_i: in std_logic_vector(address_high downto address_low);
    m_wb_sel_i: in std_logic_vector(3 downto 0);
    m_wb_cti_i: in std_logic_vector(2 downto 0);
    m_wb_we_i:  in std_logic;
    m_wb_cyc_i: in std_logic;
    m_wb_stb_i: in std_logic;
    m_wb_ack_o: out std_logic;

    -- Slave 0 signals

    s0_wb_dat_i: in std_logic_vector(31 downto 0);
    s0_wb_dat_o: out std_logic_vector(31 downto 0);
    s0_wb_adr_o: out std_logic_vector(address_high downto address_low);
    s0_wb_sel_o: out std_logic_vector(3 downto 0);
    s0_wb_cti_o: out std_logic_vector(2 downto 0);
    s0_wb_we_o:  out std_logic;
    s0_wb_cyc_o: out std_logic;
    s0_wb_stb_o: out std_logic;
    s0_wb_ack_i: in std_logic;

    -- Slave 1 signals

    s1_wb_dat_i: in std_logic_vector(31 downto 0);
    s1_wb_dat_o: out std_logic_vector(31 downto 0);
    s1_wb_adr_o: out std_logic_vector(address_high downto address_low);
    s1_wb_sel_o: out std_logic_vector(3 downto 0);
    s1_wb_cti_o: out std_logic_vector(2 downto 0);
    s1_wb_we_o:  out std_logic;
    s1_wb_cyc_o: out std_logic;
    s1_wb_stb_o: out std_logic;
    s1_wb_ack_i: in std_logic
  );
  end component wbmux2;


  signal io_read:    std_logic_vector(wordSize-1 downto 0);
  signal io_write:   std_logic_vector(wordSize-1 downto 0);
  signal io_address: std_logic_vector(maxAddrBitIncIO downto 0);
  signal io_stb:     std_logic;
  signal io_cyc:     std_logic;
  signal io_we:       std_logic;
  signal io_ack:     std_logic;

  signal wb_read:    std_logic_vector(wordSize-1 downto 0);
  signal wb_write:   std_logic_vector(wordSize-1 downto 0);
  signal wb_address: std_logic_vector(maxAddrBitIncIO downto 0);
  signal wb_stb:     std_logic;
  signal wb_cyc:     std_logic;
  signal wb_sel:     std_logic_vector(3 downto 0);
  signal wb_we:       std_logic;
  signal wb_ack:     std_logic;

  signal interrupt:  std_logic;
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

  signal stack_a_addr,stack_b_addr: std_logic_vector(stackSize_bits-1 downto 2);
  signal stack_a_writeenable, stack_b_writeenable: std_logic_vector(3 downto 0);
  signal stack_a_enable,stack_b_enable: std_logic;
  signal stack_a_write,stack_b_write: std_logic_vector(31 downto 0);
  signal stack_a_read,stack_b_read: std_logic_vector(31 downto 0);
  signal stack_clk: std_logic;
  signal cache_flush: std_logic;
  --signal memory_enable: std_logic;

  signal cpu_ram_wb_clk_i:       std_logic;
  signal cpu_ram_wb_rst_i:       std_logic;
  signal cpu_ram_wb_ack_o:       std_logic;
  signal cpu_ram_wb_stall_o:     std_logic;
  signal cpu_ram_wb_dat_i:       std_logic_vector(wordSize-1 downto 0);
  signal cpu_ram_wb_dat_o:       std_logic_vector(wordSize-1 downto 0);
  signal cpu_ram_wb_adr_i:       std_logic_vector(maxAddrBitIncIO downto 0);
  signal cpu_ram_wb_cyc_i:       std_logic;
  signal cpu_ram_wb_stb_i:       std_logic;
  signal cpu_ram_wb_sel_i:       std_logic_vector(3 downto 0);
  signal cpu_ram_wb_we_i:        std_logic;

  signal dbg_to_zpu:         zpu_dbg_in_type;
  signal dbg_from_zpu:       zpu_dbg_out_type;

begin

  core: zpu_core_extreme_icache
    port map (
      wb_clk_i      => clk,
	 		wb_rst_i      => rst,

	 		wb_ack_i      => wb_ack,
	 		wb_dat_i      => wb_read,
	 		wb_dat_o      => wb_write,
      wb_adr_o      => wb_address,
			wb_cyc_o      => wb_cyc,
			wb_stb_o      => wb_stb,
      wb_sel_o        => wb_sel,
      wb_we_o       => wb_we,
	 		wb_inta_i     => interrupt,

      poppc_inst    => poppc_inst,
	 		break         => open,
      cache_flush   => cache_flush,

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

      rom_wb_ack_i  => rom_wb_ack_i,
      rom_wb_dat_i  => rom_wb_dat_i,
      rom_wb_adr_o  => rom_wb_adr_o(maxAddrBit downto 0),
      rom_wb_cyc_o  => rom_wb_cyc_o,
      rom_wb_stb_o  => rom_wb_stb_o,
      rom_wb_cti_o  => rom_wb_cti_o,
      rom_wb_stall_i  => rom_wb_stall_i,

      dbg_in        => dbg_to_zpu,
      dbg_out       => dbg_from_zpu
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

  dbg: zpuino_debug_core
    port map (
      clk           => clk,
      rst           => rst,
      dbg_out       => dbg_to_zpu,
      dbg_in        => dbg_from_zpu,
      dbg_reset     => dbg_reset,

      jtag_data_chain_out => jtag_data_chain_out,
      jtag_ctrl_chain_in => jtag_ctrl_chain_in

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
      cache_flush   => cache_flush,
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

  iomemmux: wbmux2
  generic map (
    select_line => maxAddrBitIncIO,
    address_high =>maxAddrBitIncIO,
    address_low=>0  
  )
  port map (
    wb_clk_i     => clk,
	 	wb_rst_i     => rst,

    -- Master 

    m_wb_dat_o    => wb_read,
    m_wb_dat_i    => wb_write,
    m_wb_adr_i    => wb_address,
    m_wb_sel_i    => wb_sel,
    m_wb_cti_i    => CTI_CYCLE_CLASSIC,--wb_cti,
    m_wb_we_i     => wb_we,
    m_wb_cyc_i    => wb_cyc,
    m_wb_stb_i    => wb_stb,
    m_wb_ack_o    => wb_ack,

    -- Slave 0 signals

    s0_wb_dat_i   => cpu_ram_wb_dat_o,
    s0_wb_dat_o   => cpu_ram_wb_dat_i,
    s0_wb_adr_o   => cpu_ram_wb_adr_i,
    s0_wb_sel_o   => cpu_ram_wb_sel_i,
    s0_wb_cti_o   => open,--cpu_ram_wb_sel_i,
    s0_wb_we_o    => cpu_ram_wb_we_i,
    s0_wb_cyc_o   => cpu_ram_wb_cyc_i,
    s0_wb_stb_o   => cpu_ram_wb_stb_i,
    s0_wb_ack_i   => cpu_ram_wb_ack_o,

    -- Slave 1 signals

    s1_wb_dat_i   => io_read,
    s1_wb_dat_o   => io_write,
    s1_wb_adr_o   => io_address,
    s1_wb_sel_o   => open,
    s1_wb_cti_o   => open,
    s1_wb_we_o    => io_we,
    s1_wb_cyc_o   => io_cyc,
    s1_wb_stb_o   => io_stb,
    s1_wb_ack_i   => io_ack
  );

  memarb: wbarb2_1
  generic map (
    ADDRESS_HIGH => maxAddrBit,
    ADDRESS_LOW => 0
  )
  port map (
    wb_clk_i      => clk,
	 	wb_rst_i      => rst,

    -- Master 0 signals (CPU)

    m0_wb_dat_o   => cpu_ram_wb_dat_o,
    m0_wb_dat_i   => cpu_ram_wb_dat_i,
    m0_wb_adr_i   => cpu_ram_wb_adr_i(maxAddrBit downto 0),
    m0_wb_sel_i   => cpu_ram_wb_sel_i,
    m0_wb_cti_i   => CTI_CYCLE_CLASSIC,
    m0_wb_we_i    => cpu_ram_wb_we_i,
    m0_wb_cyc_i   => cpu_ram_wb_cyc_i,
    m0_wb_stb_i   => cpu_ram_wb_stb_i,
    m0_wb_ack_o   => cpu_ram_wb_ack_o,
    m0_wb_stall_o => cpu_ram_wb_stall_o,

    -- Master 1 signals

    m1_wb_dat_o   => m_wb_dat_o,
    m1_wb_dat_i   => m_wb_dat_i,
    m1_wb_adr_i   => m_wb_adr_i(maxAddrBit downto 0),
    m1_wb_sel_i   => (others => '1'),
    m1_wb_cti_i   => CTI_CYCLE_CLASSIC,
    m1_wb_we_i    => m_wb_we_i,
    m1_wb_cyc_i   => m_wb_cyc_i,
    m1_wb_stb_i   => m_wb_stb_i,
    m1_wb_ack_o   => m_wb_ack_o,
    m1_wb_stall_o   => m_wb_stall_o,

    -- Slave signals

    s0_wb_dat_i   => ram_wb_dat_i,
    s0_wb_dat_o   => ram_wb_dat_o,
    s0_wb_adr_o   => ram_wb_adr_o(maxAddrBit downto 0),
    s0_wb_sel_o   => ram_wb_sel_o,
    s0_wb_cti_o   => open,
    s0_wb_we_o    => ram_wb_we_o,
    s0_wb_cyc_o   => ram_wb_cyc_o,
    s0_wb_stb_o   => ram_wb_stb_o,
    s0_wb_ack_i   => ram_wb_ack_i,
    s0_wb_stall_i => ram_wb_stall_i
  );


end behave;
