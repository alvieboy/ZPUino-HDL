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
    poppc_inst:in std_logic;

    ivecs:    in std_logic_vector(15 downto 0)
  );
end entity zpuino_intr;


architecture behave of zpuino_intr is

  signal mask_q: std_logic_vector(15 downto 0);
  signal intr_q: std_logic_vector(15 downto 0);
  signal ien_q: std_logic;
  signal iready_q: std_logic;
  signal interrupt_active: std_logic;
begin


process(ivecs,mask_q)
begin
  if unsigned(ivecs and mask_q)/=0 then
    interrupt_active<='1';
  else
    interrupt_active<='0';
  end if;
end process;

process(address,mask_q,ien_q,intr_q)
begin
  read <= (others => '0');
  case address is
    when "0" =>
      read(15 downto 0) <= intr_q;
    when "1" =>
      read(15 downto 0) <= mask_q;
    when others =>
  end case;
end process;

    
process(clk,areset)
  variable do_interrupt: std_logic;
begin
  if rising_edge(clk) then
    if areset='1' then
      mask_q <= (others => '1');
      ien_q <= '0';
      iready_q <= '1';
      interrupt <= '0';
      intr_q <= (others =>'0');
    else
      if we='1' then
        case address is
          when "0" =>
            ien_q <= write(0); -- Interrupt enable
            interrupt <= '0';
          when "1" =>
            mask_q <= write(15 downto 0);
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
        intr_q <= ivecs;
        ien_q <= '0';
        interrupt<='1';
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
