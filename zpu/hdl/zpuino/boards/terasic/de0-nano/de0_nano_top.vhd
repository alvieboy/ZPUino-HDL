--
--
--  ZPUINO implementation on Terasic DE0-Nano Board
-- 
--  Copyright 2017 Alvaro Lopes <alvieboy@alvie.com>
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
use work.wishbonepkg.all;

entity de0_nano_top is
  port (
    -- Clock
	  CLOCK_50:       in std_logic;
    -- LED
	  LED:            out std_logic_vector(7 downto 0);
    -- Debounced keys
	  KEY:            in std_logic_vector(1 downto 0);
    -- DIP switches
	  SW:             in std_logic_vector(3 downto 0);
    -- DRAM connections
    DRAM_ADDR:      out std_logic_vector(12 downto 0);
    DRAM_BA:        out std_logic_vector(1 downto 0);
    DRAM_CAS_N:     out std_logic;
    DRAM_CKE:       out std_logic;
    DRAM_CLK:       out std_logic;
    DRAM_CS_N:      out std_logic;
    DRAM_DQ:        inout std_logic_vector(15 downto 0);
    DRAM_DQM:       out std_logic_vector(1 downto 0);
    DRAM_RAS_N:     out std_logic;
    DRAM_WE_N:      out std_logic;
    -- EPCS (serial flash)
  	EPCS_ASDO:      out std_logic;
	  EPCS_DATA0:     in std_logic;
	  EPCS_DCLK:      out std_logic;
	  EPCS_NCSO:      out std_logic;
    -- I2C sensor
    G_SENSOR_CS_N:  out std_logic;
    G_SENSOR_INT:   in std_logic;
    I2C_SCLK:       inout std_logic;
    I2C_SDAT:       inout std_logic;
    -- ADC
	  ADC_CS_N:       out std_logic;
	  ADC_SADDR:      out std_logic;
	  ADC_SCLK:       out std_logic;
	  ADC_SDAT:       in std_logic;
    -- GPIO Header 0
    GPIO_0:         inout std_logic_vector(33 downto 0);
    GPIO_0_IN:      in std_logic_vector(1 downto 0);
    -- GPIO Header 1
    GPIO_1:         inout std_logic_vector(33 downto 0);
    GPIO_1_IN:      in std_logic_vector(1 downto 0);
    -- GPIO Header 2
    GPIO_2:         inout std_logic_vector(12 downto 0);
    GPIO_2_IN:      in std_logic_vector(2 downto 0)
  );
end entity de0_nano_top;


architecture behave of de0_nano_top is


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

  component wb_bootloader is
  port (
    wb_clk_i:   in std_logic;
    wb_rst_i:   in std_logic;

    wb_dat_o:   out std_logic_vector(31 downto 0);
    wb_adr_i:   in std_logic_vector(11 downto 2);
    wb_cyc_i:   in std_logic;
    wb_stb_i:   in std_logic;
    wb_ack_o:   out std_logic;
    wb_stall_o: out std_logic;

    wb2_dat_o:   out std_logic_vector(31 downto 0);
    wb2_adr_i:   in std_logic_vector(11 downto 2);
    wb2_cyc_i:   in std_logic;
    wb2_stb_i:   in std_logic;
    wb2_ack_o:   out std_logic;
    wb2_stall_o: out std_logic
  );
  end component;

  signal sysrst:      std_logic;
  signal sysclk:      std_logic;
  signal clkgen_rst:  std_logic;
  signal wb_clk_i:    std_logic;
  signal wb_rst_i:    std_logic;

  signal gpio_o:      std_logic_vector(zpuino_gpio_count-1 downto 0);
  signal gpio_t:      std_logic_vector(zpuino_gpio_count-1 downto 0);
  signal gpio_i:      std_logic_vector(zpuino_gpio_count-1 downto 0);

  constant spp_cap_in: std_logic_vector(zpuino_gpio_count-1 downto 0) :=
    "0000000000000000000000000000" &
    "0000000000000000000000000000000000" &
    "1111111111111111111111111111111111";

  constant spp_cap_out: std_logic_vector(zpuino_gpio_count-1 downto 0) :=
    "0000000000000000000000000000" &
    "0000000000000000000000000000000000" &
    "1111111111111111111111111111111111";

  -- I/O Signals
  signal slot_cyc:    slot_std_logic_type;
  signal slot_we:     slot_std_logic_type;
  signal slot_stb:    slot_std_logic_type;
  signal slot_read:   slot_cpuword_type;
  signal slot_write:  slot_cpuword_type;
  signal slot_address:slot_address_type;
  signal slot_ack:    slot_std_logic_type;
  signal slot_interrupt: slot_std_logic_type;
  signal slot_ids:    slot_id_type;

  -- 2nd SPI signals
  signal spi2_mosi:   std_logic;
  signal spi2_miso:   std_logic;
  signal spi2_sck:    std_logic;

  -- GPIO Periperal Pin Select
  signal gpio_spp_data: std_logic_vector(PPSCOUNT_OUT-1 downto 0);
  signal gpio_spp_read: std_logic_vector(PPSCOUNT_IN-1 downto 0);
  signal ppsout_info_slot: ppsoutinfotype := (others => 0);
  signal ppsout_info_pin:  ppsoutinfotype;
  signal ppsin_info_slot: ppsininfotype := (others => 0);
  signal ppsin_info_pin:  ppsininfotype;

  -- Timer connections
  signal timers_interrupt:  std_logic_vector(1 downto 0);
  signal timers_pwm:        std_logic_vector(1 downto 0);

  -- Sigmadelta output
  signal sigmadelta_spp_data: std_logic_vector(1 downto 0);

  -- main SPI signals
  signal spi_pf_miso: std_logic;
  signal spi_pf_mosi: std_logic;
  signal spi_pf_sck:  std_logic;

  -- UART signals
  signal rx: std_logic;
  signal tx: std_logic;
  signal sysclk_sram_we, sysclk_sram_wen: std_ulogic;

  signal ram_wb_ack_o:       std_logic;
  signal ram_wb_dat_i:       std_logic_vector(wordSize-1 downto 0);
  signal ram_wb_dat_o:       std_logic_vector(wordSize-1 downto 0);
  signal ram_wb_adr_i:       std_logic_vector(maxAddrBitIncIO downto 0);
  signal ram_wb_cyc_i:       std_logic;
  signal ram_wb_stb_i:       std_logic;
  signal ram_wb_sel_i:       std_logic_vector(3 downto 0);
  signal ram_wb_we_i:        std_logic;
  signal ram_wb_stall_o:     std_logic;

  signal np_ram_wb_ack_o:       std_logic;
  signal np_ram_wb_dat_i:       std_logic_vector(wordSize-1 downto 0);
  signal np_ram_wb_dat_o:       std_logic_vector(wordSize-1 downto 0);
  signal np_ram_wb_adr_i:       std_logic_vector(maxAddrBitIncIO downto 0);
  signal np_ram_wb_cyc_i:       std_logic;
  signal np_ram_wb_stb_i:       std_logic;
  signal np_ram_wb_sel_i:       std_logic_vector(3 downto 0);
  signal np_ram_wb_we_i:        std_logic;

  signal sram_wb_ack_o:       std_logic;
  signal sram_wb_dat_i:       std_logic_vector(wordSize-1 downto 0);
  signal sram_wb_dat_o:       std_logic_vector(wordSize-1 downto 0);
  signal sram_wb_adr_i:       std_logic_vector(maxAddrBitIncIO downto 0);
  signal sram_wb_cyc_i:       std_logic;
  signal sram_wb_stb_i:       std_logic;
  signal sram_wb_we_i:        std_logic;
  signal sram_wb_sel_i:       std_logic_vector(3 downto 0);
  signal sram_wb_stall_o:     std_logic;

  signal rom_wb_ack_o:       std_logic;
  signal rom_wb_dat_o:       std_logic_vector(wordSize-1 downto 0);
  signal rom_wb_adr_i:       std_logic_vector(maxAddrBitIncIO downto 0);
  signal rom_wb_cyc_i:       std_logic;
  signal rom_wb_stb_i:       std_logic;
  signal rom_wb_cti_i:       std_logic_vector(2 downto 0);
  signal rom_wb_stall_o:     std_logic;

  signal sram_rom_wb_ack_o:       std_logic;
  signal sram_rom_wb_dat_o:       std_logic_vector(wordSize-1 downto 0);
  signal sram_rom_wb_adr_i:       std_logic_vector(maxAddrBit downto 2);
  signal sram_rom_wb_cyc_i:       std_logic;
  signal sram_rom_wb_stb_i:       std_logic;
  signal sram_rom_wb_cti_i:       std_logic_vector(2 downto 0);
  signal sram_rom_wb_stall_o:     std_logic;

  signal prom_rom_wb_ack_o:       std_logic;
  signal prom_rom_wb_dat_o:       std_logic_vector(wordSize-1 downto 0);
  signal prom_rom_wb_adr_i:       std_logic_vector(maxAddrBit downto 2);
  signal prom_rom_wb_cyc_i:       std_logic;
  signal prom_rom_wb_stb_i:       std_logic;
  signal prom_rom_wb_cti_i:       std_logic_vector(2 downto 0);
  signal prom_rom_wb_stall_o:     std_logic;

  signal memory_enable: std_logic;

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

  signal uart2_rx: std_logic;
  signal uart2_tx: std_logic;

  signal ramwbi:  wb_mosi_type;
  signal ramwbo:  wb_p_miso_type;

  alias RXD: std_logic is GPIO_2(0);
  alias TXD: std_logic is GPIO_2(1);

  alias SPI_MISO: std_logic is EPCS_DATA0;
  alias SPI_MOSI: std_logic is EPCS_ASDO;
  alias SPI_SCK:  std_logic is EPCS_DCLK;
  alias SPI_CS:   std_logic is EPCS_NCSO;

  alias CLK:      std_ulogic is CLOCK_50;

  signal scl_pad_i     : std_logic;                    -- i2c clock line input
  signal scl_pad_o     : std_logic;                    -- i2c clock line output
  signal scl_padoen_o  : std_logic;                    -- i2c clock line output enable, active low
  signal sda_pad_i     : std_logic;                    -- i2c data line input
  signal sda_pad_o     : std_logic;                    -- i2c data line output
  signal sda_padoen_o  : std_logic;                    -- i2c data line output enable, active low


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

  clkgen_inst: entity work.clkgen
  port map (
    clkin   => clk,
    rstin   => '0'  ,
    clkout  => sysclk,
    rstout  => clkgen_rst
  );

  iopads: block
  begin

  -- GPIO 0 to 33 map to GPIO0 block
  gp0_gen: for i in 0 to 33 generate
    pin: IOPAD port map(I => gpio_o(i),O => gpio_i(i),T => gpio_t(i),C => sysclk,PAD => GPIO_0(i) );
  end generate;

  -- GPIO 34 to 67 map to GPIO1 block
  gp1_gen: for i in 0 to 33 generate
    pin: IOPAD port map(I => gpio_o(34+i),O => gpio_i(34+i),T => gpio_t(34+i),C => sysclk,PAD => GPIO_1(i) );
  end generate;

  -- first 2 GPIO reserved for UART

  -- GPIO 68 to 78 map to GPIO2 block

  gp2_gen: for i in 2 to 12 generate
    pin: IOPAD port map(I => gpio_o(68+i-2),O => gpio_i(68+i-2),T => gpio_t(68+i-2),C => sysclk,PAD => GPIO_2(i) );
  end generate;

  -- Other ports are special, we need to avoid outputs on input-only pins

  ibufrx:   IPAD port map ( PAD => RXD,        O => rx,           C => sysclk );
  obuftx:   OPAD port map ( I => tx,           PAD => TXD );

  ibufmiso: IPAD port map ( PAD => SPI_MISO,   O => spi_pf_miso,  C => sysclk );
  ospiclk:  OPAD port map ( I => spi_pf_sck,   PAD => SPI_SCK );
  ospics:   OPAD port map ( I => gpio_o(79),   PAD => SPI_CS );
  ospimosi: OPAD port map ( I => spi_pf_mosi,  PAD => SPI_MOSI );

  oled0:    OPAD port map ( I => gpio_o(80),   PAD => LED(0) );
  oled1:    OPAD port map ( I => gpio_o(81),   PAD => LED(1) );
  oled2:    OPAD port map ( I => gpio_o(82),   PAD => LED(2) );
  oled3:    OPAD port map ( I => gpio_o(83),   PAD => LED(3) );
  oled4:    OPAD port map ( I => gpio_o(84),   PAD => LED(4) );
  oled5:    OPAD port map ( I => gpio_o(85),   PAD => LED(5) );
  oled6:    OPAD port map ( I => gpio_o(86),   PAD => LED(6) );
  oled7:    OPAD port map ( I => gpio_o(87),   PAD => LED(7) );

  -- KEY in
  kin0:     IPAD port map ( O => gpio_i(88),   C => sysclk, PAD => KEY(0) );
  kin1:     IPAD port map ( O => gpio_i(89),   C => sysclk, PAD => KEY(1) );

  -- DIP switches
  dip0:     IPAD port map ( O => gpio_i(90),   C => sysclk, PAD => SW(0) );
  dip1:     IPAD port map ( O => gpio_i(91),   C => sysclk, PAD => SW(1) );
  dip2:     IPAD port map ( O => gpio_i(92),   C => sysclk, PAD => SW(2) );
  dip3:     IPAD port map ( O => gpio_i(93),   C => sysclk, PAD => SW(3) );
  -- Misc select lines

  gssel:    OPAD port map ( I => gpio_o(94),   PAD => G_SENSOR_CS_N );
  adcsel:   OPAD port map ( I => gpio_o(95),   PAD => ADC_CS_N );

  end block;


  zpuino: entity work.zpuino_top_icache
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
      slot_id       => slot_ids,

      pps_in_slot   => ppsin_info_slot,
      pps_in_pin    => ppsin_info_pin,

      pps_out_slot => ppsout_info_slot,
      pps_out_pin  => ppsout_info_pin,

      m_wb_dat_o    => open,
      m_wb_dat_i    => (others => 'X'),
      m_wb_adr_i    => (others => 'X'),
      m_wb_we_i     => '0',
      m_wb_cyc_i    => '0',
      m_wb_stb_i    => '0',
      m_wb_cti_i    => CTI_CYCLE_CLASSIC,
      m_wb_ack_o    => open,
      m_wb_stall_o  => open,

      wb_ack_i      => sram_wb_ack_o,
      wb_stall_i    => sram_wb_stall_o,
      wb_dat_o      => sram_wb_dat_i,
      wb_dat_i      => sram_wb_dat_o,
      wb_adr_o      => sram_wb_adr_i(maxAddrBit downto 0),
      wb_cyc_o      => sram_wb_cyc_i,
      wb_stb_o      => sram_wb_stb_i,
      wb_sel_o      => sram_wb_sel_i,
      wb_we_o       => sram_wb_we_i,

      -- No debug unit connected
      dbg_reset     => open,
      jtag_data_chain_out => open,            --jtag_data_chain_in,
      jtag_ctrl_chain_in  => (others => '0') --jtag_ctrl_chain_out
    );


  sysclk_sram_we <= not wb_clk_i;

  sram_inst: entity work.sdram_ctrl
    port map (
      wb_clk_i    => wb_clk_i,
  	 	wb_rst_i    => wb_rst_i,
      wb_dat_o    => sram_wb_dat_o,
      wb_dat_i    => sram_wb_dat_i,
      wb_adr_i    => sram_wb_adr_i(maxIObit downto minIObit),
      wb_we_i     => sram_wb_we_i,
      wb_cyc_i    => sram_wb_cyc_i,
      wb_stb_i    => sram_wb_stb_i,
      wb_sel_i    => sram_wb_sel_i,
      wb_ack_o    => sram_wb_ack_o,
      wb_stall_o  => sram_wb_stall_o,

      clk_off_3ns => sysclk_sram_we,
      DRAM_ADDR   => DRAM_ADDR(11 downto 0),
      DRAM_BA     => DRAM_BA,
      DRAM_CAS_N  => DRAM_CAS_N,
      DRAM_CKE    => DRAM_CKE,
      DRAM_CLK    => DRAM_CLK,
      DRAM_CS_N   => DRAM_CS_N,
      DRAM_DQ     => DRAM_DQ,
      DRAM_DQM    => DRAM_DQM,
      DRAM_RAS_N  => DRAM_RAS_N,
      DRAM_WE_N   => DRAM_WE_N
    );

    DRAM_ADDR(12) <= '0';


  --
  -- IO SLOT 1
  --

  uart_inst: zpuino_uart
  generic map (
    bits  => 8
  )
  port map (
    wb_clk_i      => wb_clk_i,
	 	wb_rst_i      => wb_rst_i,
    wb_dat_o      => slot_read(1),
    wb_dat_i      => slot_write(1),
    wb_adr_i      => slot_address(1),
    wb_we_i       => slot_we(1),
    wb_cyc_i      => slot_cyc(1),
    wb_stb_i      => slot_stb(1),
    wb_ack_o      => slot_ack(1),
    wb_inta_o     => slot_interrupt(1),
    id            => slot_ids(1),

    enabled       => open,
    tx            => tx,
    rx            => rx
  );

  --
  -- IO SLOT 2
  --

  gpio_inst: zpuino_gpio
  generic map (
    gpio_count => zpuino_gpio_count
  )
  port map (
    wb_clk_i      => wb_clk_i,
	 	wb_rst_i      => wb_rst_i,
    wb_dat_o      => slot_read(2),
    wb_dat_i      => slot_write(2),
    wb_adr_i      => slot_address(2),
    wb_we_i       => slot_we(2),
    wb_cyc_i      => slot_cyc(2),
    wb_stb_i      => slot_stb(2),
    wb_ack_o      => slot_ack(2),
    wb_inta_o     => slot_interrupt(2),
    id            => slot_ids(2),

    spp_data      => gpio_spp_data,
    spp_read      => gpio_spp_read,

    gpio_i        => gpio_i,
    gpio_t        => gpio_t,
    gpio_o        => gpio_o,
    spp_cap_in    => spp_cap_in,
    spp_cap_out   => spp_cap_out
  );

  --
  -- IO SLOT 3
  --

  timers_inst: zpuino_timers
  generic map (
    A_TSCENABLED        => true,
    A_PWMCOUNT          => 1,
    A_WIDTH             => 32,
    A_PRESCALER_ENABLED => true,
    A_BUFFERS           => true,
    B_TSCENABLED        => false,
    B_PWMCOUNT          => 1,
    B_WIDTH             => 24,
    B_PRESCALER_ENABLED => true,
    B_BUFFERS           => false
  )
  port map (
    wb_clk_i      => wb_clk_i,
	 	wb_rst_i      => wb_rst_i,
    wb_dat_o      => slot_read(3),
    wb_dat_i      => slot_write(3),
    wb_adr_i      => slot_address(3),
    wb_we_i       => slot_we(3),
    wb_cyc_i      => slot_cyc(3),
    wb_stb_i      => slot_stb(3),
    wb_ack_o      => slot_ack(3),
    id            => slot_ids(3),

    wb_inta_o     => slot_interrupt(3), -- We use two interrupt lines
    wb_intb_o     => slot_interrupt(4), -- so we borrow intr line from slot 4

    pwm_a_out   => timers_pwm(0 downto 0),
    pwm_b_out   => timers_pwm(1 downto 1)
  );

  --
  -- IO SLOT 4
  --

  slot4: zpuino_spi
  generic map (
    INTERNAL_SPI => true
  )
  port map (
    wb_clk_i      => wb_clk_i,
	 	wb_rst_i      => wb_rst_i,
    wb_dat_o      => slot_read(4),
    wb_dat_i      => slot_write(4),
    wb_adr_i      => slot_address(4),
    wb_we_i       => slot_we(4),
    wb_cyc_i      => slot_cyc(4),
    wb_stb_i      => slot_stb(4),
    wb_ack_o      => slot_ack(4),
    -- wb_inta_o     => slot_interrupt(4), -- Used by the Timers.
    id            => slot_ids(4),
    mosi          => spi_pf_mosi,
    miso          => spi_pf_miso,
    sck           => spi_pf_sck
  );

  --
  -- IO SLOT 5
  --

  sigmadelta_inst: zpuino_sigmadelta
  port map (
    wb_clk_i      => wb_clk_i,
	 	wb_rst_i      => wb_rst_i,
    wb_dat_o      => slot_read(5),
    wb_dat_i      => slot_write(5),
    wb_adr_i      => slot_address(5),
    wb_we_i       => slot_we(5),
    wb_cyc_i      => slot_cyc(5),
    wb_stb_i      => slot_stb(5),
    wb_ack_o      => slot_ack(5),
    wb_inta_o     => slot_interrupt(5),
    id            => slot_ids(5),

    spp_data      => sigmadelta_spp_data,
    spp_en        => open,
    sync_in       => '1'
  );

  --
  -- IO SLOT 6
  --

  slot1: zpuino_spi
  port map (
    wb_clk_i      => wb_clk_i,
	 	wb_rst_i      => wb_rst_i,
    wb_dat_o      => slot_read(6),
    wb_dat_i      => slot_write(6),
    wb_adr_i      => slot_address(6),
    wb_we_i       => slot_we(6),
    wb_cyc_i      => slot_cyc(6),
    wb_stb_i      => slot_stb(6),
    wb_ack_o      => slot_ack(6),
    wb_inta_o     => slot_interrupt(6),
    id            => slot_ids(6),

    mosi          => spi2_mosi,
    miso          => spi2_miso,
    sck           => spi2_sck,
    enabled       => open
  );



  --
  -- IO SLOT 7
  --

  crc16_inst: zpuino_crc16
  port map (
    wb_clk_i      => wb_clk_i,
	 	wb_rst_i      => wb_rst_i,
    wb_dat_o      => slot_read(7),
    wb_dat_i      => slot_write(7),
    wb_adr_i      => slot_address(7),
    wb_we_i       => slot_we(7),
    wb_cyc_i      => slot_cyc(7),
    wb_stb_i      => slot_stb(7),
    wb_ack_o      => slot_ack(7),
    wb_inta_o     => slot_interrupt(7),
    id            => slot_ids(7)
  );

  --
  -- IO SLOT 8
  --

  slot8: zpuino_uart
  generic map (
    bits  => 8
  )
  port map (
    wb_clk_i      => wb_clk_i,
	 	wb_rst_i      => wb_rst_i,
    wb_dat_o      => slot_read(8),
    wb_dat_i      => slot_write(8),
    wb_adr_i      => slot_address(8),
    wb_we_i       => slot_we(8),
    wb_cyc_i      => slot_cyc(8),
    wb_stb_i      => slot_stb(8),
    wb_ack_o      => slot_ack(8),
    wb_inta_o     => slot_interrupt(8),
    id            => slot_ids(8),
    tx            => uart2_tx,
    rx            => uart2_rx
  );

  --
  -- IO SLOT 9
  --

  slot9: zpuino_empty_device
  port map (
    wb_clk_i      => wb_clk_i,
	 	wb_rst_i      => wb_rst_i,
    wb_dat_o      => slot_read(9),
    wb_dat_i      => slot_write(9),
    wb_adr_i      => slot_address(9),
    wb_we_i       => slot_we(9),
    wb_cyc_i      => slot_cyc(9),
    wb_stb_i      => slot_stb(9),
    wb_ack_o      => slot_ack(9),
    wb_inta_o     => slot_interrupt(9),
    id            => slot_ids(9)
  );


  --
  -- IO SLOT 10
  --

  slot10: zpuino_empty_device
  port map (
    wb_clk_i      => wb_clk_i,
	 	wb_rst_i      => wb_rst_i,
    wb_dat_o      => slot_read(10),
    wb_dat_i      => slot_write(10),
    wb_adr_i      => slot_address(10),
    wb_we_i       => slot_we(10),
    wb_cyc_i      => slot_cyc(10),
    wb_stb_i      => slot_stb(10),
    wb_ack_o      => slot_ack(10),
    wb_inta_o     => slot_interrupt(10),
    id            => slot_ids(10)
  );

  --
  -- IO SLOT 11
  --

  slot11: zpuino_empty_device
  port map (
    wb_clk_i      => wb_clk_i,
	 	wb_rst_i      => wb_rst_i,
    wb_dat_o      => slot_read(11),
    wb_dat_i      => slot_write(11),
    wb_adr_i      => slot_address(11),
    wb_we_i       => slot_we(11),
    wb_cyc_i      => slot_cyc(11),
    wb_stb_i      => slot_stb(11),
    wb_ack_o      => slot_ack(11),
    wb_inta_o     => slot_interrupt(11),
    id            => slot_ids(11)
  );

  --
  -- IO SLOT 12
  --

  slot12: zpuino_spi
  port map (
    wb_clk_i      => wb_clk_i,
	 	wb_rst_i      => wb_rst_i,
    wb_dat_o      => slot_read(12),
    wb_dat_i      => slot_write(12),
    wb_adr_i      => slot_address(12),
    wb_we_i       => slot_we(12),
    wb_cyc_i      => slot_cyc(12),
    wb_stb_i      => slot_stb(12),
    wb_ack_o      => slot_ack(12),
    wb_inta_o     => slot_interrupt(12),
    id            => slot_ids(12),

    mosi          => ADC_SADDR,
    miso          => ADC_SDAT,
    sck           => ADC_SCLK,
    enabled       => open
  );

  --
  -- IO SLOT 13
  --

  slot13: entity work.i2c_master_top
  port map (
    wb_clk_i      => wb_clk_i,
	 	wb_rst_i      => wb_rst_i,
    wb_dat_o      => slot_read(13)(7 downto 0),
    wb_dat_i      => slot_write(13)(7 downto 0),
    wb_adr_i      => slot_address(13)(4 downto 2),
    wb_we_i       => slot_we(13),
    wb_cyc_i      => slot_cyc(13),
    wb_stb_i      => slot_stb(13),
    wb_ack_o      => slot_ack(13),
    wb_inta_o     => slot_interrupt(13),
    id            => slot_ids(13),

    scl_pad_i     => scl_pad_i,
    scl_pad_o     => scl_pad_o,                    -- i2c clock line output
    scl_padoen_o  => scl_padoen_o,                    -- i2c clock line output enable, active low
    sda_pad_i     => sda_pad_i,                    -- i2c data line input
    sda_pad_o     => sda_pad_o,                    -- i2c data line output
    sda_padoen_o  => sda_padoen_o                     -- i2c data line output enable, active low

  );
  slot_read(13)(31 downto 8)<=(others => '0');

  i2c_buf0: entity work.IOBUF port map(I => scl_pad_o, O => scl_pad_i, T => scl_padoen_o, IO => I2C_SCLK );
  i2c_buf1: entity work.IOBUF port map(I => sda_pad_o, O => sda_pad_i, T => sda_padoen_o, IO => I2C_SDAT );




  --
  -- IO SLOT 14
  --

  slot14: zpuino_empty_device
  port map (
    wb_clk_i      => wb_clk_i,
	 	wb_rst_i      => wb_rst_i,
    wb_dat_o      => slot_read(14),
    wb_dat_i      => slot_write(14),
    wb_adr_i      => slot_address(14),
    wb_we_i       => slot_we(14),
    wb_cyc_i      => slot_cyc(14),
    wb_stb_i      => slot_stb(14),
    wb_ack_o      => slot_ack(14),
    wb_inta_o     => slot_interrupt(14),
    id            => slot_ids(14)
  );

  --
  -- IO SLOT 15 - do not use
  --

  process(gpio_spp_read, spi_pf_mosi, spi_pf_sck,
          sigmadelta_spp_data,timers_pwm,
          spi2_mosi,spi2_sck)
  begin

    gpio_spp_data <= (others => DontCareValue);

    -- PPS Outputs
    gpio_spp_data(0)  <= sigmadelta_spp_data(0);   -- PPS0 : SIGMADELTA DATA
    ppsout_info_slot(0) <= 5; -- Slot 5
    ppsout_info_pin(0) <= 0;  -- PPS OUT pin 0 (Channel 0)

    gpio_spp_data(1)  <= timers_pwm(0);            -- PPS1 : TIMER0
    ppsout_info_slot(1) <= 3; -- Slot 3
    ppsout_info_pin(1) <= 0;  -- PPS OUT pin 0 (TIMER 0)

    gpio_spp_data(2)  <= timers_pwm(1);            -- PPS2 : TIMER1
    ppsout_info_slot(2) <= 3; -- Slot 3
    ppsout_info_pin(2) <= 1;  -- PPS OUT pin 1 (TIMER 0)

    gpio_spp_data(3)  <= spi2_mosi;                -- PPS3 : USPI MOSI
    ppsout_info_slot(3) <= 6; -- Slot 6
    ppsout_info_pin(3) <= 0;  -- PPS OUT pin 0 (MOSI)

    gpio_spp_data(4)  <= spi2_sck;                 -- PPS4 : USPI SCK
    ppsout_info_slot(4) <= 6; -- Slot 6
    ppsout_info_pin(4) <= 1;  -- PPS OUT pin 1 (SCK)

    gpio_spp_data(5)  <= sigmadelta_spp_data(1);   -- PPS5 : SIGMADELTA1 DATA
    ppsout_info_slot(5) <= 5; -- Slot 5
    ppsout_info_pin(5) <= 1;  -- PPS OUT pin 0 (Channel 1)

    gpio_spp_data(6)  <= uart2_tx;   -- PPS6 : UART2 TX
    ppsout_info_slot(6) <= 8; -- Slot 8
    ppsout_info_pin(6) <= 0;  -- PPS OUT pin 0 (Channel 1)

    -- PPS inputs
    spi2_miso         <= gpio_spp_read(0);         -- PPS0 : USPI MISO
    ppsin_info_slot(0) <= 6;                    -- USPI is in slot 6
    ppsin_info_pin(0) <= 0;                     -- PPS pin of USPI is 0

    uart2_rx          <= gpio_spp_read(1);         -- PPS1 : UART2 RX
    ppsin_info_slot(1) <= 8;                    -- USPI is in slot 6
    ppsin_info_pin(1) <= 0;                     -- PPS pin of USPI is 0

  end process;


end behave;
