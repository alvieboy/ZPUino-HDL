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
  port (
    clk:      in std_logic;
	 	areset:   in std_logic;
    read:     out std_logic_vector(wordSize-1 downto 0);
    write:    in std_logic_vector(wordSize-1 downto 0);
    address:  in std_logic_vector(maxAddrBitIncIO downto 0);
    we:       in std_logic;
    re:       in std_logic;
    busy:     out std_logic;
    interrupt:out std_logic;
    intready: in std_logic;

    -- GPIO
    gpio_o:         out std_logic_vector(zpuino_gpio_count-1 downto 0);
    gpio_t:         out std_logic_vector(zpuino_gpio_count-1 downto 0);
    gpio_i:         in std_logic_vector(zpuino_gpio_count-1 downto 0)
  );
end entity zpuino_io;

architecture behave of zpuino_io is

  signal spi_read:     std_logic_vector(wordSize-1 downto 0);
  signal spi_re:  std_logic;
  signal spi_we:  std_logic;
  signal spi_busy:  std_logic;
  signal spi_enabled:  std_logic;

  signal spi2_read:     std_logic_vector(wordSize-1 downto 0);
  signal spi2_re:  std_logic;
  signal spi2_we:  std_logic;
  signal spi2_busy:  std_logic;
  signal spi2_enabled:  std_logic;
  signal spi2_mosi:  std_logic;
  signal spi2_miso:  std_logic;
  signal spi2_sck:  std_logic;

  signal uart_read:     std_logic_vector(wordSize-1 downto 0);
  signal uart_re:  std_logic;
  signal uart_we:  std_logic;
  signal uart_enabled:  std_logic;

  signal gpio_read:     std_logic_vector(wordSize-1 downto 0);
  signal gpio_re:  std_logic;
  signal gpio_we:  std_logic;
  signal gpio_spp_data: std_logic_vector(zpuino_gpio_count-1 downto 0);
  signal gpio_spp_read: std_logic_vector(zpuino_gpio_count-1 downto 0);
  signal gpio_spp_en: std_logic_vector(zpuino_gpio_count-1 downto 0);

  signal timers_read:     std_logic_vector(wordSize-1 downto 0);
  signal timers_re:  std_logic;
  signal timers_we:  std_logic;
  signal timers_interrupt:  std_logic_vector(1 downto 0);
  signal timers_spp_data: std_logic_vector(1 downto 0);
  signal timers_spp_en: std_logic_vector(1 downto 0);

  signal intr_read:     std_logic_vector(wordSize-1 downto 0);
  signal intr_re:  std_logic;
  signal intr_we:  std_logic;

  signal ivecs: std_logic_vector(15 downto 0);

  signal sigmadelta_read:     std_logic_vector(wordSize-1 downto 0);
  signal sigmadelta_re:  std_logic;
  signal sigmadelta_we:  std_logic;
  signal sigmadelta_spp_en:  std_logic;
  signal sigmadelta_spp_data:  std_logic;

  signal crc16_read:     std_logic_vector(wordSize-1 downto 0);
  signal crc16_re:  std_logic;
  signal crc16_we:  std_logic;
  signal crc16_busy:  std_logic;

  -- For busy-implementation
  signal addr_save_q: std_logic_vector(maxAddrBitIncIO downto 0);
  signal write_save_q: std_logic_vector(wordSize-1 downto 0);

  signal io_address: std_logic_vector(maxAddrBitIncIO downto 0);
  signal io_write: std_logic_vector(wordSize-1 downto 0);
  signal io_we: std_logic;
  signal io_re: std_logic;
  signal io_device_busy: std_logic;

  signal spi_pf_miso: std_logic;
  signal spi_pf_mosi: std_logic;
  signal spi_pf_sck: std_logic;
  signal uart_tx: std_logic;
  signal uart_rx: std_logic;
begin

  io_device_busy <= spi_busy or spi2_busy or crc16_busy;

  iobusy: if zpuino_iobusyinput=true generate
    process(clk)
    begin
      if rising_edge(clk) then
        if we='1' or re='1' then
          addr_save_q <= address;
        end if;
        if we='1' then
          write_save_q <= write;
        end if;
      end if;
    end process;

    io_address <= addr_save_q;
    io_write <= write_save_q;

    -- Generate busy signal, and rd/wr flags

    process(io_device_busy, re, we)
    begin
      if (re='1' or we='1') then
        busy <= '1';
      elsif io_device_busy='1' then
        busy <= '1';
      else
        busy <= '0';
      end if;
    end process;

    process(clk)
    begin
      if rising_edge(clk) then
        if areset='1' then
          io_re <= '0';
          io_we <= '0';
        else
          -- If no device is busy, propagate request
          if io_device_busy='0' then
            io_re <= re;
            io_we <= we;
          end if;
        end if;
      end if;
    end process;

  end generate;

  noiobusy: if zpuino_iobusyinput=false generate

    io_address <= address;
    io_write <= write;
    io_re <= re;
    io_we <= we;

    busy <= io_device_busy;
  end generate;


  ivecs(0) <= timers_interrupt(0);
  ivecs(1) <= timers_interrupt(1);
  ivecs(15 downto 2) <= (others => '0');

  -- MUX read signals
  process(io_address,spi_read,uart_read,gpio_read,timers_read,intr_read,sigmadelta_read,spi2_read,crc16_read)
  begin
    case io_address(14 downto 11) is
      when "0000" =>
        read <= spi_read;
      when "0001" =>
        read <= uart_read;
      when "0010" =>
        read <= gpio_read;
      when "0011" =>
        read <= timers_read;
      when "0100" =>
        read <= intr_read;
      when "0101" =>
        read <= sigmadelta_read;
      when "0110" =>
        read <= spi2_read;
      when "0111" =>
        read <= crc16_read;
      when others =>
        read <= (others => DontCareValue);
    end case;
  end process;

  -- Enable signals

  process(io_address,io_re,io_we)
  begin
    spi_re <= '0';
    spi_we <= '0';
    uart_re <= '0';
    uart_we <= '0';
    gpio_re <= '0';
    gpio_we <= '0';
    timers_re <= '0';
    timers_we <= '0';
    intr_re <= '0';
    intr_we <= '0';
    sigmadelta_re <= '0';
    sigmadelta_we <= '0';
    spi2_re <= '0';
    spi2_we <= '0';
    crc16_we <= '0';
    crc16_re <= '0';

    case io_address(14 downto 11) is
      when "0000" =>
        spi_re <= io_re;
        spi_we <= io_we;
      when "0001" =>
        uart_re <= io_re;
        uart_we <= io_we;
      when "0010" =>
        gpio_re <= io_re;
        gpio_we <= io_we;
      when "0011" =>
        timers_re <= io_re;
        timers_we <= io_we;
      when "0100" =>
        intr_re <= io_re;
        intr_we <= io_we;
      when "0101" =>
        sigmadelta_re <= io_re;
        sigmadelta_we <= io_we;
      when "0110" =>
        spi2_re <= io_re;
        spi2_we <= io_we;
      when "0111" =>
        crc16_re <= io_re;
        crc16_we <= io_we;
      when others =>
    end case;
  end process;

  fpspi_inst: zpuino_spi
  port map (
    clk       => clk,
	 	areset    => areset,
    read      => spi_read,
    write     => io_write,
    address   => io_address(2 downto 2),
    we        => spi_we,
    re        => spi_re,
    busy      => spi_busy,
    interrupt => open,

    mosi      => spi_pf_mosi,
    miso      => spi_pf_miso,
    sck       => spi_pf_sck,
    enabled   => spi_enabled
  );

  userspi_inst: zpuino_spi
  port map (
    clk       => clk,
	 	areset    => areset,
    read      => spi2_read,
    write     => io_write,
    address   => io_address(2 downto 2),
    we        => spi2_we,
    re        => spi2_re,
    busy      => spi2_busy,
    interrupt => open,

    mosi      => spi2_mosi,
    miso      => spi2_miso,
    sck       => spi2_sck,
    enabled   => spi2_enabled
  );

  uart_inst: zpuino_uart
  port map (
    clk       => clk,
	 	areset    => areset,
    read      => uart_read,
    write     => io_write,
    address   => io_address(2 downto 2),
    we        => uart_we,
    re        => uart_re,
    busy      => open,
    interrupt => open,
    enabled   => uart_enabled,
    tx        => uart_tx,
    rx        => uart_rx
  );

  gpio_inst: zpuino_gpio
  generic map (
    gpio_count => zpuino_gpio_count
  )
  port map (
    clk       => clk,
	 	areset    => areset,
    read      => gpio_read,
    write     => io_write,
    address   => io_address(10 downto 2),
    we        => gpio_we,
    re        => gpio_re,
    spp_data  => gpio_spp_data,
    spp_read  => gpio_spp_read,
    spp_en    => gpio_spp_en,
    busy      => open,
    interrupt => open,

    gpio_i      => gpio_i,
    gpio_t      => gpio_t,
    gpio_o      => gpio_o
  );

  timers_inst: zpuino_timers
  port map (
    clk       => clk,
	 	areset    => areset,
    read      => timers_read,
    write     => io_write,
    address   => io_address(4 downto 2),
    we        => timers_we,
    re        => timers_re,
    spp_data  => timers_spp_data,
    spp_en    => timers_spp_en,
    busy      => open,
    interrupt => timers_interrupt
  );

  intr_inst: zpuino_intr
  port map (
    clk       => clk,
	 	areset    => areset,
    read      => intr_read,
    write     => io_write,
    address   => io_address(2 downto 2),
    we        => intr_we,
    re        => intr_re,

    busy      => open,
    interrupt => interrupt,
    poppc_inst=> intready,

    ivecs     => ivecs
  );

  sigmadelta_inst: zpuino_sigmadelta
  port map (
    clk       => clk,
	 	areset    => areset,
    read      => sigmadelta_read,
    write     => io_write,
    address   => io_address(2 downto 2),
    we        => sigmadelta_we,
    re        => sigmadelta_re,
    spp_data  => sigmadelta_spp_data,
    spp_en    => sigmadelta_spp_en,
    busy      => open,
    interrupt => open
  );

  crc16_inst: zpuino_crc16
  port map (
    clk       => clk,
	 	areset    => areset,
    read      => crc16_read,
    write     => io_write,
    address   => io_address(3 downto 2),
    we        => crc16_we,
    re        => crc16_re,
    busy      => crc16_busy
  );

  process(spi_enabled,spi2_enabled,spi_enabled,
          uart_enabled,sigmadelta_spp_en, uart_tx,
          gpio_spp_read, spi_pf_mosi, spi_pf_sck,
          sigmadelta_spp_data,timers_spp_data,
          spi2_mosi,spi2_sck,timers_spp_en)
  begin
    gpio_spp_en(zpuino_gpio_count-1 downto 0) <= (others=>'0');
    gpio_spp_data <= (others => DontCareValue);

    gpio_spp_en(0) <= uart_enabled;         -- PPS1 : UART RX
    uart_rx <= gpio_spp_read(0);

    gpio_spp_en(1) <= uart_enabled;         -- PPS0 : UART TX
    gpio_spp_data(1) <= uart_tx;

    gpio_spp_en(2) <= spi_enabled;          -- PPS2 : SPI MISO
    spi_pf_miso <= gpio_spp_read(2);

    gpio_spp_en(3) <= spi_enabled;          -- PPS3 : SPI MOSI
    gpio_spp_data(3) <= spi_pf_mosi;

    gpio_spp_en(4) <= spi_enabled;          -- PPS4 : SPI SCK
    gpio_spp_data(4) <= spi_pf_sck;

    gpio_spp_en(5) <= sigmadelta_spp_en;    -- PPS5 : SIGMADELTA DATA
    gpio_spp_data(5) <= sigmadelta_spp_data;

    gpio_spp_en(6) <= timers_spp_en(0);     -- PPS6 : TIMER0
    gpio_spp_data(6) <= timers_spp_data(0);

    gpio_spp_en(7) <= timers_spp_en(1);     -- PPS7 : TIMER1
    gpio_spp_data(7) <= timers_spp_data(1);

    gpio_spp_en(8) <= spi2_enabled;         -- PPS8 : USPI MISO
    spi2_miso <= gpio_spp_read(8);

    gpio_spp_en(9) <= spi2_enabled;         -- PPS9 : USPI MOSI
    gpio_spp_data(9) <= spi2_mosi;

    gpio_spp_en(10) <= spi2_enabled;         -- PPS10: USPI SCK
    gpio_spp_data(10) <= spi2_sck;

  end process;

end behave;
