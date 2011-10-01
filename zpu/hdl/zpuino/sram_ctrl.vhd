library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

library work;
use work.zpu_config.all;
use work.zpuino_config.all;
use work.zpuinopkg.all;
use work.zpupkg.all;

entity sram_ctrl is
  port (
    wb_clk_i: in std_logic;
	 	wb_rst_i: in std_logic;

    wb_dat_o: out std_logic_vector(31 downto 0);
    wb_dat_i: in std_logic_vector(31 downto 0);
    wb_adr_i: in std_logic_vector(maxIOBit downto minIOBit);
--    wb_sel_i: in std_logic_vector(3 downto 0);
--    wb_cti_i: in std_logic_vector(2 downto 0);
    wb_we_i:  in std_logic;
    wb_cyc_i: in std_logic;
    wb_stb_i: in std_logic;
    wb_ack_o: out std_logic;

    -- SRAM signals
    sram_addr:  out std_logic_vector(17 downto 0);
    sram_data:  inout std_logic_vector(15 downto 0);
    sram_ce:    out std_logic;
    sram_we:    out std_logic;
    sram_oe:    out std_logic;
    sram_be:    out std_logic
  );
end entity sram_ctrl;


architecture behave of sram_ctrl is

signal sram_data_write: std_logic_vector(15 downto 0);
--signal sram_data_read: std_logic_vector(15 downto 0);

type state_type is (
  idle,
  operation,
  finish
);

signal state: state_type;

begin

sram_be <= '0';
--sram_ce <= not wb_cyc_i;
--sram_we <= not wb_we_i when state=operation else '1';
--sram_oe <= wb_we_i;



sram_data <= sram_data_write when wb_we_i='1' and wb_cyc_i='1' else (others => 'Z');

wb_dat_o(15 downto 0) <= sram_data;
wb_dat_o(31 downto 16) <= (others => '0');
sram_addr <= wb_adr_i(19 downto 2);

process(wb_clk_i)
begin
  if rising_edge(wb_clk_i) then
    if wb_rst_i='1' then
      wb_ack_o <= '0';
      state <= idle;
      sram_we <= '1';
      sram_ce <= '1';
      sram_oe <= '1';
    else

      wb_ack_o <= '0';
      case state is
        when idle =>
          if wb_cyc_i='1' and wb_stb_i='1' then

            --sram_addr <= wb_adr_i(19 downto 2);
            sram_data_write <= wb_dat_i(15 downto 0);
            sram_we <= not wb_we_i;
            sram_oe <= wb_we_i;
            sram_ce <= '0';

            state <= operation;
          end if;
        when operation =>
          wb_ack_o<='1';
          sram_we <= '1';
          state <= finish;
        when finish =>
          state <= idle;
          sram_we <= '1';
          sram_oe <= '1';
          sram_ce <= '1';
        when others =>
      end case;
    end if;
  end if;
end process;


end behave;
