library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb is
end entity tb;

architecture sim of tb is

  constant period: time := 31.25 ns;
  signal w_clk: std_logic := '0';

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

  signal sram_addr:  std_logic_vector(18 downto 0);
  signal sram_data:  std_logic_vector(15 downto 0);
  signal sram_ce:    std_logic;
  signal sram_we:    std_logic;
  signal sram_oe:    std_logic;
  signal sram_be:    std_logic;

  signal sram_addr_i:  std_logic_vector(18 downto 0);
--  signal sram_data:  std_logic_vector(15 downto 0);
  signal sram_ce_i:    std_logic;
  signal sram_we_i:    std_logic;
  signal sram_oe_i:    std_logic;
  signal sram_be_i:    std_logic;

  signal spi_miso_i:    std_logic;
  signal vcc: real := 0.0;

  signal spi_sck, spi_mosi, spi_miso, spi_cs: std_logic;



begin
  w_clk <= not w_clk after period/2;

  uut: entity work.papilio_pro_top
  port map (
    CLK => w_clk,
    RXD => '0',
    SPI_MISO => spi_miso,
    SPI_MOSI => spi_mosi,
    SPI_SCK => spi_sck,
    SPI_CS   => spi_cs

  );

  spiflash: M25P16
    port map (
      VCC => vcc,
		  C   => SPI_SCK,
      D   => SPI_MOSI,
      S   => SPI_CS,
      W   => '0',
      HOLD => '1',
		  Q   => spi_miso_i
    );

  SPI_MISO <= transport spi_miso_i after 7.5 ns;

  process
  begin
    wait for 1 ns;
    vcc <= 3.3;
    wait;
  end process;

end sim;
