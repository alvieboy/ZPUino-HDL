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
    -- SPI program flash
    spi_pf_miso:  in std_logic;
    spi_pf_mosi:  out std_logic;
    spi_pf_sck:   out std_logic;
    spi_pf_nsel:  out std_logic;

    -- UART
    uart_rx:      in std_logic;
    uart_tx:      out std_logic;

    -- GPIO
    gpio:         inout std_logic_vector(31 downto 0)
  );
end entity zpuino_io;

architecture behave of zpuino_io is

  signal spi_read:     std_logic_vector(wordSize-1 downto 0);
  signal spi_re:  std_logic;
  signal spi_we:  std_logic;
  signal spi_busy:  std_logic;

  signal uart_read:     std_logic_vector(wordSize-1 downto 0);
  signal uart_re:  std_logic;
  signal uart_we:  std_logic;

  signal gpio_read:     std_logic_vector(wordSize-1 downto 0);
  signal gpio_re:  std_logic;
  signal gpio_we:  std_logic;
  signal gpio_spp_data: std_logic_vector(31 downto 0);
  signal gpio_spp_en: std_logic_vector(31 downto 0);

  signal timers_read:     std_logic_vector(wordSize-1 downto 0);
  signal timers_re:  std_logic;
  signal timers_we:  std_logic;
  signal timers_interrupt:  std_logic_vector(1 downto 0);

  signal intr_read:     std_logic_vector(wordSize-1 downto 0);
  signal intr_re:  std_logic;
  signal intr_we:  std_logic;

  signal ivecs: std_logic_vector(15 downto 0);

  signal sigmadelta_read:     std_logic_vector(wordSize-1 downto 0);
  signal sigmadelta_re:  std_logic;
  signal sigmadelta_we:  std_logic;

begin

  busy <= spi_busy;
  ivecs(0) <= timers_interrupt(0);
  ivecs(1) <= timers_interrupt(1);
  ivecs(15 downto 2) <= (others => '0');

  -- MUX read signals
  process(address,spi_read,uart_read,gpio_read,timers_read,intr_read,sigmadelta_read)
  begin
    case address(7 downto 5) is
      when "000" =>
        read <= spi_read;
      when "001" =>
        read <= uart_read;
      when "010" =>
        read <= gpio_read;
      when "011" =>
        read <= timers_read;
      when "100" =>
        read <= intr_read;
      when "101" =>
        read <= sigmadelta_read;
      when others =>
        read <= (others => DontCareValue);
    end case;
  end process;

  -- Enable signals

  process(address,re,we)
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

    case address(7 downto 5) is
      when "000" =>
        spi_re <= re;
        spi_we <= we;
      when "001" =>
        uart_re <= re;
        uart_we <= we;
      when "010" =>
        gpio_re <= re;
        gpio_we <= we;
      when "011" =>
        timers_re <= re;
        timers_we <= we;
      when "100" =>
        intr_re <= re;
        intr_we <= we;
      when "101" =>
        sigmadelta_re <= re;
        sigmadelta_we <= we;
      when others =>
    end case;
  end process;

  spi_pf_nsel <= gpio(0);

  fpspi_inst: zpuino_spi
  port map (
    clk       => clk,
	 	areset    => areset,
    read      => spi_read,
    write     => write,
    address   => address(2 downto 2),
    we        => spi_we,
    re        => spi_re,
    busy      => spi_busy,
    interrupt => open,

    mosi      => spi_pf_mosi,
    miso      => spi_pf_miso,
    sck       => spi_pf_sck,
    nsel      => open
  );

  uart_inst: zpuino_uart
  port map (
    clk       => clk,
	 	areset    => areset,
    read      => uart_read,
    write     => write,
    address   => address(2 downto 2),
    we        => uart_we,
    re        => uart_re,
    busy      => open,
    interrupt => open,

    tx        => uart_tx,
    rx        => uart_rx
  );

  gpio_inst: zpuino_gpio
  port map (
    clk       => clk,
	 	areset    => areset,
    read      => gpio_read,
    write     => write,
    address   => address(2 downto 2),
    we        => gpio_we,
    re        => gpio_re,
    spp_data  => gpio_spp_data,
    spp_en    => gpio_spp_en,
    busy      => open,
    interrupt => open,

    gpio      => gpio
  );

  timers_inst: zpuino_timers
  port map (
    clk       => clk,
	 	areset    => areset,
    read      => timers_read,
    write     => write,
    address   => address(4 downto 2),
    we        => timers_we,
    re        => timers_re,
    spp_data  => gpio_spp_data(2 downto 1),
    spp_en    => gpio_spp_en(2 downto 1),
    busy      => open,
    interrupt => timers_interrupt
  );

  intr_inst: zpuino_intr
  port map (
    clk       => clk,
	 	areset    => areset,
    read      => intr_read,
    write     => write,
    address   => address(2 downto 2),
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
    write     => write,
    address   => address(2 downto 2),
    we        => sigmadelta_we,
    re        => sigmadelta_re,
    spp_data  => gpio_spp_data(3),
    spp_en    => gpio_spp_en(3),
    busy      => open,
    interrupt => open
  );

  gpio_spp_en(0) <= '0';
  gpio_spp_en(31 downto 4) <= (others=>'0');


end behave;
