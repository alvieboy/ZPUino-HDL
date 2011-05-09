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
    address:  in std_logic_vector(maxIObit downto minIObit);
    we:       in std_logic;
    re:       in std_logic;
    busy:     out std_logic;
    interrupt:out std_logic;

    mosi:     out std_logic;
    miso:     in std_logic;
    sck:      out std_logic;
    enabled:  out std_logic
  );
end entity zpuino_spi;

architecture behave of zpuino_spi is


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

  signal spi_read: std_logic_vector(31 downto 0);
  signal spi_en: std_logic;
  signal spi_ready: std_logic;
  signal spi_clk_en: std_logic;
  signal spi_clkrise: std_logic;
  signal spi_clkfall: std_logic;
  signal spi_clk_pres: std_logic_vector(2 downto 0);
  signal spi_samprise: std_logic;
  signal spi_enable_q: std_logic;
  signal spi_txblock_q: std_logic;
  signal cpol: std_logic;
  signal miso_i: std_logic;
  signal spi_transfersize_q: std_logic_vector(1 downto 0);

begin

  zspi: spi
    port map (
      clk   => clk,
      rst   => areset,
      din   => write,
      dout  => spi_read,
      en    => spi_en,
      ready => spi_ready,
      transfersize => spi_transfersize_q,

      miso  => miso_i,
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

  -- Simulation only
  miso_i <= '0' when miso='Z' else miso;

  -- Direct access (write) to SPI

  spi_en <= '1' when we='1' and address(2)='1' and spi_ready='1' else '0';

  busygen: if zpuino_spiblocking=true generate
    busy <= '1' when address(2)='1' and (we='1' or re='1') and spi_ready='0' and spi_txblock_q='1' else '0';
  end generate;

  nobusygen: if zpuino_spiblocking=false generate
    busy <= '0';
  end generate;

  

  interrupt <= '0';
  enabled <= spi_enable_q;

  -- Prescaler write

  process(clk)
  begin
    if rising_edge(clk) then
      if areset='1' then
        spi_enable_q<='0';
        spi_txblock_q<='1';
        spi_transfersize_q<=(others => '0');
      else
      if we='1' then
        if address(2)='0' then
          spi_clk_pres <= write(3 downto 1);
          cpol <= write(4);
          spi_samprise <= write(5);
          spi_enable_q <= write(6);
          spi_txblock_q <= write(7);
          spi_transfersize_q <= write(9 downto 8);
        end if;
      end if;
      end if;
    end if;
  end process;

  process(address, spi_ready, spi_read, spi_clk_pres,cpol,spi_samprise,spi_enable_q)
  begin
    read <= (others =>'0');
    case address(2) is
      when '0' =>
        read(0) <= spi_ready;
        read(3 downto 1) <= spi_clk_pres;
        read(4) <= cpol;
        read(5) <= spi_samprise;
        read(6) <= spi_enable_q;
        read(7) <= spi_txblock_q;
        read(9 downto 8) <= spi_transfersize_q;
      when '1' =>
        read <= spi_read;
      when others =>
        read <= (others => DontCareValue);
    end case;
  end process;

end behave;

