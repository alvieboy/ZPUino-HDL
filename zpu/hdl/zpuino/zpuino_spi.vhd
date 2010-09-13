--
--  SPI interface for ZPUINO
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
use work.zpu_config.all;
use work.zpuino_config.all;
use work.zpupkg.all;
use work.zpuinopkg.all;

entity zpuino_spi is
  port (
    clk:      in std_logic;
	 	areset:   in std_logic;
    read:     out std_logic_vector(wordSize-1 downto 0);
    write:    in std_logic_vector(wordSize-1 downto 0);
    address:  in std_logic_vector(0 downto 0);
    we:       in std_logic;
    re:       in std_logic;
    busy:     out std_logic;
    interrupt:out std_logic;

    mosi:     out std_logic;
    miso:     in std_logic;
    sck:      out std_logic;
    nsel:     out std_logic
  );
end entity zpuino_spi;

architecture behave of zpuino_spi is


  component spi is
    generic (
      bits: integer := 8
    );
    port (
      clk:  in std_logic;
      rst:  in std_logic;
      din:  in std_logic_vector(bits-1 downto 0);
      dout:  out std_logic_vector(bits-1 downto 0);
      en:   in std_logic;
      ready: out std_logic;
  
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
      pres:  in std_logic_vector(1 downto 0);
    
      clkrise: out std_logic;
      clkfall: out std_logic;
      spiclk:  out std_logic
  );
  end component spiclkgen;

  signal spi_read: std_logic_vector(31 downto 0);
  signal spi_en: std_logic;
  signal spi_ready: std_logic;
  signal spi_clk_en: std_logic;
  signal spi_clkrise: std_logic;
  signal spi_clkfall: std_logic;
  signal spi_clk_pres: std_logic_vector(1 downto 0);
  signal spi_samprise: std_logic;
  signal cpol: std_logic;

begin

  zspi: spi
    generic map (
      bits => 32
    )
    port map (
      clk   => clk,
      rst   => areset,
      din   => write,
      dout  => spi_read,
      en    => spi_en,
      ready => spi_ready,
  
      miso  => miso,
      mosi  => mosi,
  
      clk_en    => spi_clk_en,
  
      clkrise   => spi_clkrise,
      clkfall   => spi_clkfall,
      samprise  => spi_samprise
    );

  zspiclk: spiclkgen
    port map (
      clk     => clk,
      rst     => areset,
      en      => spi_clk_en,
      pres    => spi_clk_pres,
      clkrise => spi_clkrise,
      clkfall => spi_clkfall,
      spiclk  => sck,
      cpol    => cpol
    );

  -- Direct access (write) to SPI

  spi_en <= '1' when we='1' and address="1" else '0';

  busygen: if zpuino_spiblocking=true generate
    busy <= '1' when address="1" and (we='1' or re='1') and spi_ready='0' else '0';
  end generate;

  nobusygen: if zpuino_spiblocking=false generate
    --busy <= '1' when address="1" and (we='1' or re='1') and spi_ready='0' else '0';
    busy <= '0';
  end generate;

  

  interrupt <= '0';

  -- Prescaler write

  process(clk)
  begin
    if rising_edge(clk) then
      if we='1' then
        if address="0" then
          spi_clk_pres <= write(2 downto 1);
          cpol <= write(3);
          spi_samprise <= write(4);
        end if;
      end if;
    end if;
  end process;

  process(address, spi_ready, spi_read, spi_clk_pres,cpol,spi_samprise)
  begin
    read <= (others =>'0');
    if address="0" then
      read(0) <= spi_ready;
      read(2 downto 1) <= spi_clk_pres;
      read(3) <= cpol;
      read(4) <= spi_samprise;
    else
      read <= spi_read;
    end if;
  end process;

end behave;

