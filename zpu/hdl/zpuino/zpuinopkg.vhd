--
--  ZPUINO package
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
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;

library work;
use work.zpu_config.all;
use work.zpupkg.all;
use work.zpuino_config.all;
use work.wishbonepkg.all;

package zpuinopkg is


  constant num_devices: integer := (2**zpuino_number_io_select_bits);

  type slot_std_logic_type is array(0 to num_devices-1) of std_logic;
  subtype cpuword_type     is std_logic_vector(31 downto 0);
  type slot_cpuword_type   is array(0 to num_devices-1) of cpuword_type;
  subtype address_type     is std_logic_vector(maxIObit downto minIObit);
  type slot_address_type   is array(0 to num_devices-1) of address_type;


  type icache_out_type is record
    valid:          std_logic;
    stall:          std_logic;
    data:           std_logic_vector(wordSize-1 downto 0);
  end record;

  type icache_in_type is record
    address:        std_logic_vector(maxAddrBit downto 0);
    strobe:         std_logic;
    enable:         std_logic;
    flush:          std_logic;
  end record;


  component zpuino_top_icache is
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

    -- Wishbone MASTER interface (for DMA)
    m_wb_dat_o: out std_logic_vector(wordSize-1 downto 0);
    m_wb_dat_i: in std_logic_vector(wordSize-1 downto 0);
    m_wb_adr_i: in std_logic_vector(maxAddrBitIncIO downto 0);
    m_wb_we_i:  in std_logic;
    m_wb_cyc_i: in std_logic;
    m_wb_stb_i: in std_logic;
    m_wb_ack_o: out std_logic;

    memory_enable:      out std_logic;
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

    dbg_reset: out std_logic;
    jtag_data_chain_out: out std_logic_vector(98 downto 0);
    jtag_ctrl_chain_in: in std_logic_vector(11 downto 0)

  );
  end component zpuino_top_icache;

  component zcorev3_top is
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

    -- ROM connection
    --rom_wbo:    out wb_mosi_type;
    --rom_wbi:    in wb_miso_type;

    jtag_data_chain_out: out std_logic_vector(98 downto 0);
    jtag_ctrl_chain_in: in std_logic_vector(11 downto 0)

  );
  end component;


  component zpuino_top is
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

    -- Memory accesses (for DMA)
    -- This is a master interface

    m_wb_dat_o: out std_logic_vector(wordSize-1 downto 0);
    m_wb_dat_i: in std_logic_vector(wordSize-1 downto 0);
    m_wb_adr_i: in std_logic_vector(maxAddrBitIncIO downto 0);
    m_wb_we_i:  in std_logic;
    m_wb_cyc_i: in std_logic;
    m_wb_stb_i: in std_logic;
    m_wb_ack_o: out std_logic;

    jtag_data_chain_out: out std_logic_vector(98 downto 0);
    jtag_ctrl_chain_in: in std_logic_vector(11 downto 0)

  );
  end component;



  component zpuino_io is
    port (
      wb_clk_i: in std_logic;
  	 	wb_rst_i: in std_logic;
      wb_dat_o: out std_logic_vector(wordSize-1 downto 0);
      wb_dat_i: in std_logic_vector(wordSize-1 downto 0);
      wb_adr_i: in std_logic_vector(maxAddrBitIncIO downto 0);
      wb_we_i:  in std_logic;
      wb_cyc_i: in std_logic;
      wb_stb_i: in std_logic;
      wb_ack_o: out std_logic;
      wb_inta_o:out std_logic;

      intready: in std_logic;
      cache_flush: out std_logic;
      memory_enable: out std_logic;

      slot_cyc:   out slot_std_logic_type;
      slot_we:    out slot_std_logic_type;
      slot_stb:   out slot_std_logic_type;  
      slot_read:  in slot_cpuword_type;
      slot_write: out slot_cpuword_type;
      slot_address:  out slot_address_type;
      slot_ack:   in slot_std_logic_type;
      slot_interrupt: in slot_std_logic_type

    );
  end component zpuino_io;

  component zpuino_empty_device is
  port (
    wb_clk_i: in std_logic;
	 	wb_rst_i: in std_logic;
    wb_dat_o: out std_logic_vector(wordSize-1 downto 0);
    wb_dat_i: in std_logic_vector(wordSize-1 downto 0);
    wb_adr_i: in std_logic_vector(maxIObit downto minIObit);
    wb_we_i:  in std_logic;
    wb_cyc_i: in std_logic;
    wb_stb_i: in std_logic;
    wb_ack_o: out std_logic;
    wb_inta_o:out std_logic
  );
  end component zpuino_empty_device;

  component zpuino_spi is
  port (
    wb_clk_i: in std_logic;
	 	wb_rst_i: in std_logic;
    wb_dat_o: out std_logic_vector(wordSize-1 downto 0);
    wb_dat_i: in std_logic_vector(wordSize-1 downto 0);
    wb_adr_i: in std_logic_vector(maxIObit downto minIObit);
    wb_we_i:  in std_logic;
    wb_cyc_i: in std_logic;
    wb_stb_i: in std_logic;
    wb_ack_o: out std_logic;
    wb_inta_o:out std_logic;

    mosi:     out std_logic;
    miso:     in std_logic;
    sck:      out std_logic;

    enabled:  out std_logic
  );
  end component zpuino_spi;

  component zpuino_uart is
  generic (
    bits: integer := 11
  );
  port (
    wb_clk_i: in std_logic;
	 	wb_rst_i: in std_logic;
    wb_dat_o: out std_logic_vector(wordSize-1 downto 0);
    wb_dat_i: in std_logic_vector(wordSize-1 downto 0);
    wb_adr_i: in std_logic_vector(maxIObit downto minIObit);
    wb_we_i:  in std_logic;
    wb_cyc_i: in std_logic;
    wb_stb_i: in std_logic;
    wb_ack_o: out std_logic;
    wb_inta_o:out std_logic;

    enabled:  out std_logic;
    tx:       out std_logic;
    rx:       in std_logic
  );
  end component zpuino_uart;

  component zpuino_gpio is
  generic (
    gpio_count: integer := 32
  );
  port (
    wb_clk_i: in std_logic;
	 	wb_rst_i: in std_logic;
    wb_dat_o: out std_logic_vector(wordSize-1 downto 0);
    wb_dat_i: in std_logic_vector(wordSize-1 downto 0);
    wb_adr_i: in std_logic_vector(maxIObit downto minIObit);
    wb_we_i:  in std_logic;
    wb_cyc_i: in std_logic;
    wb_stb_i: in std_logic;
    wb_ack_o: out std_logic;
    wb_inta_o:out std_logic;

    spp_data: in std_logic_vector(gpio_count-1 downto 0);
    spp_read: out std_logic_vector(gpio_count-1 downto 0);

    gpio_o:   out std_logic_vector(gpio_count-1 downto 0);
    gpio_t:   out std_logic_vector(gpio_count-1 downto 0);
    gpio_i:   in std_logic_vector(gpio_count-1 downto 0);

    spp_cap_in:  in std_logic_vector(gpio_count-1 downto 0); -- SPP capable pin for INPUT
    spp_cap_out:  in std_logic_vector(gpio_count-1 downto 0) -- SPP capable pin for OUTPUT
  );
  end component zpuino_gpio;

  component zpuino_timers is
  generic (
    A_TSCENABLED: boolean := false;
    A_PWMCOUNT: integer range 1 to 8 := 2;
    A_WIDTH: integer range 1 to 32 := 16;
    A_PRESCALER_ENABLED: boolean := true;
    A_BUFFERS: boolean := true;
    B_TSCENABLED: boolean := false;
    B_PWMCOUNT: integer range 1 to 8 := 2;
    B_WIDTH: integer range 1 to 32 := 16;
    B_PRESCALER_ENABLED: boolean := false;
    B_BUFFERS: boolean := false
  );

  port (
    wb_clk_i: in std_logic;
	 	wb_rst_i: in std_logic;
    wb_dat_o: out std_logic_vector(wordSize-1 downto 0);
    wb_dat_i: in std_logic_vector(wordSize-1 downto 0);
    wb_adr_i: in std_logic_vector(maxIObit downto minIObit);
    wb_we_i:  in std_logic;
    wb_cyc_i: in std_logic;
    wb_stb_i: in std_logic;
    wb_ack_o: out std_logic;
    wb_inta_o:out std_logic;
    wb_intb_o:out std_logic;
    
    pwm_A_out: out std_logic_vector(A_PWMCOUNT-1 downto 0);
    pwm_B_out: out std_logic_vector(B_PWMCOUNT-1 downto 0)
  );
  end component zpuino_timers;


  component zpuino_intr is
  generic (
    INTERRUPT_LINES: integer := 16
  );
  port (
    wb_clk_i: in std_logic;
	 	wb_rst_i: in std_logic;
    wb_dat_o: out std_logic_vector(wordSize-1 downto 0);
    wb_dat_i: in std_logic_vector(wordSize-1 downto 0);
    wb_adr_i: in std_logic_vector(maxIObit downto minIObit);
    wb_we_i:  in std_logic;
    wb_cyc_i: in std_logic;
    wb_stb_i: in std_logic;
    wb_ack_o: out std_logic;
    wb_inta_o:out std_logic;

    poppc_inst:in std_logic;
    cache_flush: out std_logic;
    memory_enable: out std_logic;

    intr_in:    in std_logic_vector(INTERRUPT_LINES-1 downto 0);
    intr_cfglvl:in std_logic_vector(INTERRUPT_LINES-1 downto 0)
  );
  end component zpuino_intr;

  component zpuino_sigmadelta is
	port (
    wb_clk_i: in std_logic;
	 	wb_rst_i: in std_logic;
    wb_dat_o: out std_logic_vector(wordSize-1 downto 0);
    wb_dat_i: in std_logic_vector(wordSize-1 downto 0);
    wb_adr_i: in std_logic_vector(maxIObit downto minIObit);
    wb_we_i:  in std_logic;
    wb_cyc_i: in std_logic;
    wb_stb_i: in std_logic;
    wb_ack_o: out std_logic;
    wb_inta_o:out std_logic;

    sync_in:  in std_logic;

    -- Connection to GPIO pin
    spp_data: out std_logic_vector(1 downto 0);
    spp_en:   out std_logic_vector(1 downto 0)

  );
  end component zpuino_sigmadelta;

  component zpuino_crc16 is
  port (
    wb_clk_i: in std_logic;
	 	wb_rst_i: in std_logic;
    wb_dat_o: out std_logic_vector(wordSize-1 downto 0);
    wb_dat_i: in std_logic_vector(wordSize-1 downto 0);
    wb_adr_i: in std_logic_vector(maxIObit downto minIObit);
    wb_we_i:  in std_logic;
    wb_cyc_i: in std_logic;
    wb_stb_i: in std_logic;
    wb_ack_o: out std_logic;
    wb_inta_o:out std_logic
  );
  end component zpuino_crc16;

  component zpuino_adc is
  port (
    wb_clk_i: in std_logic;
	 	wb_rst_i: in std_logic;
    wb_dat_o: out std_logic_vector(wordSize-1 downto 0);
    wb_dat_i: in std_logic_vector(wordSize-1 downto 0);
    wb_adr_i: in std_logic_vector(maxIObit downto minIObit);
    wb_we_i:  in std_logic;
    wb_cyc_i: in std_logic;
    wb_stb_i: in std_logic;
    wb_ack_o: out std_logic;
    wb_inta_o:out std_logic;

    sample:   in std_logic;
    -- GPIO SPI pins

    mosi:     out std_logic;
    miso:     in std_logic;
    sck:      out std_logic;
    seln:     out std_logic;
    enabled:  out std_logic
  );
  end component zpuino_adc;

  component sram_ctrl is
  port (
    wb_clk_i: in std_logic;
	 	wb_rst_i: in std_logic;

    wb_dat_o: out std_logic_vector(31 downto 0);
    wb_dat_i: in std_logic_vector(31 downto 0);
    wb_adr_i: in std_logic_vector(maxIObit downto minIObit);
    --wb_sel_i: in std_logic_vector(3 downto 0);
    --wb_cti_i: in std_logic_vector(2 downto 0);
    wb_we_i:  in std_logic;
    wb_cyc_i: in std_logic;
    wb_stb_i: in std_logic;
    wb_ack_o: out std_logic;
    wb_stall_o: out std_logic;
    clk_we: in std_logic;
    clk_wen: in std_logic;

    -- SRAM signals
    sram_addr:  out std_logic_vector(18 downto 0);
    sram_data:  inout std_logic_vector(15 downto 0);
    sram_ce:    out std_logic;
    sram_we:    out std_logic;
    sram_oe:    out std_logic;
    sram_be:    out std_logic
  );
  end component sram_ctrl;

  component zpuino_sevenseg is
  generic (
    BITS: integer := 2;
    EXTRASIZE: integer := 32;
    FREQ_PER_DISPLAY:  integer := 120;
    MHZ:  integer := 96;
    INVERT: boolean := true
  );
  port (
    wb_clk_i: in std_logic;
	 	wb_rst_i: in std_logic;
    wb_dat_o: out std_logic_vector(wordSize-1 downto 0);
    wb_dat_i: in std_logic_vector(wordSize-1 downto 0);
    wb_adr_i: in std_logic_vector(maxIObit downto minIObit);
    wb_we_i:  in std_logic;
    wb_cyc_i: in std_logic;
    wb_stb_i: in std_logic;
    wb_ack_o: out std_logic;
    wb_inta_o:out std_logic;

    segdata:  out std_logic_vector(6 downto 0);
    dot:      out std_logic;
    extra:    out std_logic_vector(EXTRASIZE-1 downto 0);
    enable:   out std_logic_vector((2**BITS)-1 downto 0)
  );
  end component;

  component wbarb2_1 is
  generic (
    ADDRESS_HIGH: integer := maxIObit;
    ADDRESS_LOW: integer := maxIObit
  );
  port (
    syscon:   in wb_syscon_type;
    -- Master 0 signals
    m0wbi:    in wb_mosi_type;
    m0wbo:    out wb_miso_type;
    -- Master 1 signals
    m1wbi:    in wb_mosi_type;
    m1wbo:    out wb_miso_type;
    -- Slave signals
    s0wbi:    in wb_miso_type;
    s0wbo:    out wb_mosi_type
  );
  end component;


  component wb_master_np_to_slave_p is
  generic (
    ADDRESS_HIGH: integer := maxIObit;
    ADDRESS_LOW: integer := maxIObit
  );
  port (
    wb_clk_i: in std_logic;
	 	wb_rst_i: in std_logic;

    -- Master signals

    m_wb_dat_o: out std_logic_vector(31 downto 0);
    m_wb_dat_i: in std_logic_vector(31 downto 0);
    m_wb_adr_i: in std_logic_vector(ADDRESS_HIGH downto ADDRESS_LOW);
    m_wb_sel_i: in std_logic_vector(3 downto 0);
    m_wb_cti_i: in std_logic_vector(2 downto 0);
    m_wb_we_i:  in std_logic;
    m_wb_cyc_i: in std_logic;
    m_wb_stb_i: in std_logic;
    m_wb_ack_o: out std_logic;

    -- Slave signals

    s_wb_dat_i: in std_logic_vector(31 downto 0);
    s_wb_dat_o: out std_logic_vector(31 downto 0);
    s_wb_adr_o: out std_logic_vector(ADDRESS_HIGH downto ADDRESS_LOW);
    s_wb_sel_o: out std_logic_vector(3 downto 0);
    s_wb_cti_o: out std_logic_vector(2 downto 0);
    s_wb_we_o:  out std_logic;
    s_wb_cyc_o: out std_logic;
    s_wb_stb_o: out std_logic;
    s_wb_ack_i: in std_logic;
    s_wb_stall_i: in std_logic
  );
  end component;

  component generic_sp_ram is
  generic (
    address_bits: integer := 8;
    data_bits: integer := 32
  );
  port (
    clka:             in std_logic;
    ena:              in std_logic;
    wea:              in std_logic;
    addra:            in std_logic_vector(address_bits-1 downto 0);
    dia:              in std_logic_vector(data_bits-1 downto 0);
    doa:              out std_logic_vector(data_bits-1 downto 0)
  );
  end component;

  component generic_dp_ram is
  generic (
    address_bits: integer := 8;
    data_bits: integer := 32
  );
  port (
    clka:             in std_logic;
    ena:              in std_logic;
    wea:              in std_logic;
    addra:            in std_logic_vector(address_bits-1 downto 0);
    dia:              in std_logic_vector(data_bits-1 downto 0);
    doa:              out std_logic_vector(data_bits-1 downto 0);
    clkb:             in std_logic;
    enb:              in std_logic;
    web:              in std_logic;
    addrb:            in std_logic_vector(address_bits-1 downto 0);
    dib:              in std_logic_vector(data_bits-1 downto 0);
    dob:              out std_logic_vector(data_bits-1 downto 0)
  );

  end component generic_dp_ram;

  type dcache_in_type is record
    a_address:        std_logic_vector(31 downto 0);
    a_strobe:         std_logic;
    a_enable:         std_logic;
    b_data_in:        std_logic_vector(wordSize-1 downto 0);
    b_address:        std_logic_vector(31 downto 0);
    b_strobe:         std_logic;
    b_we:             std_logic;
    b_wmask:          std_logic_vector(3 downto 0);
    b_enable:         std_logic;
    flush:            std_logic;
  end record;

  type dcache_out_type is record
    a_valid:          std_logic;
    a_data_out:       std_logic_vector(wordSize-1 downto 0);
    a_stall:          std_logic;
    b_valid:          std_logic;
    b_data_out:       std_logic_vector(wordSize-1 downto 0);
    b_stall:          std_logic;
  end record;

  component zpuino_dcache is
  generic (
      ADDRESS_HIGH: integer := 26;
      CACHE_MAX_BITS: integer := 13; -- 8 Kb
      CACHE_LINE_SIZE_BITS: integer := 6 -- 64 bytes
  );
  port (
    syscon:     in wb_syscon_type;
    ci:         in dcache_in_type;
    co:         out dcache_out_type;
    mwbi:       in wb_miso_type;
    mwbo:       out wb_mosi_type
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

  component wb_rom_ram is
  port (
    ram_wb_clk_i:       in std_logic;
    ram_wb_rst_i:       in std_logic;
    ram_wb_ack_o:       out std_logic;
    ram_wb_dat_i:       in std_logic_vector(wordSize-1 downto 0);
    ram_wb_dat_o:       out std_logic_vector(wordSize-1 downto 0);
    ram_wb_adr_i:       in std_logic_vector(maxAddrBitIncIO downto 0);
    ram_wb_cyc_i:       in std_logic;
    ram_wb_stb_i:       in std_logic;
    ram_wb_we_i:        in std_logic;

    rom_wb_clk_i:       in std_logic;
    rom_wb_rst_i:       in std_logic;
    rom_wb_ack_o:       out std_logic;
    rom_wb_dat_o:       out std_logic_vector(wordSize-1 downto 0);
    rom_wb_adr_i:       in std_logic_vector(maxAddrBitIncIO downto 0);
    rom_wb_cyc_i:       in std_logic;
    rom_wb_stb_i:       in std_logic;
    rom_wb_cti_i:       in std_logic_vector(2 downto 0)
  );
  end component wb_rom_ram;

  component wbmux2 is
  generic (
    select_line: integer;
    address_high: integer:=31;
    address_low: integer:=2
  );
  port (
    syscon:   in wb_syscon_type;
    -- Master (sink)
    mwbi:     in wb_mosi_type;
    mwbo:     out wb_miso_type;
    -- Slave 0 signals (driver)
    s0wbo:    out wb_mosi_type;
    s0wbi:    in wb_miso_type;
    -- Slave 1 signals (driver)
    s1wbo:    out wb_mosi_type;
    s1wbi:    in wb_miso_type
  );
  end component;


  component lshifter is
  port (
    clk: in std_logic;
    rst: in std_logic;
    enable:  in std_logic;
    done: out std_logic;
    inputA:  in std_logic_vector(31 downto 0);
    inputB: in std_logic_vector(31 downto 0);
    output: out std_logic_vector(63 downto 0);
    multorshift: in std_logic
  );
  end component;

  component zpuino_icache is
  generic (
      ADDRESS_HIGH: integer := 26
  );
  port (
    syscon:         in wb_syscon_type;
    co:             out icache_out_type;
    ci:             in icache_in_type;
    mwbi:           in wb_miso_type;
    mwbo:           out wb_mosi_type
  );
  end component;


  component zpuino_lsu is
  port (
    wb_clk_i:       in std_logic;
    wb_rst_i:       in std_logic;

    wb_ack_i:       in std_logic;
    wb_dat_i:       in std_logic_vector(wordSize-1 downto 0);
    wb_dat_o:       out std_logic_vector(wordSize-1 downto 0);
    wb_adr_o:       out std_logic_vector(maxAddrBitIncIO downto 2);
    wb_cyc_o:       out std_logic;
    wb_stb_o:       out std_logic;
    wb_sel_o:       out std_logic_vector(3 downto 0);
    wb_we_o:        out std_logic;


    -- Connection to cpu
    req:            in std_logic;
    we:             in std_logic;
    busy:           out std_logic;

    data_read:      out std_logic_vector(wordSize-1 downto 0);
    data_write:     in std_logic_vector(wordSize-1 downto 0);
    data_sel:       in std_logic_vector(3 downto 0);
    address:        in std_logic_vector(maxAddrBitIncIO downto 0)
  );
  end component;

  component wbbootloadermux is
  generic (
    address_high: integer:=31;
    address_low: integer:=2
  );
  port (
    syscon:   in wb_syscon_type;

    sel:      in std_logic;

      -- Master (sink)
    mwbi:     in wb_mosi_type;
    mwbo:     out wb_miso_type;
    -- Slave 0 signals

    s0wbi:    in wb_miso_type;
    s0wbo:    out wb_mosi_type;
    s1wbi:    in wb_miso_type;
    s1wbo:    out wb_mosi_type
  );
  end component wbbootloadermux;


end package zpuinopkg;
