--
--  UART for ZPUINO
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
use work.zpupkg.all;
use work.zpuinopkg.all;

entity zpuino_uart is
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

    enabled:  out std_logic;
    tx:       out std_logic;
    rx:       in std_logic
  );
end entity zpuino_uart;

architecture behave of zpuino_uart is

  component zpuino_uart_rx is
  port (
    clk:      in std_logic;
	 	rst:      in std_logic;
    rx:       in std_logic;
    rxclk:    in std_logic;
    read:     in std_logic;
    data:     out std_logic_vector(7 downto 0);
    data_av:  out std_logic
  );
  end component zpuino_uart_rx;


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

  component fifo is
  port (
    clk:      in std_logic;
    rst:      in std_logic;
    wr:       in std_logic;
    rd:       in std_logic;
    write:    in std_logic_vector(7 downto 0);
    read :    out std_logic_vector(7 downto 0);
    full:     out std_logic;
    empty:    out std_logic
  );
  end component fifo;


  signal uart_read: std_logic;
  signal uart_write: std_logic;
  signal divider_tx: std_logic_vector(15 downto 0) := x"000f";

  signal divider_rx_q: std_logic_vector(15 downto 0);

  signal data_ready: std_logic;
  signal received_data: std_logic_vector(7 downto 0);
  signal fifo_data: std_logic_vector(7 downto 0);
  signal uart_busy: std_logic;
  signal fifo_empty: std_logic;
  signal rx_br: std_logic;
  signal tx_br: std_logic;
  signal rx_en: std_logic;

  signal dready_q: std_logic;
  signal data_ready_dly_q: std_logic;
  signal fifo_rd: std_logic;
  signal enabled_q: std_logic;

begin

  enabled <= enabled_q;
  interrupt <= '0';

  rx_inst: zpuino_uart_rx
    port map(
      clk     => clk,
      rst     => areset,
      rxclk   => rx_br,
      read    => uart_read,
      rx      => rx,
      data_av => data_ready,
      data    => received_data
   );

  uart_read <= dready_q;

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

  uart_write <= '1' when we='1' and address(2)='0' else '0';

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

  process(clk)
  begin
    if rising_edge(clk) then
      if areset='1' then
        dready_q<='0';
        data_ready_dly_q<='0';
      else

        data_ready_dly_q<=data_ready;

        if data_ready='1' and data_ready_dly_q='0' then
          dready_q<='1';
        else
          dready_q<='0';
        end if;

      end if;
    end if;
  end process;

  fifo_instance: fifo
    port map (
      clk   => clk,
      rst   => areset,
      wr    => dready_q,
      rd    => fifo_rd,
      write => received_data,
      read  => fifo_data,
      full  => open,
      empty => fifo_empty
    );
  

  fifo_rd<='1' when address(2)='0' and re='1' else '0';

  process(address, received_data, uart_busy, data_ready, fifo_empty, fifo_data)
  begin
    read <= (others => '0');
    case address(2) is
      when '1' =>
        read(0) <= not fifo_empty;
        read(1) <= uart_busy;
      when '0' =>
        read(7 downto 0) <= fifo_data;
      when others =>
        read <= (others => DontCareValue);
    end case;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if areset='1' then
        enabled_q<='0';
      else
        if we='1' then
          if address(2)='1' then
            divider_rx_q <= write(15 downto 0);
            enabled_q  <= write(16);
          end if;
        end if;
      end if;
    end if;
  end process;

end behave;
