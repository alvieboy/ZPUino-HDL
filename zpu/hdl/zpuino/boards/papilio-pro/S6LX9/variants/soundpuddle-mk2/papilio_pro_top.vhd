--
--
--  ZPUINO implementation on Gadget Factory 'Papilio Pro' Board
-- 
--  Copyright 2011 Alvaro Lopes <alvieboy@alvie.com>
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
use work.wishbonepkg.all;

entity papilio_pro_top is
  port (
    CLK:        in std_logic;

    -- Connection to the main SPI flash
    SPI_SCK:    out std_logic;
    SPI_MISO:   in std_logic;
    SPI_MOSI:   out std_logic;
    SPI_CS:     out std_logic;

    -- WING connections
    WING_A:     inout std_logic_vector(15 downto 0);
    WING_B:     inout std_logic_vector(15 downto 0);
    WING_C:     inout std_logic_vector(15 downto 0);

    -- UART (FTDI) connection
    TXD:        out std_logic;
    RXD:        in std_logic;

    DRAM_ADDR   : OUT   STD_LOGIC_VECTOR (12 downto 0);
     DRAM_BA      : OUT   STD_LOGIC_VECTOR (1 downto 0);
     DRAM_CAS_N   : OUT   STD_LOGIC;
     DRAM_CKE      : OUT   STD_LOGIC;
     DRAM_CLK      : OUT   STD_LOGIC;
     DRAM_CS_N   : OUT   STD_LOGIC;
     DRAM_DQ      : INOUT STD_LOGIC_VECTOR(15 downto 0);
     DRAM_DQM      : OUT   STD_LOGIC_VECTOR(1 downto 0);
     DRAM_RAS_N   : OUT   STD_LOGIC;
     DRAM_WE_N    : OUT   STD_LOGIC;

    -- The LED
    LED:        out std_logic
  );
end entity papilio_pro_top;

architecture behave of papilio_pro_top is

  component zpuino_debug_jtag_spartan6 is
  port (
    jtag_data_chain_in: in std_logic_vector(98 downto 0);
    jtag_ctrl_chain_out: out std_logic_vector(11 downto 0)
  );
  end component;

  signal jtag_data_chain_in: std_logic_vector(98 downto 0);
  signal jtag_ctrl_chain_out: std_logic_vector(11 downto 0);

  component clkgen is
  port (
    clkin:  in std_logic;
    rstin:  in std_logic;
    clkout: out std_logic;
    clkout1: out std_logic;
    clkout2: out std_logic;
    rstout: out std_logic
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
    "00" &                -- SPI CS and LED
    "1111111111111111" &  -- Wing C
    "0000000000000000" &  -- Wing B
    "1111111111111111";   -- Wing A

  constant spp_cap_out: std_logic_vector(zpuino_gpio_count-1 downto 0) :=
    "00" &                -- SPI CS and LED
    "1111111111111111" &  -- Wing C
    "0000000000000000" &  -- Wing B
    "1111111111111111";   -- Wing A

  -- I/O Signals
  signal slot_cyc:    slot_std_logic_type;
  signal slot_we:     slot_std_logic_type;
  signal slot_stb:    slot_std_logic_type;
  signal slot_read:   slot_cpuword_type;
  signal slot_write:  slot_cpuword_type;
  signal slot_address:slot_address_type;
  signal slot_ack:    slot_std_logic_type;
  signal slot_interrupt: slot_std_logic_type;

  -- 2nd SPI signals
  signal spi2_mosi:   std_logic;
  signal spi2_miso:   std_logic;
  signal spi2_sck:    std_logic;

  -- GPIO Periperal Pin Select
  signal gpio_spp_data: std_logic_vector(zpuino_gpio_count-1 downto 0);
  signal gpio_spp_read: std_logic_vector(zpuino_gpio_count-1 downto 0);

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

  component sdram_ctrl is
  port (
    wb_clk_i: in std_logic;
	 	wb_rst_i: in std_logic;

    wb_dat_o: out std_logic_vector(31 downto 0);
    wb_dat_i: in std_logic_vector(31 downto 0);
    wb_adr_i: in std_logic_vector(maxIOBit downto minIOBit);
    wb_we_i:  in std_logic;
    wb_cyc_i: in std_logic;
    wb_stb_i: in std_logic;
    wb_sel_i: in std_logic_vector(3 downto 0);
    wb_ack_o: out std_logic;
    wb_stall_o: out std_logic;

    -- extra clocking
    clk_off_3ns: in std_logic;

    -- SDRAM signals
     DRAM_ADDR   : OUT   STD_LOGIC_VECTOR (11 downto 0);
     DRAM_BA      : OUT   STD_LOGIC_VECTOR (1 downto 0);
     DRAM_CAS_N   : OUT   STD_LOGIC;
     DRAM_CKE      : OUT   STD_LOGIC;
     DRAM_CLK      : OUT   STD_LOGIC;
     DRAM_CS_N   : OUT   STD_LOGIC;
     DRAM_DQ      : INOUT STD_LOGIC_VECTOR(15 downto 0);
     DRAM_DQM      : OUT   STD_LOGIC_VECTOR(1 downto 0);
     DRAM_RAS_N   : OUT   STD_LOGIC;
     DRAM_WE_N    : OUT   STD_LOGIC
  
  );
  end component sdram_ctrl;

  component i2c_master_top is
    generic(
            ARST_LVL : std_logic := '0'                   -- asynchronous reset level
    );
    port   (
            -- wishbone signals
            wb_clk_i      : in  std_logic;                    -- master clock input
            wb_rst_i      : in  std_logic := '0';             -- synchronous active high reset
            arst_i        : in  std_logic := not ARST_LVL;    -- asynchronous reset
            wb_adr_i      : in  std_logic_vector(2 downto 0); -- lower address bits
            wb_dat_i      : in  std_logic_vector(7 downto 0); -- Databus input
            wb_dat_o      : out std_logic_vector(7 downto 0); -- Databus output
            wb_we_i       : in  std_logic;                    -- Write enable input
            wb_stb_i      : in  std_logic;                    -- Strobe signals / core select signal
            wb_cyc_i      : in  std_logic;                    -- Valid bus cycle input
            wb_ack_o      : out std_logic;                    -- Bus cycle acknowledge output
            wb_inta_o     : out std_logic;                    -- interrupt request output signal

            -- i2c lines
            scl_pad_i     : in  std_logic;                    -- i2c clock line input
            scl_pad_o     : out std_logic;                    -- i2c clock line output
            scl_padoen_o  : out std_logic;                    -- i2c clock line output enable, active low
            sda_pad_i     : in  std_logic;                    -- i2c data line input
            sda_pad_o     : out std_logic;                    -- i2c data line output
            sda_padoen_o  : out std_logic                     -- i2c data line output enable, active low
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
  generic (
    spicount: integer := 10
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
    lmosi:     out std_logic_vector(spicount-1 downto 0);
    lsck:      out std_logic_vector(spicount-1 downto 0);

    -- SPI flash
    fmosi:      out std_logic;
    fmiso:      in std_logic;
    fsck:       out std_logic;
    fnsel:      out std_logic
  );
  end component;

  signal lmosi: std_logic_vector(11 downto 0);
  signal lsck: std_logic_vector(11 downto 0);

  signal extspi_fmosi:      std_logic;
  signal extspi_fmiso:      std_logic;
  signal extspi_fsck:       std_logic;
  signal extspi_fnsel:      std_logic;

  signal   m_wb_dat_i:  std_logic_vector(wordSize-1 downto 0);
  signal   m_wb_dat_o:  std_logic_vector(wordSize-1 downto 0);
  signal   m_wb_adr_i:  std_logic_vector(maxAddrBitIncIO downto 0);
  signal   m_wb_sel_i:  std_logic_vector(3 downto 0);
  signal   m_wb_cti_i:  std_logic_vector(2 downto 0);
  signal   m_wb_we_i:   std_logic;
  signal   m_wb_cyc_i:  std_logic;
  signal   m_wb_stb_i:  std_logic;
  signal   m_wb_ack_o:  std_logic;

  -- Pipelined signals
  signal   p_m_wb_dat_i:  std_logic_vector(wordSize-1 downto 0);
  signal   p_m_wb_dat_o:  std_logic_vector(wordSize-1 downto 0);
  signal   p_m_wb_adr_i:  std_logic_vector(maxAddrBitIncIO downto 0);
  signal   p_m_wb_sel_i:  std_logic_vector(3 downto 0);
  signal   p_m_wb_cti_i:  std_logic_vector(2 downto 0);
  signal   p_m_wb_we_i:   std_logic;
  signal   p_m_wb_cyc_i:  std_logic;
  signal   p_m_wb_stb_i:  std_logic;
  signal   p_m_wb_ack_o:  std_logic;
  signal   p_m_wb_stall_o:  std_logic;

  signal bt_miso, bt_mosi, bt_clk: std_logic;
  signal bt_cs, codec_cs: std_logic;

  signal scl_pad_i, scl_pad_o, scl_padoen_o: std_logic;
  signal sda_pad_i, sda_pad_o, sda_padoen_o: std_logic;

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

  clkgen_inst: clkgen
  port map (
    clkin   => clk,
    rstin   => '0'  ,
    clkout  => sysclk,
    clkout1  => sysclk_sram_we,
    clkout2  => sysclk_sram_wen,
    rstout  => clkgen_rst
  );

  pin00: OPAD port map(I => lmosi(2),  PAD => WING_A(0) );
  pin01: OPAD port map(I => lsck(2), PAD => WING_A(1) );
  pin02: OPAD port map(I => lsck(3),  PAD => WING_A(2) );
  pin03: OPAD port map(I => lmosi(3), PAD => WING_A(3) );
  pin04: OPAD port map(I => lmosi(4),  PAD => WING_A(4) );
  pin05: OPAD port map(I => lsck(4), PAD => WING_A(5) );
  pin06: OPAD port map(I => lmosi(5),  PAD => WING_A(6) );
  pin07: OPAD port map(I => lsck(5), PAD => WING_A(7) );


  pin08: OPAD port map(I => lsck(6),  PAD => WING_A(8) );
  pin09: OPAD port map(I => lmosi(6), PAD => WING_A(9) );
  pin10: OPAD port map(I => lsck(7),  PAD => WING_A(10) );
  pin11: OPAD port map(I => lmosi(7), PAD => WING_A(11) );

  pin12: OPAD port map(I => lmosi(8), PAD => WING_A(12) );
  pin13: OPAD port map(I => lsck(9),  PAD => WING_A(13) );
  pin14: OPAD port map(I => lsck(10), PAD => WING_A(14) );
  pin15: OPAD port map(I => lsck(11), PAD => WING_A(15) );

  pin16: OPAD port map(I => lmosi(11),PAD => WING_B(0) );
  pin17: OPAD port map(I => lmosi(10),PAD => WING_B(1) );
  pin18: OPAD port map(I => lmosi(9), PAD => WING_B(2) );
  pin19: OPAD port map(I => lsck(8),  PAD => WING_B(3) );


  pin20: IOPAD port map(I => gpio_o(20),O => gpio_i(20),T => gpio_t(20),C => sysclk,PAD => WING_B(4) ); -- Midi IN
  pin21: OPAD port map(I => gpio_o(21),O => gpio_i(21),PAD => WING_B(5) ); -- Flash CS
  pin22: IPAD port map(O => bt_miso, C => sysclk, PAD => WING_B(6) ); -- BT MISO
  pin23: OPAD port map(I => gpio_o(23), O => gpio_i(23), PAD => WING_B(7) ); -- BT CS
  pin24: OPAD port map(I => bt_clk, PAD => WING_B(8) ); -- BT CLK
  pin25: OPAD port map(I => bt_mosi, PAD => WING_B(9) ); -- BT MOSI
  pin26: OPAD port map(I => gpio_o(26), O => gpio_i(26), PAD => WING_B(10) ); -- BT RESET

  pin27: OPAD port map(I => gpio_o(27), O => gpio_i(27), PAD => WING_B(11) );
  pin28: OPAD port map(I => lmosi(0),  PAD => WING_B(12) );
  pin29: OPAD port map(I => lsck(0), PAD => WING_B(13) );
  pin30: OPAD port map(I => lmosi(1),  PAD => WING_B(14) );
  pin31: OPAD port map(I => lsck(1), PAD => WING_B(15) ); -- up to here, all OK


  pin32: IOPAD port map(I => gpio_o(32),O => gpio_i(32),T => gpio_t(32),C => sysclk,PAD => WING_C(0) );  -- ADC DIN
  pin33: IOPAD port map(I => gpio_o(33),O => gpio_i(33),T => gpio_t(33),C => sysclk,PAD => WING_C(1) );  -- ADC DOUT
  pin34: IOPAD port map(I => gpio_o(34),O => gpio_i(34),T => gpio_t(34),C => sysclk,PAD => WING_C(2) );  -- ADC CLK
  pin35: IOPAD port map(I => gpio_o(35),O => gpio_i(35),T => gpio_t(35),C => sysclk,PAD => WING_C(3) );  -- ADC CS
  pin36: IOPAD port map(I => gpio_o(36),O => gpio_i(36),T => gpio_t(36),C => sysclk,PAD => WING_C(4) );
  pin37: IOPAD port map(I => gpio_o(37),O => gpio_i(37),T => gpio_t(37),C => sysclk,PAD => WING_C(5) );
  pin38: IOPAD port map(I => gpio_o(38),O => gpio_i(38),T => gpio_t(38),C => sysclk,PAD => WING_C(6) );
  pin39: IOPAD port map(I => gpio_o(39),O => gpio_i(39),T => gpio_t(39),C => sysclk,PAD => WING_C(7) );

  pin40: IOPAD port map(I => gpio_o(40),O => gpio_i(40),T => gpio_t(40),C => sysclk,PAD => WING_C(8) ); -- CODEC WCLK
  pin41: IOPAD port map(I => gpio_o(41),O => gpio_i(41),T => gpio_t(41),C => sysclk,PAD => WING_C(9) ); -- CODEC DIN
  pin42: IOPAD port map(I => gpio_o(42),O => gpio_i(42),T => gpio_t(42),C => sysclk,PAD => WING_C(10) ); -- CODEC MOSI
  pin43: IOPAD port map(I => gpio_o(43),O => gpio_i(43),T => gpio_t(43),C => sysclk,PAD => WING_C(11) ); -- CODEC MISO
  pin44: IOPAD port map(I => gpio_o(44),O => gpio_i(44),T => gpio_t(44),C => sysclk,PAD => WING_C(12) ); -- CODEC SCLK
  pin45: IOPAD port map(I => gpio_o(45),O => gpio_i(45),T => gpio_t(45),C => sysclk,PAD => WING_C(13) ); -- CODEC DOUT

  pin46: IOPAD port map(I => scl_pad_o, O => scl_pad_i,T => scl_padoen_o,C => sysclk,PAD => WING_C(14) );
  pin47: IOPAD port map(I => sda_pad_o, O => sda_pad_i,T => sda_padoen_o,C => sysclk,PAD => WING_C(15) );
  -- These two pins are mapped to I2C.

  -- Other ports are special, we need to avoid outputs on input-only pins

  ibufrx:   IPAD port map ( PAD => RXD,        O => rx,           C => sysclk );
  ibufmiso: IPAD port map ( PAD => SPI_MISO,   O => spi_pf_miso,  C => sysclk );

  obuftx:   OPAD port map ( I => tx,           PAD => TXD );
  ospiclk:  OPAD port map ( I => spi_pf_sck,   PAD => SPI_SCK );
  ospics:   OPAD port map ( I => gpio_o(48),   PAD => SPI_CS );
  ospimosi: OPAD port map ( I => spi_pf_mosi,  PAD => SPI_MOSI );
  oled:     OPAD port map ( I => gpio_o(49),   PAD => LED );

  zpuino:zpuino_top_icache
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
      --m_wb_stall_o  => p_m_wb_stall_o,

      memory_enable => memory_enable,

      ram_wb_ack_i      => np_ram_wb_ack_o,
      --ram_wb_stall_i    => np_ram_wb_stall_o,
      ram_wb_dat_o      => np_ram_wb_dat_i,
      ram_wb_dat_i      => np_ram_wb_dat_o,
      ram_wb_adr_o      => np_ram_wb_adr_i(maxAddrBit downto 0),
      ram_wb_cyc_o      => np_ram_wb_cyc_i,
      ram_wb_stb_o      => np_ram_wb_stb_i,
      ram_wb_sel_o      => np_ram_wb_sel_i,
      ram_wb_we_o       => np_ram_wb_we_i,

      rom_wb_ack_i      => rom_wb_ack_o,
      rom_wb_stall_i    => rom_wb_stall_o,
      rom_wb_dat_i      => rom_wb_dat_o,
      rom_wb_adr_o      => rom_wb_adr_i(maxAddrBit downto 0),
      rom_wb_cyc_o      => rom_wb_cyc_i,
      rom_wb_stb_o      => rom_wb_stb_i,


      -- No debug unit connected
      dbg_reset     => open,
      jtag_data_chain_out => open,            --jtag_data_chain_in,
      jtag_ctrl_chain_in  => (others => '0') --jtag_ctrl_chain_out
      );

  --dbg: zpuino_debug_jtag_spartan6
  --  port map (
  --    jtag_data_chain_in    => jtag_data_chain_in,
  --    jtag_ctrl_chain_out   => jtag_ctrl_chain_out
  --  );

  memarb: wbarb2_1
  generic map (
    ADDRESS_HIGH => maxAddrBit,
    ADDRESS_LOW => 2
  )
  port map (
    wb_clk_i      => wb_clk_i,
    wb_rst_i      => wb_rst_i,

    m0_wb_dat_o   => ram_wb_dat_o,
    m0_wb_dat_i   => ram_wb_dat_i,
    m0_wb_adr_i   => ram_wb_adr_i(maxAddrBit downto 2),
    m0_wb_sel_i   => ram_wb_sel_i,
    m0_wb_cti_i   => CTI_CYCLE_CLASSIC,
    m0_wb_we_i    => ram_wb_we_i,
    m0_wb_cyc_i   => ram_wb_cyc_i,
    m0_wb_stb_i   => ram_wb_stb_i,
    m0_wb_ack_o   => ram_wb_ack_o,
    m0_wb_stall_o => ram_wb_stall_o,

    m1_wb_dat_o   => sram_rom_wb_dat_o,
    m1_wb_dat_i   => (others => DontCareValue),
    m1_wb_adr_i   => sram_rom_wb_adr_i(maxAddrBit downto 2),
    m1_wb_sel_i   => (others => '1'),
    m1_wb_cti_i   => CTI_CYCLE_CLASSIC,
    m1_wb_we_i    => '0',--rom_wb_we_i,
    m1_wb_cyc_i   => sram_rom_wb_cyc_i,
    m1_wb_stb_i   => sram_rom_wb_stb_i,
    m1_wb_ack_o   => sram_rom_wb_ack_o,
    m1_wb_stall_o => sram_rom_wb_stall_o,

    s0_wb_dat_i   => sram_wb_dat_o,
    s0_wb_dat_o   => sram_wb_dat_i,
    s0_wb_adr_o   => sram_wb_adr_i(maxAddrBit downto 2),
    s0_wb_sel_o   => sram_wb_sel_i,
    s0_wb_cti_o   => open,
    s0_wb_we_o    => sram_wb_we_i,
    s0_wb_cyc_o   => sram_wb_cyc_i,
    s0_wb_stb_o   => sram_wb_stb_i,
    s0_wb_ack_i   => sram_wb_ack_o,
    s0_wb_stall_i => sram_wb_stall_o
  );

  bootmux: wbbootloadermux
  generic map (
    address_high  => maxAddrBit
  )
  port map (
    wb_clk_i      => wb_clk_i,
	 	wb_rst_i      => wb_rst_i,

    sel           => memory_enable,

    -- Master 

    m_wb_dat_o    => rom_wb_dat_o,
    m_wb_dat_i    => (others => DontCareValue),
    m_wb_adr_i    => rom_wb_adr_i(maxAddrBit downto 2),
    m_wb_sel_i    => (others => '1'),
    m_wb_cti_i    => CTI_CYCLE_CLASSIC,
    m_wb_we_i     => '0',
    m_wb_cyc_i    => rom_wb_cyc_i,
    m_wb_stb_i    => rom_wb_stb_i,
    m_wb_ack_o    => rom_wb_ack_o,
    m_wb_stall_o  => rom_wb_stall_o,

    -- Slave 0 signals

    s0_wb_dat_i   => sram_rom_wb_dat_o,
    s0_wb_dat_o   => open,
    s0_wb_adr_o   => sram_rom_wb_adr_i,
    s0_wb_sel_o   => open,
    s0_wb_cti_o   => open,
    s0_wb_we_o    => open,
    s0_wb_cyc_o   => sram_rom_wb_cyc_i,
    s0_wb_stb_o   => sram_rom_wb_stb_i,
    s0_wb_ack_i   => sram_rom_wb_ack_o,
    s0_wb_stall_i => sram_rom_wb_stall_o,

    -- Slave 1 signals

    s1_wb_dat_i   => prom_rom_wb_dat_o,
    s1_wb_dat_o   => open,
    s1_wb_adr_o   => prom_rom_wb_adr_i(11 downto 2),
    s1_wb_sel_o   => open,
    s1_wb_cti_o   => open,
    s1_wb_we_o    => open,
    s1_wb_cyc_o   => prom_rom_wb_cyc_i,
    s1_wb_stb_o   => prom_rom_wb_stb_i,
    s1_wb_ack_i   => prom_rom_wb_ack_o,
    s1_wb_stall_i => prom_rom_wb_stall_o

  );

  npnadapt: wb_master_np_to_slave_p
  generic map (
    ADDRESS_HIGH  => maxAddrBitIncIO,
    ADDRESS_LOW   => 0
  )
  port map (
    wb_clk_i    => wb_clk_i,
	 	wb_rst_i    => wb_rst_i,

    -- Master signals

    m_wb_dat_o  => np_ram_wb_dat_o,
    m_wb_dat_i  => np_ram_wb_dat_i,
    m_wb_adr_i  => np_ram_wb_adr_i,
    m_wb_sel_i  => np_ram_wb_sel_i,
    m_wb_cti_i  => CTI_CYCLE_CLASSIC,
    m_wb_we_i   => np_ram_wb_we_i,
    m_wb_cyc_i  => np_ram_wb_cyc_i,
    m_wb_stb_i  => np_ram_wb_stb_i,
    m_wb_ack_o  => np_ram_wb_ack_o,

    -- Slave signals

    s_wb_dat_i  => ram_wb_dat_o,
    s_wb_dat_o  => ram_wb_dat_i,
    s_wb_adr_o  => ram_wb_adr_i,
    s_wb_sel_o  => ram_wb_sel_i,
    s_wb_cti_o  => open,
    s_wb_we_o   => ram_wb_we_i,
    s_wb_cyc_o  => ram_wb_cyc_i,
    s_wb_stb_o  => ram_wb_stb_i,
    s_wb_ack_i  => ram_wb_ack_o,
    s_wb_stall_i => ram_wb_stall_o
  );


  -- PROM

  prom: wb_bootloader
    port map (
      wb_clk_i    => wb_clk_i,
      wb_rst_i    => wb_rst_i,

      wb_dat_o    => prom_rom_wb_dat_o,
      wb_adr_i    => prom_rom_wb_adr_i(11 downto 2),
      wb_cyc_i    => prom_rom_wb_cyc_i,
      wb_stb_i    => prom_rom_wb_stb_i,
      wb_ack_o    => prom_rom_wb_ack_o,
      wb_stall_o  => prom_rom_wb_stall_o,

      wb2_dat_o    => slot_read(15),
      wb2_adr_i    => slot_address(15)(11 downto 2),
      wb2_cyc_i    => slot_cyc(15),
      wb2_stb_i    => slot_stb(15),
      wb2_ack_o    => slot_ack(15),
      wb2_stall_o  => open
    );



  --
  -- IO SLOT 0
  --

  slot0: zpuino_spi
  port map (
    wb_clk_i      => wb_clk_i,
	 	wb_rst_i      => wb_rst_i,
    wb_dat_o      => slot_read(0),
    wb_dat_i      => slot_write(0),
    wb_adr_i      => slot_address(0),
    wb_we_i       => slot_we(0),
    wb_cyc_i      => slot_cyc(0),
    wb_stb_i      => slot_stb(0),
    wb_ack_o      => slot_ack(0),
    wb_inta_o     => slot_interrupt(0),

    mosi          => spi_pf_mosi,
    miso          => spi_pf_miso,
    sck           => spi_pf_sck,
    enabled       => open
  );

  --
  -- IO SLOT 1
  --

  uart_inst: zpuino_uart
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
    A_WIDTH             => 16,
    A_PRESCALER_ENABLED => true,
    A_BUFFERS           => true,
    B_TSCENABLED        => false,
    B_PWMCOUNT          => 1,
    B_WIDTH             => 8,--24,
    B_PRESCALER_ENABLED => false,
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

    wb_inta_o     => slot_interrupt(3), -- We use two interrupt lines
    wb_intb_o     => slot_interrupt(4), -- so we borrow intr line from slot 4

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
    wb_inta_o     => slot_interrupt(7)
  );

  --
  -- IO SLOT 8
  --

  slot8: zpuino_spi
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
    mosi          => bt_mosi,
    miso          => bt_miso,
    sck           => bt_clk
  );

  sram_inst: sdram_ctrl
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
      --wb_cti_i    => CTI_CYCLE_CLASSIC,
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
    wb_inta_o     => slot_interrupt(9)
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
    wb_inta_o     => slot_interrupt(10)
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
    wb_inta_o     => slot_interrupt(11)
  );

  --
  -- IO SLOT 12
  --

  slot12: i2c_master_top
    port map (
            -- wishbone signals
      wb_clk_i      => wb_clk_i,
      wb_rst_i      => wb_rst_i,
      wb_adr_i      => slot_address(12)(4 downto 2),
      wb_dat_i      => slot_write(12)(7 downto 0),

      wb_dat_o      => slot_read(12)(7 downto 0),
      wb_we_i       => slot_we(12),
      wb_stb_i      => slot_stb(12),
      wb_cyc_i      => slot_cyc(12),
      wb_ack_o      => slot_ack(12),
      wb_inta_o     => slot_interrupt(12),

      scl_pad_i     => scl_pad_i,
      scl_pad_o     => scl_pad_o,
      scl_padoen_o  => scl_padoen_o,

      sda_pad_i     => sda_pad_i,
      sda_pad_o     => sda_pad_o,
      sda_padoen_o  => sda_padoen_o
    );

  --
  -- IO SLOT 13
  --

  slot13: zpuino_empty_device
  port map (
    wb_clk_i      => wb_clk_i,
	 	wb_rst_i      => wb_rst_i,
    wb_dat_o      => slot_read(13),
    wb_dat_i      => slot_write(13),
    wb_adr_i      => slot_address(13),
    wb_we_i       => slot_we(13),
    wb_cyc_i      => slot_cyc(13),
    wb_stb_i      => slot_stb(13),
    wb_ack_o      => slot_ack(13),
    wb_inta_o     => slot_interrupt(13)
  );

  --
  -- IO SLOT 14
  --

--  npnadapt_spi: wb_master_np_to_slave_p
--  generic map (
--    ADDRESS_HIGH  => maxAddrBitIncIO,
--    ADDRESS_LOW   => 0
--  )
--  port map (
--    wb_clk_i    => wb_clk_i,
--	 	wb_rst_i    => wb_rst_i,
--
--    -- Master signals
--
--    m_wb_dat_o  => m_wb_dat_o,
--    m_wb_dat_i  => m_wb_dat_i,
--    m_wb_adr_i  => m_wb_adr_i,
--    m_wb_sel_i  => m_wb_sel_i,
--    m_wb_cti_i  => CTI_CYCLE_CLASSIC,
--    m_wb_we_i   => m_wb_we_i,
--    m_wb_cyc_i  => m_wb_cyc_i,
--    m_wb_stb_i  => m_wb_stb_i,
--    m_wb_ack_o  => m_wb_ack_o,
--
--    -- Slave signals
--
--    s_wb_dat_i  => p_m_wb_dat_o,
--    s_wb_dat_o  => p_m_wb_dat_i,
--    s_wb_adr_o  => p_m_wb_adr_i,
--    s_wb_sel_o  => p_m_wb_sel_i,
--    s_wb_cti_o  => open,
--    s_wb_we_o   => p_m_wb_we_i,
--    s_wb_cyc_o  => p_m_wb_cyc_i,
--   s_wb_stb_o  => p_m_wb_stb_i,
--    s_wb_ack_i  => p_m_wb_ack_o,
--    s_wb_stall_i => p_m_wb_stall_o
--  );


  slot14: multispi
  generic map (
    spicount => 12
  )
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
  -- IO SLOT 15 - do not use
  --

  process(gpio_spp_read, spi_pf_mosi, spi_pf_sck,
          sigmadelta_spp_data,timers_pwm,
          spi2_mosi,spi2_sck)
  begin

    gpio_spp_data <= (others => DontCareValue);

    -- PPS Outputs
    gpio_spp_data(0)  <= sigmadelta_spp_data(0);   -- PPS0 : SIGMADELTA DATA
    gpio_spp_data(1)  <= timers_pwm(0);            -- PPS1 : TIMER0
    gpio_spp_data(2)  <= timers_pwm(1);            -- PPS2 : TIMER1
    gpio_spp_data(3)  <= spi2_mosi;                -- PPS3 : USPI MOSI
    gpio_spp_data(4)  <= spi2_sck;                 -- PPS4 : USPI SCK
    gpio_spp_data(5)  <= sigmadelta_spp_data(1);   -- PPS5 : SIGMADELTA1 DATA

    -- PPS inputs
    spi2_miso         <= gpio_spp_read(0);         -- PPS0 : USPI MISO

  end process;


end behave;
