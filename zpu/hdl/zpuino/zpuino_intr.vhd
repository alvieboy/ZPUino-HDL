--
--  Interrupt controller for ZPUINO
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

entity zpuino_intr is
  generic (
    INTERRUPT_LINES: integer := 16 -- MAX 32 lines
  );
  port (
    wb_clk_i: in std_logic;
	 	wb_rst_i: in std_logic;
    wb_dat_o: out std_logic_vector(wordSize-1 downto 0);
    wb_dat_i: in std_logic_vector(wordSize-1 downto 0);
    wb_adr_i: in std_logic_vector(maxIObit downto minIObit);
    wb_we_i:  in std_logic;
    wb_cyc_i: in std_logic;
    wb_stb_i: in std_logic;
    wb_ack_o: out std_logic;
    wb_inta_o:out std_logic;

    poppc_inst:in std_logic;

    cache_flush: out std_logic;
    memory_enable: out std_logic;

    intr_in:    in std_logic_vector(INTERRUPT_LINES-1 downto 0); -- edge interrupts
    intr_cfglvl: in std_logic_vector(INTERRUPT_LINES-1 downto 0) -- user-configurable interrupt level
  );
end entity zpuino_intr;


architecture behave of zpuino_intr is

  signal mask_q: std_logic_vector(INTERRUPT_LINES-1 downto 0);
  signal intr_line: std_logic_vector(31 downto 0); -- Max interrupt lines here, for priority encoder
  signal ien_q: std_logic;
  signal iready_q: std_logic;
  signal interrupt_active: std_logic;
  signal masked_ivecs: std_logic_vector(31 downto 0); -- Max interrupt lines here, for priority encoder

  signal intr_detected_q: std_logic_vector(INTERRUPT_LINES-1 downto 0);
  signal intr_in_q: std_logic_vector(INTERRUPT_LINES-1 downto 0);
  signal intr_level_q: std_logic_vector(INTERRUPT_LINES-1 downto 0);
  signal intr_served_q: std_logic_vector(INTERRUPT_LINES-1 downto 0); -- Interrupt being served

  signal memory_enable_q: std_logic;
begin



  -- Edge detector
  process(wb_clk_i)
    variable level: std_logic;
    variable not_level: std_logic;
  begin
    if rising_edge(wb_clk_i) then
      if wb_rst_i='1' then
        
      else
        for i in 0 to INTERRUPT_LINES-1 loop
          if ien_q='1' and poppc_inst='1' and iready_q='0' then -- Exiting interrupt
            if intr_served_q(i)='1' then
              intr_detected_q(i) <= '0';
            end if;
          else
            level := intr_level_q(i);
            not_level := not intr_level_q(i);
            if ( intr_in(i) = not_level and intr_in_q(i)=level) then -- edge detection
              intr_detected_q(i) <= '1';
            end if;
          end if;
        end loop;

        intr_in_q <= intr_in;

      end if;
    end if;
  end process;


  masked_ivecs(INTERRUPT_LINES-1 downto 0) <= intr_detected_q and mask_q;
  masked_ivecs(31 downto INTERRUPT_LINES) <= (others => '0');

-- Priority

intr_line <= "00000000000000000000000000000001" when masked_ivecs(0)='1' else
             "00000000000000000000000000000010" when masked_ivecs(1)='1' else
             "00000000000000000000000000000100" when masked_ivecs(2)='1' else
             "00000000000000000000000000001000" when masked_ivecs(3)='1' else
             "00000000000000000000000000010000" when masked_ivecs(4)='1' else
             "00000000000000000000000000100000" when masked_ivecs(5)='1' else
             "00000000000000000000000001000000" when masked_ivecs(6)='1' else
             "00000000000000000000000010000000" when masked_ivecs(7)='1' else
             "00000000000000000000000100000000" when masked_ivecs(8)='1' else
             "00000000000000000000001000000000" when masked_ivecs(9)='1' else
             "00000000000000000000010000000000" when masked_ivecs(10)='1' else
             "00000000000000000000100000000000" when masked_ivecs(11)='1' else
             "00000000000000000001000000000000" when masked_ivecs(12)='1' else
             "00000000000000000010000000000000" when masked_ivecs(13)='1' else
             "00000000000000000100000000000000" when masked_ivecs(14)='1' else
             "00000000000000001000000000000000" when masked_ivecs(15)='1' else
             "00000000000000010000000000000000" when masked_ivecs(16)='1' else
             "00000000000000100000000000000000" when masked_ivecs(17)='1' else
             "00000000000001000000000000000000" when masked_ivecs(18)='1' else
             "00000000000010000000000000000000" when masked_ivecs(19)='1' else
             "00000000000100000000000000000000" when masked_ivecs(20)='1' else
             "00000000001000000000000000000000" when masked_ivecs(21)='1' else
             "00000000010000000000000000000000" when masked_ivecs(22)='1' else
             "00000000100000000000000000000000" when masked_ivecs(23)='1' else
             "00000001000000000000000000000000" when masked_ivecs(24)='1' else
             "00000010000000000000000000000000" when masked_ivecs(25)='1' else
             "00000100000000000000000000000000" when masked_ivecs(26)='1' else
             "00001000000000000000000000000000" when masked_ivecs(27)='1' else
             "00010000000000000000000000000000" when masked_ivecs(28)='1' else
             "00100000000000000000000000000000" when masked_ivecs(29)='1' else
             "01000000000000000000000000000000" when masked_ivecs(30)='1' else
             "10000000000000000000000000000000" when masked_ivecs(31)='1' else
             "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX";

wb_ack_o <= wb_stb_i and wb_cyc_i;

-- Select

interrupt_active<='1' when masked_ivecs(0)='1' or
                           masked_ivecs(1)='1' or
                           masked_ivecs(2)='1' or
                           masked_ivecs(3)='1' or
                           masked_ivecs(4)='1' or
                           masked_ivecs(5)='1' or
                           masked_ivecs(6)='1' or
                           masked_ivecs(7)='1' or
                           masked_ivecs(8)='1' or
                           masked_ivecs(9)='1' or
                           masked_ivecs(10)='1' or
                           masked_ivecs(11)='1' or
                           masked_ivecs(12)='1' or
                           masked_ivecs(13)='1' or
                           masked_ivecs(14)='1' or
                           masked_ivecs(15)='1' or
                           masked_ivecs(16)='1' or
                           masked_ivecs(17)='1' or
                           masked_ivecs(18)='1' or
                           masked_ivecs(19)='1' or
                           masked_ivecs(20)='1' or
                           masked_ivecs(21)='1' or
                           masked_ivecs(22)='1' or
                           masked_ivecs(23)='1' or
                           masked_ivecs(24)='1' or
                           masked_ivecs(25)='1' or
                           masked_ivecs(26)='1' or
                           masked_ivecs(27)='1' or
                           masked_ivecs(28)='1' or
                           masked_ivecs(29)='1' or
                           masked_ivecs(30)='1' or
                           masked_ivecs(31)='1'
                           else '0';

process(wb_adr_i,mask_q,ien_q,intr_served_q,intr_cfglvl,intr_level_q)
begin
  wb_dat_o <= (others => Undefined);
  case wb_adr_i(3 downto 2) is
    when "00" =>
      --wb_dat_o(INTERRUPT_LINES-1 downto 0) <= intr_served_q;
      wb_dat_o(0) <= ien_q; 
    when "01" =>
      wb_dat_o(INTERRUPT_LINES-1 downto 0) <= mask_q;
    when "10" =>
      wb_dat_o(INTERRUPT_LINES-1 downto 0) <= intr_served_q;
    when "11" =>
      for i in 0 to INTERRUPT_LINES-1 loop
        if intr_cfglvl(i)='1' then
          wb_dat_o(i) <= intr_level_q(i);
        end if;
      end loop;
    when others =>
      wb_dat_o <= (others => DontCareValue);
  end case;
end process;

    
process(wb_clk_i,wb_rst_i)
  variable do_interrupt: std_logic;
begin
  if rising_edge(wb_clk_i) then
    if wb_rst_i='1' then
      mask_q <= (others => '0');  -- Start with all interrupts masked out
      ien_q <= '0';
      iready_q <= '1';
      wb_inta_o <= '0';
      intr_level_q<=(others =>'0');
      --intr_q <= (others =>'0');
      memory_enable<='1'; -- '1' to boot from internal bootloader
      cache_flush<='0';
    else
      cache_flush<='0';

      if wb_cyc_i='1' and wb_stb_i='1' and wb_we_i='1' then
        case wb_adr_i(4 downto 2) is
          when "000" =>
            ien_q <= wb_dat_i(0); -- Interrupt enable
            wb_inta_o <= '0';
          when "001" =>
            mask_q <= wb_dat_i(INTERRUPT_LINES-1 downto 0);
          when "011" =>
            for i in 0 to INTERRUPT_LINES-1 loop
              if intr_cfglvl(i)='1' then
                intr_level_q(i) <= wb_dat_i(i);
              end if;
            end loop;
          when "100" =>
            memory_enable <= wb_dat_i(0);
            cache_flush <= wb_dat_i(1);
          when others =>
        end case;
      end if;

      do_interrupt := '0';
      if interrupt_active='1' then
        if ien_q='1' and iready_q='1' then
          do_interrupt := '1';
        end if;
      end if;

      if do_interrupt='1' then
        intr_served_q <= intr_line(INTERRUPT_LINES-1 downto 0);
        ien_q <= '0';
        wb_inta_o<='1';
        iready_q <= '0';
      else

        if ien_q='1' and poppc_inst='1' then
          iready_q<='1';
        end if;

      end if;
    end if;
  end if;
end process;

end behave;
