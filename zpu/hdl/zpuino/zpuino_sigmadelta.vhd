--
-- Sigma-delta output
--
-- Copyright 2008,2009,2010 Álvaro Lopes <alvieboy@alvie.com>
--
-- Version: 1.2
--
-- The FreeBSD license
-- 
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:
-- 
-- 1. Redistributions of source code must retain the above copyright
--    notice, this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above
--    copyright notice, this list of conditions and the following
--    disclaimer in the documentation and/or other materials
--    provided with the distribution.
-- 
-- THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY
-- EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
-- PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
-- ZPU PROJECT OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
-- INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
-- OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
-- STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
-- ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--
-- Changelog:
--
-- 1.2: Adapted from ALZPU to ZPUino
-- 1.1: First version, imported from old controller.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.zpupkg.all;
use work.zpu_config.all;
use work.zpuinopkg.all;

entity zpuino_sigmadelta is
  generic (
    BITS: integer := 16
  );
 port (
    clk:      in std_logic;
    areset:   in std_logic;
    read:     out std_logic_vector(wordSize-1 downto 0);
    write:    in std_logic_vector(wordSize-1 downto 0);
    address:  in std_logic_vector(0 downto 0);
    we:       in std_logic;
    re:       in std_logic;

    -- Connection to GPIO pin
    spp_data: out std_logic_vector(1 downto 0);
    spp_en:   out std_logic_vector(1 downto 0);

    busy:     out std_logic;
    interrupt:out std_logic
  );
end entity zpuino_sigmadelta;

architecture behave of zpuino_sigmadelta is

signal delta_adder1: unsigned(BITS+1 downto 0);
signal sigma_adder1: unsigned(BITS+1 downto 0);
signal sigma_latch1: unsigned(BITS+1 downto 0);
signal delta_b1:     unsigned(BITS+1 downto 0);

signal delta_adder2: unsigned(BITS+1 downto 0);
signal sigma_adder2: unsigned(BITS+1 downto 0);
signal sigma_latch2: unsigned(BITS+1 downto 0);
signal delta_b2:     unsigned(BITS+1 downto 0);

signal dat_q1: unsigned(BITS+1 downto 0);
signal dat_q2: unsigned(BITS+1 downto 0);

signal sd_en_q: std_logic_vector(1 downto 0);
signal sdout: std_logic_vector(1 downto 0);

signal sdtick: std_logic;
signal sdcnt: integer;

begin

  read <= (others => DontCareValue);
  interrupt <= '0';
  busy <= '0';

process(clk)
begin
  if rising_edge(clk) then
    if areset='1' then
      dat_q1 <= (others =>'0');
      dat_q1(BITS-1) <= '1';
      dat_q2 <= (others =>'0');
      dat_q2(BITS-1) <= '1';
      sd_en_q <= (others =>'0');
    else 
      if we='1' then
        case address is
          when "0" =>
            sd_en_q(0) <= write(0);
            sd_en_q(1) <= write(1);
          when "1" =>
            --report "SigmaDelta set: " & hstr(write(BITS-1 downto 0)) severity note;
            dat_q1(BITS-1 downto 0) <= unsigned(write(BITS-1 downto 0));
            dat_q2(BITS-1 downto 0) <= unsigned(write(BITS+BITS-1 downto BITS));
          when others =>
        end case;
      end if;
    end if;
  end if;
end process;

process(sigma_latch1)
begin
  delta_b1(BITS+1) <= sigma_latch1(BITS+1);
  delta_b1(BITS) <= sigma_latch1(BITS+1);
  delta_b1(BITS-1 downto 0) <= (others => '0');
end process;

process(sigma_latch2)
begin
  delta_b2(BITS+1) <= sigma_latch2(BITS+1);
  delta_b2(BITS) <= sigma_latch2(BITS+1);
  delta_b2(BITS-1 downto 0) <= (others => '0');
end process;

process(dat_q1, delta_b1)
begin
  delta_adder1 <= dat_q1 + delta_b1;
end process;

process(dat_q2, delta_b2)
begin
  delta_adder2 <= dat_q2 + delta_b2;
end process;

process(delta_adder1,sigma_latch1)
begin
  sigma_adder1 <= delta_adder1 + sigma_latch1;
end process;

process(delta_adder2,sigma_latch2)
begin
  sigma_adder2 <= delta_adder2 + sigma_latch2;
end process;

-- Divider

process(clk)
begin
  if rising_edge(clk) then
    if areset='1' then
      sdtick<='0';
      sdcnt<=3;
    else
      if sdcnt/=0 then
        sdcnt<=sdcnt-1;
        sdtick<='0';
      else
        sdtick<='1';
        sdcnt<=3;
      end if;
    end if;
  end if;
end process;

process(clk)
begin
  if rising_edge(clk) then
   if areset='1' then
      sigma_latch1 <= (others => '0');
      sigma_latch1(BITS+1) <= '1';
      sdout <= (others=>'0');
      sigma_latch2 <= (others => '0');
      sigma_latch2(BITS+1) <= '1';
   else
      if sdtick='1' then
        sigma_latch1 <= sigma_adder1;
        sigma_latch2 <= sigma_adder2;
        sdout(0) <= sigma_latch1(BITS+1);
        sdout(1) <= sigma_latch2(BITS+1);
      end if;
   end if;
  end if;
end process;

spp_data <= sdout;
spp_en <= sd_en_q;

end behave;

