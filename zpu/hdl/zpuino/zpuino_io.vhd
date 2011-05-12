--
--  IO dispatcher for ZPUINO
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
use work.zpuino_config.all;
use work.zpupkg.all;
use work.zpuinopkg.all;

entity zpuino_io is
  generic (
    spp_cap_in:  in std_logic_vector(zpuino_gpio_count-1 downto 0); -- SPP capable pin for INPUT
    spp_cap_out:  in std_logic_vector(zpuino_gpio_count-1 downto 0) -- SPP capable pin for OUTPUT
  );
  port (
    wb_clk_i:   in std_logic;
	 	wb_rst_i:   in std_logic;
    wb_dat_o:   out std_logic_vector(wordSize-1 downto 0);
    wb_dat_i:   in std_logic_vector(wordSize-1 downto 0);
    wb_adr_i:   in std_logic_vector(maxAddrBitIncIO downto 0);
    wb_we_i:    in std_logic;
    wb_cyc_i:   in std_logic;
    wb_stb_i:   in std_logic;
    wb_ack_o:   out std_logic;
    wb_inta_o:  out std_logic;

    intready:   in std_logic;

    -- GPIO
    gpio_o:         out std_logic_vector(zpuino_gpio_count-1 downto 0);
    gpio_t:         out std_logic_vector(zpuino_gpio_count-1 downto 0);
    gpio_i:         in std_logic_vector(zpuino_gpio_count-1 downto 0);

    tx: out std_logic;
    rx: in std_logic
  );
end entity zpuino_io;

architecture behave of zpuino_io is

  constant io_registered_read: boolean := true;

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
  signal timers_spp_data: std_logic_vector(1 downto 0);
  signal timers_spp_en: std_logic_vector(1 downto 0);
  signal timers_comp: std_logic;

  signal ivecs: std_logic_vector(17 downto 0);

  signal sigmadelta_spp_en:  std_logic_vector(1 downto 0);
  signal sigmadelta_spp_data:  std_logic_vector(1 downto 0);

  -- For busy-implementation
  signal addr_save_q: std_logic_vector(maxAddrBitIncIO downto 0);
  signal write_save_q: std_logic_vector(wordSize-1 downto 0);

  signal io_address: std_logic_vector(maxAddrBitIncIO downto 0);
  signal io_write: std_logic_vector(wordSize-1 downto 0);
  signal io_cyc: std_logic;
  signal io_stb: std_logic;
  signal io_we: std_logic;

  signal io_device_ack: std_logic;

  signal spi_pf_miso: std_logic;
  signal spi_pf_mosi: std_logic;
  signal spi_pf_sck: std_logic;
  signal uart_tx: std_logic;
  signal uart_rx: std_logic;

  signal adc_mosi:  std_logic;
  signal adc_miso:  std_logic;
  signal adc_sck:   std_logic;
  signal adc_seln:  std_logic;
  signal adc_enabled: std_logic;


  type slot_std_logic_type is array(0 to 15) of std_logic;
  subtype cpuword_type     is std_logic_vector(31 downto 0);
  type slot_cpuword_type   is array(0 to 15) of cpuword_type;
  subtype address_type     is std_logic_vector(10 downto 2);
  type slot_address_type   is array(0 to 15) of address_type;

  signal io_read_selected: cpuword_type;

  signal slot_cyc:       slot_std_logic_type;
  signal slot_we:        slot_std_logic_type;
  signal slot_stb:       slot_std_logic_type;

  signal slot_read:     slot_cpuword_type;
  signal slot_write:    slot_cpuword_type;
  signal slot_address:  slot_address_type;

  signal slot_ack:     slot_std_logic_type;
  signal slot_interrupt:slot_std_logic_type;


  signal wb_in_transaction: std_logic;
begin

  -- Ack generator

  process(slot_ack)
  begin
    io_device_ack <= '0';
    for i in 0 to 15 loop
      if slot_ack(i) = '1' then
        io_device_ack<='1';
      end if;
    end loop;
  end process;

  iobusy: if zpuino_iobusyinput=true generate
    process(wb_clk_i)
    begin
      if rising_edge(wb_clk_i) then
        if wb_rst_i='1' then
          wb_in_transaction <= '0';
        else

          if wb_in_transaction='0' then
            io_cyc <= wb_cyc_i;
            io_stb <= wb_stb_i;
            io_we <= wb_we_i;
          elsif io_device_ack='1' then
            io_stb<='0';
            io_we<='0'; -- safe side
            -- How to keep cyc ????
          end if;

          if wb_cyc_i='1' then
            wb_in_transaction<='1';
          else
            io_cyc <= '0';
            wb_in_transaction<='0';
          end if;

          if wb_stb_i='1' and wb_cyc_i='1' then
            addr_save_q <= wb_adr_i;
          end if;
          if wb_we_i='1' then
            write_save_q <= wb_dat_i;
          end if;
        end if;
      end if;
    end process;

    io_address <= addr_save_q;
    io_write <= write_save_q;

    rread: if io_registered_read=true generate
    -- Read/ack
    process(wb_clk_i)
    begin
      if rising_edge(wb_clk_i) then
        if wb_rst_i='1' then
          wb_ack_o<='0';
          wb_dat_o<=(others => DontCareValue);
        else
          wb_ack_o <= io_device_ack;
          wb_dat_o <= io_read_selected;
        end if;
      end if;
    end process;

    end generate;

    nrread: if io_registered_read=false generate

      process(io_device_ack)
      begin
        wb_ack_o <= io_device_ack;
      end process;

      process(io_read_selected)
      begin
        wb_dat_o <= io_read_selected;
      end process;

    end generate;

  end generate;

  noiobusy: if zpuino_iobusyinput=false generate
    -- TODO: remove this

    io_address <= wb_adr_i;
    io_write <= wb_dat_i;
    io_cyc <= wb_cyc_i;
    io_stb <= wb_stb_i;
    io_we <= wb_we_i;

    wb_ack_o <= io_device_ack;
  end generate;

  -- Interrupt vectors

  process(slot_interrupt)
  begin
    for i in 0 to 15 loop
      ivecs(i) <= slot_interrupt(i);
    end loop;
  end process;

  -- Write and address signals, shared by all slots
  process(wb_dat_i,wb_adr_i,io_write,io_address)
  begin
    for i in 0 to 15 loop
      slot_write(i) <= io_write;--wb_dat_i;
      slot_address(i) <= io_address(10 downto 2);--wb_adr_i(10 downto 2);
    end loop;
  end process;

  process(io_address,slot_read)
    variable slotNumber: integer range 0 to 15;
  begin

    slotNumber := to_integer(unsigned(io_address(14 downto 11)));
    io_read_selected <= slot_read(slotNumber);

  end process;

  -- Enable signals

  process(io_address,wb_stb_i,wb_cyc_i,wb_we_i,io_stb,io_cyc,io_we)
    variable slotNumber: integer range 0 to 15;
  begin

    slotNumber := to_integer(unsigned(io_address(14 downto 11)));

    for i in 0 to 15 loop
      if i = slotNumber then
        slot_stb(i) <= io_stb;-- and wb_stb_i;
        slot_cyc(i) <= io_cyc;-- and wb_cyc_i;
        slot_we(i) <= io_we;-- and wb_we_i;
      else
        slot_stb(i) <= '0';
        slot_cyc(i) <= '0';
        slot_we(i) <= '0';
      end if;
    end loop;

  end process;

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
    tx        => uart_tx,
    rx        => uart_rx
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

    spp_data  => timers_spp_data,
    spp_en    => timers_spp_en,
    comp      => timers_comp
  );

  --
  -- IO SLOT 4
  --

  intr_inst: zpuino_intr
  generic map (
    INTERRUPT_LINES =>  18
  )
  port map (
    wb_clk_i       => wb_clk_i,
	 	wb_rst_i    => wb_rst_i,
    wb_dat_o     => slot_read(4),
    wb_dat_i    => slot_write(4),
    wb_adr_i   => slot_address(4),
    wb_we_i        => slot_we(4),
    wb_cyc_i        => slot_cyc(4),
    wb_stb_i        => slot_stb(4),
    wb_ack_o      => slot_ack(4),
    wb_inta_o => wb_inta_o, -- Interrupt signal to core

    poppc_inst=> intready,
    intr_in     => ivecs,
    intr_cfglvl => "110000000000000000"
  );

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
    sync_in   => timers_comp
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
    enabled   => spi2_enabled
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

  adcgen: if zpuino_adc_enabled generate

  adc_inst:zpuino_adc
  port map (
    wb_clk_i       => wb_clk_i,
	 	wb_rst_i    => wb_rst_i,
    wb_dat_o      => slot_read(8),
    wb_dat_i     => slot_write(8),
    wb_adr_i   => slot_address(8),
    wb_we_i    => slot_we(8),
    wb_cyc_i      => slot_cyc(8),
    wb_stb_i      => slot_stb(8),
    wb_ack_o      => slot_ack(8),
    wb_inta_o => slot_interrupt(8),

    sample    => timers_comp,
    mosi      => adc_mosi,
    miso      => adc_miso,
    sck       => adc_sck,
    seln      => adc_seln,
    enabled   => adc_enabled
  );
  end generate;

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

  slot11: zpuino_empty_device
  port map (
    wb_clk_i       => wb_clk_i,
	 	wb_rst_i       => wb_rst_i,
    wb_dat_o      => slot_read(11),
    wb_dat_i     => slot_write(11),
    wb_adr_i   => slot_address(11),
    wb_we_i        => slot_we(11),
    wb_cyc_i        => slot_cyc(11),
    wb_stb_i        => slot_stb(11),
    wb_ack_o      => slot_ack(11),
    wb_inta_o => slot_interrupt(11)
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

  slot13: zpuino_empty_device
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

  slot14: zpuino_empty_device
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
    wb_inta_o => slot_interrupt(14)
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


  uart_rx <= rx;
  tx <= uart_tx;

  process(spi_enabled,spi2_enabled,spi_enabled,
          uart_enabled,sigmadelta_spp_en, uart_tx,
          gpio_spp_read, spi_pf_mosi, spi_pf_sck,
          sigmadelta_spp_data,timers_spp_data,
          spi2_mosi,spi2_sck,timers_spp_en)
  begin

    gpio_spp_data <= (others => DontCareValue);

    spi_pf_miso <= gpio_spp_read(0);            -- PPS1 : SPI MISO
    gpio_spp_data(1) <= spi_pf_mosi;            -- PPS2 : SPI MOSI
    gpio_spp_data(2) <= spi_pf_sck;             -- PPS3 : SPI SCK
    gpio_spp_data(3) <= sigmadelta_spp_data(0); -- PPS4 : SIGMADELTA DATA
    gpio_spp_data(4) <= timers_spp_data(0);     -- PPS5 : TIMER0
    gpio_spp_data(5) <= timers_spp_data(1);     -- PPS6 : TIMER1
    spi2_miso <= gpio_spp_read(6);              -- PPS7 : USPI MISO
    gpio_spp_data(7) <= spi2_mosi;              -- PPS8 : USPI MOSI
    gpio_spp_data(8) <= spi2_sck;               -- PPS9: USPI SCK
    if zpuino_adc_enabled then
      gpio_spp_data(9) <= adc_sck;           -- PPS10: ADC SCK
      adc_miso <= gpio_spp_read(10);          -- PPS11 : ADC MISO
      gpio_spp_data(11) <= adc_mosi;          -- PPS12 : ADC MOSI
      gpio_spp_data(12) <= adc_seln;          -- PPS13 : ADC SELN
    end if;
    gpio_spp_data(13) <= sigmadelta_spp_data(1); -- PPS14 : SIGMADELTA1 DATA

    -- External interrupt lines
    ivecs(16) <= gpio_spp_read(1);
    ivecs(17) <= gpio_spp_read(2);

  end process;

end behave;
