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

    comp:     out std_logic; -- Compare output

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
    prst: std_logic;
    intr: std_logic;
    cout: std_logic;
  end record;


signal tmr_prescale_event: std_logic;

signal r,w: regs;

begin

  interrupt <= r.intr;
  comp <= r.cout;

  busy <= '0';

  tmr0prescale_inst: prescaler
    port map (
      clk     => clk,
      rst     => r.prst,
      prescale=> r.pres,
      event   => tmr_prescale_event
    );

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
        read(6 downto 4) <= r.pres;
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


  process(we,r,write,address,tmr_prescale_event)
  begin

    w <= r;

    w.prst <= not r.en;

    if TSCENABLED then
      w.TSC <= r.TSC + 1;
    end if;

    if we='1' then
      case address is
        when "00" =>
          w.en  <= write(0);
          w.ccm <= write(1);
          w.dir <= write(2);
          w.ien <= write(3);
          w.pres<= write(6 downto 4);
          w.oce <= write(8);

          if write(7)='0' then
            w.intr <= '0';
          end if;

        when "01" =>
          w.cnt <= unsigned(write(15 downto 0));
        when "10" =>
          w.cmp <= unsigned(write(15 downto 0));
        when "11" =>
          w.oc <= unsigned(write(15 downto 0));

        when others =>
      end case;
    else
     -- Normal run

    end if;

    w.cout <= '0';

    if r.en='1' and tmr_prescale_event='1' then -- Timer enabled..
      if r.cnt=r.cmp then
        if r.ien='1' then
          w.intr <= '1';
        end if;
        w.cout <= '1';
      end if;
    end if;

    if we='0' or address/="01" then
    if r.cnt=r.cmp and r.ccm='1' then
      -- Clear on compare match
      w.cnt <= (others => '0');
    else
      -- count up or down
      if r.dir='1' then
        w.cnt <= r.cnt + 1;
      else
        w.cnt <= r.cnt - 1;
      end if;
    end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if areset='1' then
        r.en    <= '0';
        r.ccm   <= '0';
        r.dir   <= '1';
        r.ien   <= '0';
        r.oce   <= '0';
        r.cmp   <= (others => '1');
        r.pres  <= (others => '0');
        r.prst  <= '1';
        r.cnt   <= (others => '0');
        r.intr  <= '0';
        r.TSC <= (others => '0');
      else
        r <= w;
      end if;
    end if;
  end process;

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
