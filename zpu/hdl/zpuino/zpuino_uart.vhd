library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.zpu_config.all;
use work.zpupkg.all;
use work.zpuinopkg.all;

entity zpuino_uart is
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

    tx:       out std_logic;
    rx:       in std_logic
  );
end entity zpuino_uart;

architecture behave of zpuino_uart is

  component RxUnit is
   port(
      clk_i    : in  std_logic;  -- System clock signal
      reset_i  : in  std_logic;  -- Reset input (sync)
      enable_i : in  std_logic;  -- Enable input (rate*4)
      read_i   : in  std_logic;  -- Received Byte Read
      rxd_i    : in  std_logic;  -- RS-232 data input
      rxav_o   : out std_logic;  -- Byte available
      datao_o  : out std_logic_vector(7 downto 0)); -- Byte received
  end component RxUnit;

  component TxUnit is
  port (
     clk_i    : in  std_logic;  -- Clock signal
     reset_i  : in  std_logic;  -- Reset input
     enable_i : in  std_logic;  -- Enable input
     load_i   : in  std_logic;  -- Load input
     txd_o    : out std_logic;  -- RS-232 data output
     busy_o   : out std_logic;  -- Tx Busy
     datai_i  : in  std_logic_vector(7 downto 0)); -- Byte to transmit
  end component TxUnit;

  component uart_brgen is
  port (
     clk:     in std_logic;
     rst:     in std_logic;
     en:      in std_logic;
     count:   in std_logic_vector(15 downto 0);
     clkout:  out std_logic
     );
  end component uart_brgen;

  signal uart_read: std_logic;
  signal uart_write: std_logic;
  signal divider_tx: std_logic_vector(15 downto 0) := x"0004";

  signal divider_rx_q: std_logic_vector(15 downto 0);

  signal data_ready: std_logic;
  signal received_data: std_logic_vector(7 downto 0);
  signal uart_busy: std_logic;
  signal rx_br: std_logic;
  signal tx_br: std_logic;
begin

  rx_inst: RxUnit
    port map(
      clk_i     => clk,
      reset_i   => areset,
      enable_i  => rx_br,
      read_i    => uart_read,
      rxd_i     => rx,
      rxav_o    => data_ready,
      datao_o   => received_data
   );

  uart_read <= '1' when re='1' and address="0" else '0';

  tx_core: TxUnit
    port map(
      clk_i     => clk,
      reset_i   => areset,
      enable_i  => tx_br,
      load_i    => uart_write,
      txd_o     => tx,
      busy_o    => uart_busy,
      datai_i   => write(7 downto 0)
    );

  uart_write <= '1' when we='1' and address="0" else '0';

   -- Rx timing
  rx_timer: uart_brgen
    port map(
      clk => clk,
      rst => areset,
      en => '1',
      clkout => rx_br,
      count => divider_rx_q
    );

   -- Tx timing
  tx_timer: uart_brgen
    port map(
      clk => clk,
      rst => areset,
      en => rx_br,
      clkout => tx_br,
      count => divider_tx
    );

  process(address, received_data, uart_busy, data_ready)
  begin
    read <= (others => '0');
    case address is
      when "1" =>
        read(0) <= data_ready;
        read(1) <= uart_busy;
      when "0" =>
        read(7 downto 0) <= received_data;
      when others =>
    end case;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if we='1' then
        if address="1" then
          divider_rx_q <= write(15 downto 0);
        end if;
      end if;
    end if;
  end process;

end behave;
