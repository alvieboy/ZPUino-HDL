--
--  ADC interface
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

library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity zpuino_adc is
  port (
    clk:      in std_logic;
	 	areset:   in std_logic;
    read:     out std_logic_vector(wordSize-1 downto 0);
    write:    in std_logic_vector(wordSize-1 downto 0);
    address:  in std_logic_vector(2 downto 0);
    we:       in std_logic;
    re:       in std_logic;
    busy:     out std_logic;
    interrupt:out std_logic;

    sample:   in std_logic; -- External trigger

    -- GPIO SPI pins

    mosi:     out std_logic;
    miso:     in std_logic;
    sck:      out std_logic;
    seln:     out std_logic;
    enabled:  out std_logic

  );
end entity zpuino_adc;


architecture behave of zpuino_adc is

  component spi is
    port (
      clk:  in std_logic;
      rst:  in std_logic;
      din:  in std_logic_vector(31 downto 0);
      dout:  out std_logic_vector(31 downto 0);
      en:   in std_logic;
      ready: out std_logic;
      transfersize: in std_logic_vector(1 downto 0);
  
      miso: in std_logic;
      mosi: out std_logic;
  
      clk_en:    out std_logic;
  
      clkrise: in std_logic;
      clkfall: in std_logic;
      samprise:in std_logic
    );
  end component spi;

  component spiclkgen is
    port (
      clk:   in std_logic;
      rst:   in std_logic;
      en:    in std_logic;
      cpol:  in std_logic;
      pres:  in std_logic_vector(2 downto 0);
    
      clkrise: out std_logic;
      clkfall: out std_logic;
      spiclk:  out std_logic
  );
  end component spiclkgen;


  signal request_samples_q: unsigned(10 downto 0); -- Maximum 4K samples
  signal current_sample_q: unsigned(10 downto 0); -- Current sample

  signal read_fifo_ptr_q: unsigned(10 downto 2);
--  signal write_fifo_ptr_q: unsigned(10 downto 0);
  signal dly_interval_q: unsigned(31 downto 0); -- Additional clock delay between samples


  signal fifo_read: std_logic_vector(31 downto 0);
  signal fifo_read_address: std_logic_vector(10 downto 2);
  signal fifo_write_address: std_logic_vector(10 downto 0);
  signal fifo_write: std_logic_vector(7 downto 0);
  signal fifo_wr: std_logic;

  signal spi_dout: std_logic_vector(31 downto 0);
  signal spi_enable: std_logic;
  signal spi_ready: std_logic;
  signal spi_clk_en: std_logic;
  signal spi_clkrise: std_logic;
  signal spi_clkfall: std_logic;
  -- Configuration registers

  signal adc_enabled_q: std_logic;
  signal adc_source_external_q: std_logic;

  signal run_spi: std_logic;
  signal do_sample: std_logic;

begin

  enabled <= adc_enabled_q;

  process(spi_enable,spi_ready)
  begin
    seln<='1';
    if spi_enable='1' or spi_ready='0' then
      seln<='0';
    end if;
  end process;

  adcspi: spi
    port map (
      clk           => clk,
      rst           => areset,
      din           => (others => '0'), -- Change to channel number
      dout          => spi_dout,
      en            => spi_enable,
      ready         => spi_ready,
      transfersize  => "01", -- Fixed 16-bit transfers
  
      miso          => miso,
      mosi          => mosi,
  
      clk_en        => spi_clk_en,
      clkrise       => spi_clkrise,
      clkfall       => spi_clkfall,
      samprise      => '1'
    );

  acdclkgen: spiclkgen
    port map (
      clk     => clk,
      rst     => areset,
      en      => spi_clk_en,
      cpol    => '1',
      pres    => "010", -- Fixed
    
      clkrise => spi_clkrise,
      clkfall => spi_clkfall,
      spiclk  => sck
  );

  process (clk)
  begin
    if rising_edge(clk) then
      if areset='1' then
        read_fifo_ptr_q <= (others => '0');
      else

        if we='1' and address="100" then
          read_fifo_ptr_q <= unsigned(write(10 downto 2));
        else
          if re='1' and address="101" then
            -- FIFO read, increment address
            read_fifo_ptr_q <= read_fifo_ptr_q+1;
          end if;
        end if;
      end if;
    end if;
  end process;


  -- READ muxer
  process(address,fifo_read,request_samples_q,current_sample_q)
  begin
    read <= (others => DontCareValue);
    case address is
      when "000" =>
        if (request_samples_q /= current_sample_q) then
          read(0) <= '0';
        else
          read(0) <= '1';
        end if;
      when "101" =>
        read <= fifo_read;
      when others =>
    end case;
  end process;

  fifo_write_address <= std_logic_vector(current_sample_q);
  fifo_read_address <= std_logic_vector(read_fifo_ptr_q);

  fifo_write <= spi_dout(11 downto 4); -- Data from SPI

  ram: RAMB16_S9_S36
    port map (
      DOA  => open,
      DOB  => fifo_read,
      DOPA => open,
      DOPB => open,
      ADDRA => fifo_write_address,
      ADDRB => fifo_read_address,
      CLKA  => clk,
      CLKB  => clk,
      DIA   => fifo_write,
      DIB   => (others => '0'),
      DIPA  => (others => '0'),
      DIPB  => (others => '0'),
      ENA   => '1',
      ENB   => '1',
      SSRA  => '0',
      SSRB  => '0',
      WEA   => fifo_wr,
      WEB   => '0'
    );


  spi_enable <= '1' when run_spi='1' and spi_ready='1' and do_sample='1' else '0';
  do_sample <= sample when adc_source_external_q='1' else '1';

  -- Main process
  process(clk)
  begin
    if rising_edge(clk) then
      if areset='1' then
        request_samples_q <= (others => '0');
        current_sample_q <= (others => '0');
        run_spi <= '0';
        fifo_wr <= '0';
        adc_source_external_q <= '0';
        adc_enabled_q<='0';
      else

        fifo_wr <= '0';

        if we='1' then
          case address is
            when "000" =>
              -- Write configuration
              adc_enabled_q <= write(0);
              adc_source_external_q <= write(1);
            when "001" =>
              -- Write request samples
              request_samples_q <= unsigned(write(10 downto 0));
              current_sample_q <= (others => '1'); -- WARNING - this will overwrite last value on RAM
              run_spi <= '1';
            when others =>
          end case;
        else
          -- Normal run.
          if (request_samples_q /= current_sample_q) then
            -- Sampling right now.
              if spi_ready='1' then
                -- Add delay here.
                if do_sample='1' then
                  fifo_wr <= '1';
                  run_spi <= '1';
                end if;
              end if;
          else
            run_spi <= '0';
          end if;
          if fifo_wr='1' then
            current_sample_q <= current_sample_q + 1;
          end if;
        end if;
      end if;
    end if;
  end process;
end behave;

