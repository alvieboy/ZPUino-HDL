library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.zpupkg.all;
use work.zpuinopkg.all;

entity s3e_eval_zpuino is
  port (
    CLK:        in std_logic;
    RST:        in std_logic;

    SPI_SCK:    out std_logic;
    SPI_MISO:   in std_logic;
    SPI_MOSI:   out std_logic;
    SPI_SS_B:   inout std_logic;

    LED:        inout std_logic_vector(7 downto 0);

    -- UART
    UART_TX:    out std_logic;
    UART_RX:    in std_logic;

    -- Signals to disable (write '1')
    DAC_CS:     out std_logic;
    SF_CE0:     out std_logic;
    FPGA_INIT_B:out std_logic;
    AMP_CS:     out std_logic;
    -- Signals to disable (write '0')
    AD_CONV:    out std_logic
  );
end entity s3e_eval_zpuino;

architecture behave of s3e_eval_zpuino is

component zpuino_top is
  port (
    clk:      in std_logic;
	 	areset:   in std_logic;

    -- SPI program flash
    spi_pf_miso:  in std_logic;
    spi_pf_mosi:  out std_logic;
    spi_pf_sck:   out std_logic;
    spi_pf_nsel:  out std_logic;

    -- UART
    uart_rx:      in std_logic;
    uart_tx:      out std_logic;

    gpio:         inout std_logic_vector(31 downto 0)

  );
end component zpuino_top;


signal gpio: std_logic_vector(31 downto 0);
signal spi_mosi_i: std_logic;

begin

    -- Signals to disable (write '1')
    DAC_CS <= '1';

    SF_CE0 <= '1';
    FPGA_INIT_B<='0';

    AMP_CS<='1';
    -- Signals to disable (write '0')
    AD_CONV<='0';

    LED(3 downto 0) <= gpio(11 downto 8);
    LED(7) <= gpio(0);

    LED(6) <= SPI_MISO;
    SPI_MOSI <= spi_mosi_i;
    LED(5) <= spi_mosi_i;
    LED(4) <= rst;

  zpuino:zpuino_top
  port map (
    clk           => clk,
	 	areset        => rst,

    -- SPI program flash
    spi_pf_miso   => SPI_MISO,
    spi_pf_mosi   => SPI_MOSI_i,
    spi_pf_sck    => SPI_SCK,
    spi_pf_nsel   => SPI_SS_B,

    -- UART
    uart_rx       => UART_RX,
    uart_tx       => UART_TX,

    gpio          => gpio
  );

end behave;
