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
use work.zpu_config.all;
use work.pad.all;

library unisim;
use unisim.vcomponents.all;

entity papilio_one_top is
  port (
    CLK:        in std_logic;
    --RST:        in std_logic; -- No reset on papilio

    SPI_SCK:    out std_logic;
    SPI_MISO:   in std_logic;
    SPI_MOSI:   out std_logic;
    SPI_CS:     inout std_logic; 

    WING_A:     inout std_logic_vector(15 downto 0);
    WING_B:     inout std_logic_vector(15 downto 0);
    WING_C:     inout std_logic_vector(15 downto 0);

    TXD:        out std_logic;
    RXD:        in std_logic

  );
end entity papilio_one_top;

architecture behave of papilio_one_top is

  component clkgen is
  port (
    clkin:  in std_logic;
    rstin:  in std_logic;
    clkout: out std_logic;
    clkout_1mhz: out std_logic;
    rstout: out std_logic
  );
  end component clkgen;

  signal   m_wb_dat_i:  std_logic_vector(wordSize-1 downto 0);
  signal   m_wb_dat_o:  std_logic_vector(wordSize-1 downto 0);
  signal   m_wb_adr_i:  std_logic_vector(maxAddrBitIncIO downto 0);
  signal  m_wb_sel_i:  std_logic_vector(3 downto 0);
  signal   m_wb_cti_i:  std_logic_vector(2 downto 0);
  signal   m_wb_we_i:   std_logic;
  signal   m_wb_cyc_i:  std_logic;
  signal   m_wb_stb_i:  std_logic;
  signal   m_wb_ack_o:  std_logic;

  component wb_sc_cordic is
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
  end component;

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
  signal sysclk_1mhz: std_logic;
  signal dbg_reset:   std_logic;
  signal clkgen_rst:  std_logic;
  signal gpio_o:      std_logic_vector(zpuino_gpio_count-1 downto 0);
  signal gpio_t:      std_logic_vector(zpuino_gpio_count-1 downto 0);
  signal gpio_i:      std_logic_vector(zpuino_gpio_count-1 downto 0);

  signal rx: std_logic;
  signal tx: std_logic;

  constant spp_cap_in: std_logic_vector(zpuino_gpio_count-1 downto 0) :=
    "0" &
    "1111111111111111" &
    "1111111111111111" &
    "1111111111111111";
  constant spp_cap_out: std_logic_vector(zpuino_gpio_count-1 downto 0) :=
    "0" &
    "1111111111111111" &
    "1111111111111111" &
    "1111111111111111";

  -- I/O Signals
  signal slot_cyc:   slot_std_logic_type;
  signal slot_we:    slot_std_logic_type;
  signal slot_stb:   slot_std_logic_type;
  signal slot_read:  slot_cpuword_type;
  signal slot_write: slot_cpuword_type;
  signal slot_address:  slot_address_type;
  signal slot_ack:   slot_std_logic_type;
  signal slot_interrupt: slot_std_logic_type;

  signal spi_enabled:  std_logic;

  signal spi2_enabled:  std_logic;
  signal spi2_mosi:  std_logic;
  signal spi2_miso:  std_logic;
  signal spi2_sck:  std_logic;

  signal uart_enabled:  std_logic;

  -- SPP signal is one more than GPIO count
  signal gpio_spp_data: std_logic_vector(zpuino_gpio_count-1 downto 0);
  signal gpio_spp_read: std_logic_vector(zpuino_gpio_count-1 downto 0);

  --signal gpio_spp_en: std_logic_vector(zpuino_gpio_count-1 downto 1);

  signal timers_interrupt:  std_logic_vector(1 downto 0);
  signal timers_pwm: std_logic_vector(1 downto 0);

  signal ivecs: std_logic_vector(17 downto 0);

  signal sigmadelta_spp_en:  std_logic_vector(1 downto 0);
  signal sigmadelta_spp_data:  std_logic_vector(1 downto 0);

  -- For busy-implementation
  signal addr_save_q: std_logic_vector(maxAddrBitIncIO downto 0);
  signal write_save_q: std_logic_vector(wordSize-1 downto 0);

--  signal io_address: std_logic_vector(maxAddrBitIncIO downto 0);
--  signal io_write: std_logic_vector(wordSize-1 downto 0);
--  signal io_cyc: std_logic;
--  signal io_stb: std_logic;
--  signal io_we: std_logic;

--  signal io_device_ack: std_logic;

  signal spi_pf_miso: std_logic;
  signal spi_pf_mosi: std_logic;
  signal spi_pf_sck: std_logic;

  signal spi3_mosi: std_logic;
  signal spi3_sck: std_logic;

  signal adc_mosi:  std_logic;
  signal adc_miso:  std_logic;
  signal adc_sck:   std_logic;
  signal adc_seln:  std_logic;
  signal adc_enabled: std_logic;

  signal wb_clk_i: std_logic;
  signal wb_rst_i: std_logic;

  signal uart2_tx, uart2_rx: std_logic;

  signal jtag_data_chain_out: std_logic_vector(98 downto 0);
  signal jtag_ctrl_chain_in:  std_logic_vector(11 downto 0);

--  signal TCK,TDI,CAPTUREIR,UPDATEIR,SHIFTIR,CAPTUREDR,UPDATEDR,SHIFTDR,TLR,TDO_IR,TDO_DR: std_logic;


--  component zpuino_debug_jtag is
--  port (
    -- Connections to JTAG stuff

--    TCK: in std_logic;
--    TDI: in std_logic;
--    CAPTUREIR: in std_logic;
--    UPDATEIR:  in std_logic;
--    SHIFTIR:  in std_logic;
--    CAPTUREDR: in std_logic;
--    UPDATEDR:  in std_logic;
--    SHIFTDR:  in std_logic;
--    TLR:  in std_logic;

--    TDO_IR:   out std_logic;
--    TDO_DR:   out std_logic;


--    jtag_data_chain_in: in std_logic_vector(98 downto 0);
 --   jtag_ctrl_chain_out: out std_logic_vector(11 downto 0)
--  );
--  end component;

  component zpuino_debug_spartan3e is
  port (
    TCK: out std_logic;
    TDI: out std_logic;
    CAPTUREIR: out std_logic;
    UPDATEIR:  out std_logic;
    SHIFTIR:  out std_logic;
    CAPTUREDR: out std_logic;
    UPDATEDR:  out std_logic;
    SHIFTDR:  out std_logic;
    TLR:  out std_logic;
    TDO_IR:   in std_logic;
    TDO_DR:   in std_logic
  );
  end component;

  component simple_sigmadelta is
  generic (
    BITS: integer := 8
  );
	port (
    clk:      in std_logic;
    rst:      in std_logic;
    data_in:  in std_logic_vector(BITS-1 downto 0);
    data_out: out std_logic
    );
  end component simple_sigmadelta;

  component zpuino_io_YM2149 is
  port (
  wb_clk_i:   in std_logic;
  wb_rst_i:   in std_logic;
  wb_dat_i:   in std_logic_vector(wordSize-1 downto 0);
  wb_dat_o:   out std_logic_vector(wordSize-1 downto 0);
  wb_adr_i:   in std_logic_vector(maxIOBit downto minIOBit);
  wb_we_i:    in std_logic;
  wb_cyc_i:   in std_logic;
  wb_stb_i:   in std_logic;
  wb_ack_o:   out std_logic;
  wb_inta_o:  out std_logic;

  data_out:   out std_logic_vector(7 downto 0)
  );
  end component;

  component zpuino_fmath is
  port (
    wb_clk_i: in std_logic;
	 	wb_rst_i: in std_logic;
    wb_dat_o: out std_logic_vector(wordSize-1 downto 0);
    wb_dat_i: in std_logic_vector(wordSize-1 downto 0);
    wb_adr_i: in std_logic_vector(maxIOBit downto minIOBit);
    wb_we_i:  in std_logic;
    wb_cyc_i: in std_logic;
    wb_stb_i: in std_logic;
    wb_ack_o: out std_logic;
    wb_inta_o:out std_logic
  );
  end component;

  component multispi is
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

    -- Master interface (for DMA)

    mi_wb_dat_i: in std_logic_vector(wordSize-1 downto 0);
    mi_wb_dat_o: out std_logic_vector(wordSize-1 downto 0);
    mi_wb_adr_o: out std_logic_vector(maxAddrBitIncIO downto 0);
    mi_wb_sel_o: out std_logic_vector(3 downto 0);
    mi_wb_cti_o: out std_logic_vector(2 downto 0);
    mi_wb_we_o:  out std_logic;
    mi_wb_cyc_o: out std_logic;
    mi_wb_stb_o: out std_logic;
    mi_wb_ack_i: in std_logic;

    -- LED array interface (8 controllers)
    lmosi:     out std_logic_vector(9 downto 0);
    lsck:      out std_logic_vector(9 downto 0);

    -- SPI flash
    fmosi:      out std_logic;
    fmiso:      in std_logic;
    fsck:       out std_logic;
    fnsel:      out std_logic
  );
  end component;

  signal lmosi: std_logic_vector(9 downto 0);
  signal lsck: std_logic_vector(9 downto 0);

  signal extspi_fmosi:      std_logic;
  signal extspi_fmiso:      std_logic;
  signal   extspi_fsck:     std_logic;
  signal extspi_fnsel:      std_logic;


begin

  wb_clk_i <= sysclk;
  wb_rst_i <= sysrst;

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
    rstin   => dbg_reset,
    clkout  => sysclk,
    clkout_1mhz => sysclk_1mhz,
    rstout  => clkgen_rst
  );



  zpuino:zpuino_top
    port map (
      clk           => sysclk,
	 	  rst           => sysrst,

      slot_cyc      => slot_cyc,
      slot_we       => slot_we,
      slot_stb      => slot_stb,
      slot_read     => slot_read,
      slot_write    => slot_write,
      slot_address  => slot_address,
      slot_ack      => slot_ack,
      slot_interrupt=> slot_interrupt,

      m_wb_dat_o    => m_wb_dat_o,
      m_wb_dat_i    => m_wb_dat_i,
      m_wb_adr_i    => m_wb_adr_i,
      m_wb_we_i     => m_wb_we_i,
      m_wb_cyc_i    => m_wb_cyc_i,
      m_wb_stb_i    => m_wb_stb_i,
      m_wb_ack_o    => m_wb_ack_o,

      dbg_reset     => dbg_reset,
      jtag_data_chain_out => open,--jtag_data_chain_out,
      jtag_ctrl_chain_in  => (others=>'0')--jtag_ctrl_chain_in

    );

--  dbgport: zpuino_debug_jtag
--    port map (
--      jtag_data_chain_in => jtag_data_chain_out,
--      jtag_ctrl_chain_out => jtag_ctrl_chain_in,

--      TCK         => TCK,
--      TDI         => TDI,
--      CAPTUREIR   => CAPTUREIR,
--      UPDATEIR    => UPDATEIR,
--      SHIFTIR     => SHIFTIR,
--      CAPTUREDR   => CAPTUREDR,
--      UPDATEDR    => UPDATEDR,
--      SHIFTDR     => SHIFTDR,
--      TLR         => TLR,

--      TDO_IR      => TDO_IR,
--      TDO_DR      => TDO_DR
 --   );


--  dbgport_s3e: zpuino_debug_spartan3e
--    port map (
--
--      TCK         => TCK,
--      TDI         => TDI,
--      CAPTUREIR   => CAPTUREIR,
--      UPDATEIR    => UPDATEIR,
--      SHIFTIR     => SHIFTIR,
 --     CAPTUREDR   => CAPTUREDR,
  --    UPDATEDR    => UPDATEDR,
 --     SHIFTDR     => SHIFTDR,
--      TLR         => TLR,
--
--      TDO_IR      => TDO_IR,
--      TDO_DR      => TDO_DR
--
 --   );




  --
  --
  -- ----------------  I/O connection to devices --------------------
  --
  --

  --
  -- IO SLOT 0
  --

  slot0: zpuino_spi
  port map (
    wb_clk_i       => wb_clk_i,
	 	wb_rst_i    => wb_rst_i,
    wb_dat_o      => slot_read(0),
    wb_dat_i     => slot_write(0),
    wb_adr_i   => slot_address(0),
    wb_we_i        => slot_we(0),
    wb_cyc_i      => slot_cyc(0),
    wb_stb_i      => slot_stb(0),
    wb_ack_o      => slot_ack(0),
    wb_inta_o => slot_interrupt(0),

    mosi      => spi_pf_mosi,
    miso      => spi_pf_miso,
    sck       => spi_pf_sck,
    enabled   => spi_enabled
  );

  --
  -- IO SLOT 1
  --

  uart_inst: zpuino_uart
  port map (
    wb_clk_i       => wb_clk_i,
	 	wb_rst_i    => wb_rst_i,
    wb_dat_o      => slot_read(1),
    wb_dat_i     => slot_write(1),
    wb_adr_i   => slot_address(1),
    wb_we_i      => slot_we(1),
    wb_cyc_i       => slot_cyc(1),
    wb_stb_i       => slot_stb(1),
    wb_ack_o      => slot_ack(1),

    wb_inta_o => slot_interrupt(1),

    enabled   => uart_enabled,
    tx        => tx,
    rx        => rx
  );

  --
  -- IO SLOT 2
  --

  gpio_inst: zpuino_gpio
  generic map (
    gpio_count => zpuino_gpio_count
  )
  port map (
    wb_clk_i       => wb_clk_i,
	 	wb_rst_i    => wb_rst_i,
    wb_dat_o      => slot_read(2),
    wb_dat_i     => slot_write(2),
    wb_adr_i   => slot_address(2),
    wb_we_i        => slot_we(2),
    wb_cyc_i       => slot_cyc(2),
    wb_stb_i       => slot_stb(2),
    wb_ack_o      => slot_ack(2),
    wb_inta_o => slot_interrupt(2),

    spp_data  => gpio_spp_data,
    spp_read  => gpio_spp_read,

    gpio_i      => gpio_i,
    gpio_t      => gpio_t,
    gpio_o      => gpio_o,
    spp_cap_in   => spp_cap_in,
    spp_cap_out  => spp_cap_out
  );

  --
  -- IO SLOT 3
  --

  timers_inst: zpuino_timers
  generic map (
    A_TSCENABLED        => true,
    A_PWMCOUNT          => 1,
    A_WIDTH             => 16,
    A_PRESCALER_ENABLED => true,
    A_BUFFERS           => true,
    B_TSCENABLED        => false,
    B_PWMCOUNT          => 1,
    B_WIDTH             => 24,
    B_PRESCALER_ENABLED => false,
    B_BUFFERS           => false
  )
  port map (
    wb_clk_i       => wb_clk_i,
	 	wb_rst_i    => wb_rst_i,
    wb_dat_o      => slot_read(3),
    wb_dat_i     => slot_write(3),
    wb_adr_i   => slot_address(3),
    wb_we_i        => slot_we(3),
    wb_cyc_i        => slot_cyc(3),
    wb_stb_i        => slot_stb(3),
    wb_ack_o      => slot_ack(3),

    wb_inta_o => slot_interrupt(3), -- We use two interrupt lines
    wb_intb_o => slot_interrupt(4), -- so we borrow intr line from slot 4

    pwm_a_out   => timers_pwm(0 downto 0),
    pwm_b_out   => timers_pwm(1 downto 1)
  );

  --
  -- IO SLOT 4  - DO NOT USE (it's already mapped to Interrupt Controller)
  --

  --
  -- IO SLOT 5
  --

  sigmadelta_inst: zpuino_sigmadelta
  port map (
    wb_clk_i       => wb_clk_i,
	 	wb_rst_i    => wb_rst_i,
    wb_dat_o      => slot_read(5),
    wb_dat_i     => slot_write(5),
    wb_adr_i   => slot_address(5),
    wb_we_i        => slot_we(5),
    wb_cyc_i        => slot_cyc(5),
    wb_stb_i        => slot_stb(5),
    wb_ack_o      => slot_ack(5),
    wb_inta_o => slot_interrupt(5),

    spp_data  => sigmadelta_spp_data,
    spp_en    => sigmadelta_spp_en,
    sync_in   => '1'
  );

  --
  -- IO SLOT 6
  --

  slot1: zpuino_spi
  port map (
    wb_clk_i       => wb_clk_i,
	 	wb_rst_i    => wb_rst_i,
    wb_dat_o      => slot_read(6),
    wb_dat_i     => slot_write(6),
    wb_adr_i   => slot_address(6),
    wb_we_i        => slot_we(6),
    wb_cyc_i        => slot_cyc(6),
    wb_stb_i        => slot_stb(6),
    wb_ack_o      => slot_ack(6),
    wb_inta_o => slot_interrupt(6),

    mosi      => spi2_mosi,
    miso      => spi2_miso,
    sck       => spi2_sck,
    enabled   => open
  );



  --
  -- IO SLOT 7
  --

  crc16_inst: zpuino_crc16
  port map (
    wb_clk_i       => wb_clk_i,
	 	wb_rst_i    => wb_rst_i,
    wb_dat_o     => slot_read(7),
    wb_dat_i     => slot_write(7),
    wb_adr_i   => slot_address(7),
    wb_we_i     => slot_we(7),
    wb_cyc_i        => slot_cyc(7),
    wb_stb_i        => slot_stb(7),
    wb_ack_o      => slot_ack(7),
    wb_inta_o => slot_interrupt(7)
  );

  --
  -- IO SLOT 8 (optional)
  --

  spi3_inst: zpuino_spi
  port map (
    wb_clk_i       => wb_clk_i,
	 	wb_rst_i    => wb_rst_i,
    wb_dat_o      => slot_read(8),
    wb_dat_i     => slot_write(8),
    wb_adr_i   => slot_address(8),
    wb_we_i        => slot_we(8),
    wb_cyc_i      => slot_cyc(8),
    wb_stb_i      => slot_stb(8),
    wb_ack_o      => slot_ack(8),
    wb_inta_o => slot_interrupt(8),

    mosi      => spi3_mosi,
    miso      => '0',
    sck       => spi3_sck,
    enabled   => open
  );

  --
  -- IO SLOT 9
  --

  slot9: zpuino_empty_device
  port map (
    wb_clk_i       => wb_clk_i,
	 	wb_rst_i       => wb_rst_i,
    wb_dat_o      => slot_read(9),
    wb_dat_i     => slot_write(9),
    wb_adr_i   => slot_address(9),
    wb_we_i        => slot_we(9),
    wb_cyc_i        => slot_cyc(9),
    wb_stb_i        => slot_stb(9),
    wb_ack_o      => slot_ack(9),
    wb_inta_o => slot_interrupt(9)
  );

  --
  -- IO SLOT 10
  --

  slot10: zpuino_empty_device
  port map (
    wb_clk_i       => wb_clk_i,
	 	wb_rst_i       => wb_rst_i,
    wb_dat_o      => slot_read(10),
    wb_dat_i     => slot_write(10),
    wb_adr_i   => slot_address(10),
    wb_we_i        => slot_we(10),
    wb_cyc_i        => slot_cyc(10),
    wb_stb_i        => slot_stb(10),
    wb_ack_o      => slot_ack(10),
    wb_inta_o => slot_interrupt(10)
  );

  --
  -- IO SLOT 11
  --

  slot11: zpuino_uart
  generic map (
    bits => 4
  )
  port map (
    wb_clk_i       => wb_clk_i,
	 	wb_rst_i    => wb_rst_i,
    wb_dat_o      => slot_read(11),
    wb_dat_i     => slot_write(11),
    wb_adr_i   => slot_address(11),
    wb_we_i      => slot_we(11),
    wb_cyc_i       => slot_cyc(11),
    wb_stb_i       => slot_stb(11),
    wb_ack_o      => slot_ack(11),

    wb_inta_o => slot_interrupt(11),

    tx        => uart2_tx,
    rx        => uart2_rx
  );

  --
  -- IO SLOT 12
  --

  slot12: zpuino_empty_device
  port map (
    wb_clk_i       => wb_clk_i,
	 	wb_rst_i       => wb_rst_i,
    wb_dat_o      => slot_read(12),
    wb_dat_i     => slot_write(12),
    wb_adr_i   => slot_address(12),
    wb_we_i        => slot_we(12),
    wb_cyc_i        => slot_cyc(12),
    wb_stb_i        => slot_stb(12),
    wb_ack_o      => slot_ack(12),
    wb_inta_o => slot_interrupt(12)
  );

  --
  -- IO SLOT 13
  --

  slot13: zpuino_fmath
  port map (
    wb_clk_i       => wb_clk_i,
	 	wb_rst_i       => wb_rst_i,
    wb_dat_o      => slot_read(13),
    wb_dat_i     => slot_write(13),
    wb_adr_i   => slot_address(13),
    wb_we_i        => slot_we(13),
    wb_cyc_i        => slot_cyc(13),
    wb_stb_i        => slot_stb(13),
    wb_ack_o      => slot_ack(13),
    wb_inta_o => slot_interrupt(13)
  );

  --
  -- IO SLOT 14
  --

  slot14: multispi
  port map (
    wb_clk_i       => wb_clk_i,
	 	wb_rst_i       => wb_rst_i,
    wb_dat_o      => slot_read(14),
    wb_dat_i     => slot_write(14),
    wb_adr_i   => slot_address(14),
    wb_we_i        => slot_we(14),
    wb_cyc_i        => slot_cyc(14),
    wb_stb_i        => slot_stb(14),
    wb_ack_o      => slot_ack(14),
    wb_inta_o => slot_interrupt(14),

    -- Master interface (for DMA)

    mi_wb_dat_i => m_wb_dat_o,
    mi_wb_dat_o => m_wb_dat_i,
    mi_wb_adr_o => m_wb_adr_i,
    mi_wb_sel_o => m_wb_sel_i,
    mi_wb_cti_o => m_wb_cti_i,
    mi_wb_we_o  => m_wb_we_i,
    mi_wb_cyc_o => m_wb_cyc_i,
    mi_wb_stb_o => m_wb_stb_i,
    mi_wb_ack_i => m_wb_ack_o,

    -- LED array interface (8 controllers)
    lmosi       => lmosi,
    lsck        => lsck,

    -- SPI flash
    fmosi       => extspi_fmosi,
    fmiso       => extspi_fmiso,
    fsck        => extspi_fsck,
    fnsel       => extspi_fnsel
  );

  --
  -- IO SLOT 15
  --

  slot15: zpuino_empty_device
  port map (
    wb_clk_i       => wb_clk_i,
	 	wb_rst_i       => wb_rst_i,
    wb_dat_o      => slot_read(15),
    wb_dat_i     => slot_write(15),
    wb_adr_i   => slot_address(15),
    wb_we_i        => slot_we(15),
    wb_cyc_i        => slot_cyc(15),
    wb_stb_i        => slot_stb(15),
    wb_ack_o      => slot_ack(15),
    wb_inta_o => slot_interrupt(15)
  );

  pin00: OPAD port map(I => lsck(5),  PAD => WING_A(0) );
  pin01: OPAD port map(I => lmosi(5), PAD => WING_A(1) );
  pin02: OPAD port map(I => lsck(4),  PAD => WING_A(2) );
  pin03: OPAD port map(I => lmosi(4), PAD => WING_A(3) );
  pin04: OPAD port map(I => lsck(3),  PAD => WING_A(4) );
  pin05: OPAD port map(I => lmosi(3), PAD => WING_A(5) );
  pin06: OPAD port map(I => lsck(2),  PAD => WING_A(6) );
  pin07: OPAD port map(I => lmosi(2), PAD => WING_A(7) );


  pin08: OPAD port map(I => lsck(1),  PAD => WING_A(8) );
  pin09: OPAD port map(I => lmosi(1), PAD => WING_A(9) );
  pin10: OPAD port map(I => lsck(0),  PAD => WING_A(10) );
  pin11: OPAD port map(I => lmosi(0), PAD => WING_A(11) );

  pin12: OPAD port map(I => extspi_fnsel, PAD => WING_A(12) );
  pin13: OPAD port map(I => extspi_fmosi, PAD => WING_A(13) );
  pin14: OPAD port map(I => lsck(8), PAD => WING_A(14) );
  pin15: OPAD port map(I => lmosi(8), PAD => WING_A(15) );

  pin16: OPAD port map(I => lmosi(0), PAD => WING_B(0) );
  pin17: OPAD port map(I => lsck(0),  PAD => WING_B(1) );
  pin18: OPAD port map(I => lmosi(1), PAD => WING_B(2) );
  pin19: OPAD port map(I => lsck(1),  PAD => WING_B(3) );
  pin20: OPAD port map(I => lmosi(2), PAD => WING_B(4) );
  pin21: OPAD port map(I => lsck(2),  PAD => WING_B(5) );
  pin22: OPAD port map(I => lmosi(3), PAD => WING_B(6) );
  pin23: OPAD port map(I => lsck(3),  PAD => WING_B(7) );
  pin24: OPAD port map(I => lmosi(4), PAD => WING_B(8) );
  pin25: OPAD port map(I => lsck(4),  PAD => WING_B(9) );
  pin26: OPAD port map(I => lmosi(5), PAD => WING_B(10) );
  pin27: OPAD port map(I => lsck(5),  PAD => WING_B(11) );
  pin28: OPAD port map(I => lmosi(6), PAD => WING_B(12) );
  pin29: OPAD port map(I => lsck(6),  PAD => WING_B(13) );
  pin30: OPAD port map(I => lmosi(7), PAD => WING_B(14) );
  pin31: OPAD port map(I => lsck(7),  PAD => WING_B(15) );


  pin32: IOPAD port map(I => gpio_o(32),O => gpio_i(32),T => gpio_t(32),C => sysclk,PAD => WING_C(0) );
  pin33: IOPAD port map(I => gpio_o(33),O => gpio_i(33),T => gpio_t(33),C => sysclk,PAD => WING_C(1) );
  pin34: IOPAD port map(I => gpio_o(34),O => gpio_i(34),T => gpio_t(34),C => sysclk,PAD => WING_C(2) );
  pin35: IOPAD port map(I => gpio_o(35),O => gpio_i(35),T => gpio_t(35),C => sysclk,PAD => WING_C(3) );
  pin36: IOPAD port map(I => gpio_o(36),O => gpio_i(36),T => gpio_t(36),C => sysclk,PAD => WING_C(4) );
  pin37: IOPAD port map(I => gpio_o(37),O => gpio_i(37),T => gpio_t(37),C => sysclk,PAD => WING_C(5) );
  pin38: IOPAD port map(I => gpio_o(38),O => gpio_i(38),T => gpio_t(38),C => sysclk,PAD => WING_C(6) );
  pin39: IOPAD port map(I => gpio_o(39),O => gpio_i(39),T => gpio_t(39),C => sysclk,PAD => WING_C(7) );
  pin40: IOPAD port map(I => gpio_o(40),O => gpio_i(40),T => gpio_t(40),C => sysclk,PAD => WING_C(8) );
  pin41: IOPAD port map(I => gpio_o(41),O => gpio_i(41),T => gpio_t(41),C => sysclk,PAD => WING_C(9) );
  pin42: IOPAD port map(I => gpio_o(42),O => gpio_i(42),T => gpio_t(42),C => sysclk,PAD => WING_C(10) );
  pin43: IOPAD port map(I => gpio_o(43),O => gpio_i(43),T => gpio_t(43),C => sysclk,PAD => WING_C(11) );
  pin44: IOPAD port map(I => gpio_o(44),O => gpio_i(44),T => gpio_t(44),C => sysclk,PAD => WING_C(12) );
  pin45: IOPAD port map(I => gpio_o(45),O => gpio_i(45),T => gpio_t(45),C => sysclk,PAD => WING_C(13) );
  --pin46: IOPAD port map(I => gpio_o(46),O => gpio_i(46),T => gpio_t(46),C => sysclk,PAD => WING_C(14) );
  pin46: OPAD port map(I => spi3_sck, PAD => WING_C(14) );
  --pin47: IOPAD port map(I => gpio_o(47),O => gpio_i(47),T => gpio_t(47),C => sysclk,PAD => WING_C(15) );
  pin47: OPAD port map(I => spi3_mosi, PAD => WING_C(15) );

  -- Other ports are special, we need to avoid outputs on input-only pins

  ibufrx:   IPAD port map ( PAD => RXD,        O => rx, C => sysclk );
--  ibufmiso: IPAD port map ( PAD => SPI_MISO,   O => spi_pf_miso, C => sysclk );
  spi_pf_miso <= SPI_MISO;
  obuftx:   OPAD port map ( I => tx,   PAD => TXD );
  ospiclk:  OPAD port map ( I => spi_pf_sck,   PAD => SPI_SCK );
  ospics:   OPAD port map ( I => gpio_o(48),   PAD => SPI_CS );
  ospimosi: OPAD port map ( I => spi_pf_mosi,   PAD => SPI_MOSI );


  process(gpio_spp_read,
          sigmadelta_spp_data,
          timers_pwm,
          spi2_mosi,spi2_sck)
  begin

    gpio_spp_data <= (others => DontCareValue);

    gpio_spp_data(0) <= sigmadelta_spp_data(0); -- PPS0 : SIGMADELTA DATA
    gpio_spp_data(1) <= timers_pwm(0);          -- PPS1 : TIMER0
    gpio_spp_data(2) <= timers_pwm(1);          -- PPS2 : TIMER1
    gpio_spp_data(3) <= spi2_mosi;              -- PPS3 : USPI MOSI
    gpio_spp_data(4) <= spi2_sck;               -- PPS4 : USPI SCK
    gpio_spp_data(5) <= sigmadelta_spp_data(1); -- PPS5 : SIGMADELTA1 DATA
    gpio_spp_data(6) <= uart2_tx;               -- PPS6 : UART2 DATA
    spi2_miso <= gpio_spp_read(0);              -- PPS0 : USPI MISO
    uart2_rx <= gpio_spp_read(1);              -- PPS0 : USPI MISO

  end process;


end behave;
