--
--  Testbench for ZPUINO
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

entity tb_zpuino is
end entity;

architecture behave of tb_zpuino is

  constant period : time := 10 ns;

  signal w_clk : std_logic := '0';
  signal w_rst : std_logic := '0';
  --signal gpio:  std_logic_vector(31 downto 0);

  signal spi_pf_miso:  std_logic;
  signal spi_pf_miso_dly:  std_logic;
  signal spi_pf_mosi:  std_logic;
  signal spi_pf_mosi_dly:  std_logic;
  signal spi_pf_sck_dly:  std_logic;
  signal spi_pf_sck:   std_logic;
  signal spi_pf_nsel:  std_logic;


  component zpuino_top is
  port (
    clk:      in std_logic;
	 	areset:   in std_logic;

    -- SPI program flash
    spi_pf_miso:  in std_logic;
    spi_pf_mosi:  out std_logic;
    spi_pf_sck:   out std_logic;
    --spi_pf_nsel:  out std_logic;

    -- UART
    uart_rx:      in std_logic;
    uart_tx:      out std_logic;
        -- GPIO
    gpio:         inout std_logic_vector(31 downto 0)

  );
  end component zpuino_top;

  component M25P16 IS
  GENERIC (	init_file: string := string'("initM25P16.txt");         -- Init file name
		SIZE : positive := 1048576*16;                          -- 16Mbit
		Plength : positive := 256;                              -- Page length (in Byte)
		SSIZE : positive := 524288;                             -- Sector size (in # of bits)
		NB_BPi: positive := 3;                                  -- Number of BPi bits
		signature : STD_LOGIC_VECTOR (7 downto 0):="00010100";  -- Electronic signature
		manufacturerID : STD_LOGIC_VECTOR (7 downto 0):="00100000"; -- Manufacturer ID
		memtype : STD_LOGIC_VECTOR (7 downto 0):="00100000"; -- Memory Type
		density : STD_LOGIC_VECTOR (7 downto 0):="00010101"; -- Density 
		Tc: TIME := 20 ns;                                      -- Minimum Clock period
		Tr: TIME := 50 ns;                                      -- Minimum Clock period for read instruction
		tSLCH: TIME:= 5 ns;                                    -- notS active setup time (relative to C)
		tCHSL: TIME:= 5 ns;                                    -- notS not active hold time
		tCH : TIME := 9 ns;                                    -- Clock high time
		tCL : TIME := 9 ns;                                    -- Clock low time
		tDVCH: TIME:= 2 ns;                                     -- Data in Setup Time
		tCHDX: TIME:= 5 ns;                                     -- Data in Hold Time
		tCHSH : TIME := 5 ns;                                  -- notS active hold time (relative to C)
	 	tSHCH: TIME := 5 ns;                                   -- notS not active setup  time (relative to C)
		tSHSL: TIME := 100 ns;                                  -- /S deselect time
		tSHQZ: TIME := 8 ns;                                   -- Output disable Time
		tCLQV: TIME := 8 ns;                                   -- clock low to output valid
		tHLCH: TIME := 5 ns;                                   -- NotHold active setup time
		tCHHH: TIME := 5 ns;                                   -- NotHold not active hold time
		tHHCH: TIME := 5 ns;                                   -- NotHold not active setup time
		tCHHL: TIME := 5 ns;                                   -- NotHold active hold time
		tHHQX: TIME := 8 ns;                                   -- NotHold high to Output Low-Z
		tHLQZ: TIME := 8 ns;                                   -- NotHold low to Output High-Z
	        tWHSL: TIME := 20 ns;                                   -- Write protect setup time (SRWD=1)
	        tSHWL: TIME := 100 ns;                                 -- Write protect hold time (SRWD=1)
		tDP: TIME := 3 us;                                      -- notS high to deep power down mode
		tRES1: TIME := 30 us;                                    -- notS high to stand-by power mode
		tRES2: TIME := 30 us;                                  --
		tW: TIME := 15 ms;                                      -- write status register cycle time
		tPP: TIME := 5 ms;                                      -- page program cycle time
		tSE: TIME := 3 sec;                                     -- sector erase cycle time
		tBE: TIME := 40 sec;                                    -- bulk erase cycle time
		tVSL: TIME := 10 us;                                    -- Vcc(min) to /S low
		tPUW: TIME := 10 ms;                                    -- Time delay to write instruction
		Vwi: REAL := 2.5 ;                                      -- Write inhibit voltage (unit: V)
		Vccmin: REAL := 2.7 ;                                   -- Minimum supply voltage
		Vccmax: REAL := 3.6                                     -- Maximum supply voltage
		);

    PORT(		VCC: IN REAL;
		  C, D, S, W, HOLD : IN std_logic ;
		  Q : OUT std_logic
    );
  end component;

  signal vcc: real := 0.0;
  signal uart_tx: std_logic;
  signal uart_rx: std_logic := '0';
  signal gpio_i: std_logic_vector(31 downto 0);
begin

  uart_rx <= '1';--uart_tx after 7 us;
                

  top: zpuino_top
    port map (
      clk     => w_clk,
	 	  areset   => w_rst,
      spi_pf_miso   => spi_pf_miso,
      spi_pf_mosi   => spi_pf_mosi,
      spi_pf_sck    => spi_pf_sck,
      --spi_pf_nsel   => spi_pf_nsel,
      uart_rx => uart_rx,
      uart_tx => uart_tx,
      gpio => gpio_i
  );

  -- These values were taken from post-P&R timing analysis

  spi_pf_mosi_dly <= spi_pf_mosi after 3.850 ns;
  spi_pf_sck_dly <= spi_pf_sck after 3.825 ns;
  spi_pf_miso <= spi_pf_miso_dly after  2.540 ns;
  spi_pf_nsel <= gpio_i(0) after  3.850 ns;

  spiflash: M25P16
    port map (
      VCC => vcc,
		  C   => spi_pf_sck_dly,
      D   => spi_pf_mosi_dly,
      S   => spi_pf_nsel,
      W   => '0',
      HOLD => '1',
		  Q   => spi_pf_miso_dly
    );

  spiflash2: M25P16
    port map (
      VCC => vcc,
		  C   => gpio_i(6),
      D   => gpio_i(8),
      S   => gpio_i(7),
      W   => '0',
      HOLD => '1',
		  Q   => gpio_i(5)
    );

  w_clk <= not w_clk after period/2;

  stimuli : process
   begin
      w_rst   <= '0';
      wait for 1 ns;
      vcc     <= 3.3;
      w_rst   <= '1';
      wait for 120 ns;
      w_rst   <= '0';
      wait for 4 ms;
      report "End" severity failure;
      wait;
   end process;

end behave;
