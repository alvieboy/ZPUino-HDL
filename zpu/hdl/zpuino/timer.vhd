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
    clk:      in std_logic;
	 	areset:   in std_logic;
    read:     out std_logic_vector(wordSize-1 downto 0);
    write:    in std_logic_vector(wordSize-1 downto 0);
    address:  in std_logic_vector(1 downto 0);
    we:       in std_logic;
    re:       in std_logic;
    -- Connection to GPIO pin
    spp_data: out std_logic;
    spp_en:   out std_logic;

    busy:     out std_logic;
    interrupt:out std_logic
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


  type regs is record
    cnt:  unsigned(15 downto 0);
    cmp:  unsigned(15 downto 0);
    oc:   unsigned(15 downto 0);
    en:   std_logic;
    dir:  std_logic;
    ccm:  std_logic;
    ien:  std_logic;
    oce:  std_logic;
    TSC:  unsigned(wordSize-1 downto 0);
    pres: std_logic_vector(2 downto 0);
    intr: std_logic;
  end record;


signal tmr_prescale_rst: std_logic;
signal tmr_prescale_event: std_logic;

signal r,w: regs;

begin

  interrupt <= r.intr;
  busy <= '0';

  tmr0prescale_inst: prescaler
    port map (
      clk     => clk,
      rst     => tmr0_prescale_rst,
      prescale=> r.pres,
      event   => tmr0_prescale_event
    );

  tsc_process: if TSCENABLED generate
  TSCgen: process(clk)
  begin
    if rising_edge(clk) then
      if areset='1' then
        w.TSC <= (others => '0');
      else
        w.TSC <= w.TSC + 1;
      end if;
    end if;
  end process;
  end generate;

  -- Read
  process(address,r)
  begin
    read <= (others => '0');
    case address is
      when "00" =>
        read(0) <= r.en;
        read(1) <= r.ccm;
        read(2) <= r.dir;
        read(3) <= r.ien;
        read(6 downto 4) <= r.prescale;
        read(7) <= r.intr;
        read(8) <= r.oce;
      when "01" =>
        read(15 downto 0) <= std_logic_vector(r.cnt);
      when "10" =>
        read(15 downto 0) <= std_logic_vector(r.cmp);
      when others =>
        if TSCENABLED then
          read <= std_logic_vector(r.TSC);
        else
          read <= (others => DontCareValue );
        end if;
    end case;
  end process;


  process(clk)
  begin
    if rising_edge(clk) then
      if areset='1' then

        r.en    <= '0';
        r.ccm   <= '0';
        r.dir_q <= '1';
        r.ien_q <= '0';
        r.oce_q <= '0';
        r.cmp_q <= (others => '1');
        r.pres  <= (others => '0');

        prescale_rst <= '1';
      else

        tmr0_prescale_rst <= not r.en;

        w <= r;

        if we='1' then
          case address is
            when "00" =>
              w.en  <= write(0);
              w.ccm <= write(1);
              w.dir <= write(2);
              w.ien <= write(3);
              w.pres<= write(6 downto 4);
              w.oce <= write(8);
            when "10" =>
              w.cmp <= unsigned(write(15 downto 0));
            when "11" =>
              w.oc <= unsigned(write(15 downto 0));

            when others =>
          end case;
        end if;
      end if;
    end if;
  end process;

  -- Timer 0 count
  process(clk)
  begin
    if rising_edge(clk) then
      if areset='1' then
        tmr0_cnt_q <= (others => '0');
        tmr0_intr <= '0';
      else
        if we='1' and address="01" then
          tmr0_cnt_q <= unsigned(write(15 downto 0));
        else
          if we='1' and address="00" then
            if write(7)='0' then
              tmr0_intr <= '0';
            end if;
          end if;
          if tmr0_en_q='1' and tmr0_prescale_event='1' then -- Timer enabled..
            if tmr0_cnt_q=tmr0_cmp_q then
              if tmr0_ien_q='1' then
                tmr0_intr <= '1';
              end if;

              tmr0_output_compare0 <= '1';
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

  process(clk)
  begin
    if rising_edge(clk) then
      if r.oc >= r.cnt then
        spp_data <= '1';
      else
        spp_data <= '0';
      end if;
    end if;
  end process;

  spp_en <= r.oce; -- Output compare enable

end behave;
