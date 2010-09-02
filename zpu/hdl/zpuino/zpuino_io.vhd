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

    -- SPI program flash
    spi_pf_miso:  in std_logic;
    spi_pf_mosi:  out std_logic;
    spi_pf_sck:   out std_logic;
    spi_pf_nsel:  out std_logic;

    -- UART
    uart_rx:      in std_logic;
    uart_tx:      out std_logic
  );
end entity zpuino_io;

architecture behave of zpuino_io is

  signal spi_read:     std_logic_vector(wordSize-1 downto 0);
  signal spi_re:  std_logic;
  signal spi_we:  std_logic;

  signal uart_read:     std_logic_vector(wordSize-1 downto 0);
  signal uart_re:  std_logic;
  signal uart_we:  std_logic;

begin

  busy <= '0';
  interrupt <= '0';

  -- MUX read signals
  process(address,spi_read,uart_read)
  begin
    case address(3) is
      when '0' =>
        read <= spi_read;
      when '1' =>
        read <= uart_read;
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

    case address(3) is
      when '0' =>
        spi_re <= re;
        spi_we <= we;
      when '1' =>
        uart_re <= re;
        uart_we <= we;
      when others =>
    end case;
  end process;


  fpspi: zpuino_spi 
  port map (
    clk       => clk,
	 	areset    => areset,
    read      => spi_read,
    write     => write,
    address   => address(2 downto 2),
    we        => spi_we,
    re        => spi_re,
    busy      => open,
    interrupt => open,

    mosi      => spi_pf_mosi,
    miso      => spi_pf_miso,
    sck       => spi_pf_sck,
    nsel      => spi_pf_nsel
  );

  uart: zpuino_uart
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

end behave;
