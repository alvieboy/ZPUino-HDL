--
--  GPIO for ZPUINO
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

entity zpuino_gpio is
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
    spp_data: in std_logic_vector(31 downto 0);
    spp_en:   in std_logic_vector(31 downto 0);
    gpio:     inout std_logic_vector(31 downto 0)
  );
end entity zpuino_gpio;


architecture behave of zpuino_gpio is

signal gpio_q: std_logic_vector(31 downto 0);
signal gpio_i: std_logic_vector(31 downto 0);
signal gpio_tris_q: std_logic_vector(31 downto 0);

begin

tgen: for i in 0 to 31 generate
  gpio_i(i) <= gpio_q(i) when spp_en(i)='0' else spp_data(i);

  gpio(i) <= gpio_i(i) when gpio_tris_q(i)='0' else 'Z';
end generate;

process(address,gpio,gpio_tris_q)
begin
  read <= (others => '0');
  case address is
    when "0" =>
      read <= gpio;
    when "1" =>
      read <= gpio_tris_q;
    when others =>
  end case;
end process;

process(clk)
begin
  if rising_edge(clk) then
    if areset='1' then
      gpio_tris_q <= (others => '1');
    elsif we='1' then
      case address is
        when "0" =>
          gpio_q <= write;
        when "1" =>
          gpio_tris_q <= write;
        when others =>
      end case;
    end if;
  end if;
end process;

end behave;

