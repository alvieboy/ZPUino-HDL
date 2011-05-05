--
--  16-bit Timer for ZPUINO
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
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library work;
use work.zpu_config.all;
use work.zpupkg.all;
use work.zpuinopkg.all;

entity timer is
  generic (
    TSCENABLED: boolean := false
  );
  port (
    wb_clk_i:      in std_logic;
	 	wb_rst_i:   in std_logic;
    wb_dat_o:     out std_logic_vector(wordSize-1 downto 0);
    wb_dat_i:    in std_logic_vector(wordSize-1 downto 0);
    wb_adr_i:  in std_logic_vector(1 downto 0);
    wb_we_i:       in std_logic;
    wb_cyc_i:       in std_logic;
    wb_stb_i:       in std_logic;
    wb_ack_o:       out std_logic;
    wb_inta_o:      out std_logic;
    -- Connection to GPIO pin
    spp_data: out std_logic;
    spp_en:   out std_logic;

    comp:     out std_logic -- Compare output
  );
end entity timer;

architecture behave of timer is

  component prescaler is
  port (
    clk:    in std_logic;
    rst:    in std_logic;
    prescale:   in std_logic_vector(2 downto 0);
    event:  out std_logic                       
  );
  end component prescaler;

signal tmr0_cnt_q: unsigned(15 downto 0);
signal tmr0_cmp_q: unsigned(15 downto 0);
signal tmr0_oc_q: unsigned(15 downto 0);
signal tmr0_en_q: std_logic;
signal tmr0_dir_q: std_logic;
signal tmr0_ccm_q: std_logic;
signal tmr0_ien_q: std_logic;
signal tmr0_oce_q: std_logic;
signal tmr0_intr:  std_logic;
signal tmr0_cout:  std_logic;

signal tmr0_prescale_rst: std_logic;
signal tmr0_prescale: std_logic_vector(2 downto 0);
signal tmr0_prescale_event: std_logic;

signal TSC_q: unsigned(wordSize-1 downto 0);

begin

  wb_inta_o <= tmr0_intr;
  comp <= tmr0_cout;

  wb_ack_o <= wb_cyc_i and wb_stb_i;

  tmr0prescale_inst: prescaler
    port map (
      clk     => wb_clk_i,
      rst     => tmr0_prescale_rst,
      prescale=> tmr0_prescale,
      event   => tmr0_prescale_event
    );

  tsc_process: if TSCENABLED generate
  TSCgen: process(wb_clk_i)
  begin
    if rising_edge(wb_clk_i) then
      if wb_rst_i='1' then
        TSC_q <= (others => '0');
      else
        TSC_q <= TSC_q + 1;
      end if;
    end if;
  end process;
  end generate;

  -- Read
  process(wb_adr_i,tmr0_en_q, tmr0_ccm_q, tmr0_dir_q,tmr0_ien_q, tmr0_cnt_q,tmr0_cmp_q,tmr0_prescale,tmr0_intr,TSC_q,tmr0_oce_q)
  begin
    wb_dat_o <= (others => '0');
    case wb_adr_i is
      when "00" =>
        wb_dat_o(0) <= tmr0_en_q;
        wb_dat_o(1) <= tmr0_ccm_q;
        wb_dat_o(2) <= tmr0_dir_q;
        wb_dat_o(3) <= tmr0_ien_q;
        wb_dat_o(6 downto 4) <= tmr0_prescale;
        wb_dat_o(7) <= tmr0_intr;
        wb_dat_o(8) <= tmr0_oce_q;
      when "01" =>
        wb_dat_o(15 downto 0) <= std_logic_vector(tmr0_cnt_q);
      when "10" =>
        wb_dat_o(15 downto 0) <= std_logic_vector(tmr0_cmp_q);
      when others =>
        if TSCENABLED then
          wb_dat_o <= std_logic_vector(TSC_q);
        else
          wb_dat_o <= (others => DontCareValue );
        end if;
    end case;
  end process;


  process(wb_clk_i)
  begin
    if rising_edge(wb_clk_i) then
      if wb_rst_i='1' then
        tmr0_en_q <= '0';
        tmr0_ccm_q <= '0';
        tmr0_dir_q <= '1';
        tmr0_ien_q <= '0';
        tmr0_oce_q <= '0';
        tmr0_cmp_q <= (others => '1');
        tmr0_prescale <= (others => '0');
        tmr0_prescale_rst <= '1';
      else
        tmr0_prescale_rst <= not tmr0_en_q;
        if wb_we_i='1' then
          case wb_adr_i is
            when "00" =>
              tmr0_en_q <= wb_dat_i(0);
              tmr0_ccm_q <= wb_dat_i(1);
              tmr0_dir_q <= wb_dat_i(2);
              tmr0_ien_q <= wb_dat_i(3);
              tmr0_prescale <= wb_dat_i(6 downto 4);
              tmr0_oce_q <= wb_dat_i(8);
              --tmr0_prescale_rst <= '1';
            when "10" =>
              tmr0_cmp_q <= unsigned(wb_dat_i(15 downto 0));
            when "11" =>
              tmr0_oc_q <= unsigned(wb_dat_i(15 downto 0));

            when others =>
          end case;
        end if;
      end if;
    end if;
  end process;

  -- Timer 0 count
  process(wb_clk_i)
  begin
    if rising_edge(wb_clk_i) then
      if wb_rst_i='1' then
        tmr0_cnt_q <= (others => '0');
        tmr0_intr <= '0';
        tmr0_cout <= '0';
      else
        if wb_we_i='1' and wb_adr_i="01" then
          tmr0_cnt_q <= unsigned(wb_dat_i(15 downto 0));
        else
          if wb_we_i='1' and wb_adr_i="00" then
            if wb_dat_i(7)='0' then
              tmr0_intr <= '0';
            end if;
          end if;

          tmr0_cout <= '0';

          if tmr0_en_q='1' and tmr0_prescale_event='1' then -- Timer enabled..
            if tmr0_cnt_q=tmr0_cmp_q then
              if tmr0_ien_q='1' then
                tmr0_intr <= '1';
              end if;
              tmr0_cout <= '1';
            end if;

            if tmr0_cnt_q=tmr0_cmp_q and tmr0_ccm_q='1' then
                -- Clear on compare match
              tmr0_cnt_q<=(others => '0');
            else
              -- count up or down

                if tmr0_dir_q='1' then
                  tmr0_cnt_q <= tmr0_cnt_q + 1;
                else
                  tmr0_cnt_q <= tmr0_cnt_q - 1;
                end if;
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;

  -- Output compare ( synchronous )

  process(wb_clk_i)
  begin
    if rising_edge(wb_clk_i) then
      if tmr0_oc_q >= tmr0_cnt_q then
        spp_data <= '1';
      else
        spp_data <= '0';
      end if;
    end if;
  end process;

  spp_en <= tmr0_oce_q; -- Output compare enable

end behave;
