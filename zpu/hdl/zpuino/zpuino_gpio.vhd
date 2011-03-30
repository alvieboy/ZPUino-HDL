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
use IEEE.std_logic_unsigned.all; 

library work;
use work.zpu_config.all;
use work.zpupkg.all;
use work.zpuinopkg.all;
use work.zpuino_config.all;

entity zpuino_gpio is
  generic (
    gpio_count: integer := 32
  );
  port (
    clk:      in std_logic;
	 	areset:   in std_logic;
    read:     out std_logic_vector(wordSize-1 downto 0);
    write:    in std_logic_vector(wordSize-1 downto 0);
    address:  in std_logic_vector(8 downto 0);
    we:       in std_logic;
    re:       in std_logic;
    busy:     out std_logic;
    interrupt:out std_logic;
    spp_data: in std_logic_vector(gpio_count-1 downto 0);
    spp_read: out std_logic_vector(gpio_count-1 downto 0);
    spp_en:   in std_logic_vector(gpio_count-1 downto 0);
    gpio_o:   out std_logic_vector(gpio_count-1 downto 0);
    gpio_t:   out std_logic_vector(gpio_count-1 downto 0);
    gpio_i:   in std_logic_vector(gpio_count-1 downto 0);

    spp_cap_in:  in std_logic_vector(gpio_count-1 downto 0); -- SPP capable pin for INPUT
    spp_cap_out:  in std_logic_vector(gpio_count-1 downto 0) -- SPP capable pin for OUTPUT
  );
end entity zpuino_gpio;


architecture behave of zpuino_gpio is

signal gpio_q:        std_logic_vector(127 downto 0); -- GPIO output data FFs
signal gpio_tris_q:   std_logic_vector(127 downto 0); -- Tristate FFs

subtype input_number is integer range 0 to 127;
type mapper_q_type is array(0 to 127) of input_number;

signal input_mapper_q:  mapper_q_type; -- Mapper for output pins (input data)
signal output_mapper_q: mapper_q_type; -- Mapper for input pins (output data)

signal gpio_r_i:        std_logic_vector(127 downto 0);
signal gpio_tris_r_i:    std_logic_vector(127 downto 0);
signal gpio_i_q: std_logic_vector(127 downto 0);

begin

busy <= '0';
interrupt <= '0';

gpio_t <= gpio_tris_q(gpio_count-1 downto 0);

tgen: for i in 0 to gpio_count-1 generate

  process( gpio_q(i), spp_en, input_mapper_q(i), spp_data,clk,spp_cap_out )
    variable pin_index: integer;
  begin
    if zpuino_pps_enabled then
      pin_index := input_mapper_q(i);
    else
      pin_index := i;
    end if;
    if rising_edge(clk) then -- synchronous output

      -- Enforce RST on gpio_o
      if areset='1' then
        gpio_o(i)<='0';
      else
      if zpuino_pps_enabled then
        -- Zero maps to own GPIO port.

        if pin_index=0 or spp_cap_out(i) = '0' then
          gpio_o(i) <= gpio_q(i);
        else
          gpio_o(i) <= spp_data(pin_index-1); -- Offset -1
        end if;

      else
        -- PPS disabled, map directly to pin
        if spp_en( i )='1' and spp_cap_out(i)='0' then
          gpio_o(i) <= spp_data(i);
        else
          gpio_o(i) <= gpio_q(i);
        end if;

      end if;
      end if;
    end if;
  end process;

  process( gpio_i_q(i), gpio_i(i), output_mapper_q(i),clk,spp_cap_in )
    variable pin_index: integer;
  begin
    if zpuino_pps_enabled and spp_cap_in(i)='1' then
      pin_index := output_mapper_q(i);
    else
      pin_index := i;
    end if;
    spp_read(i) <= gpio_i_q(pin_index);
  end process;

  process(clk, gpio_i(i))
  begin
    -- This actually causes some trouble due to IOB FF delay.
--    if rising_edge(clk) then
      gpio_i_q(i) <= gpio_i(i);
--    end if;
  end process;

end generate;


ilink1: for i in 0 to gpio_count-1 generate
  gpio_r_i(i) <= gpio_i_q(i);
  gpio_tris_r_i(i) <= gpio_tris_q(i);
end generate;

ilink2: for i in gpio_count to 127 generate
  gpio_r_i(i) <= DontCareValue;
  gpio_tris_r_i(i) <= DontCareValue;
end generate;


process(address,gpio_r_i,gpio_tris_r_i)
begin
  case address(2) is
    when '0' =>

      case address(1 downto 0) is
        when "00" =>
          read <= gpio_r_i(31 downto 0);  
        when "01" =>
          read <= gpio_r_i(63 downto 32);
        when "10" =>
          read <= gpio_r_i(95 downto 64);
        when "11" =>
          read <= gpio_r_i(127 downto 96);
        when others =>
      end case;

    when '1' =>
      case address(1 downto 0) is
        when "00" =>
          read <= gpio_tris_r_i(31 downto 0);
        when "01" =>
          read <= gpio_tris_r_i(63 downto 32);
        when "10" =>
          read <= gpio_tris_r_i(95 downto 64);
        when "11" =>
          read <= gpio_tris_r_i(127 downto 96);
        when others =>
      end case;
    when others =>
      read <= (others => DontCareValue);
  end case;
end process;

process(clk)
begin
  if rising_edge(clk) then
    if areset='1' then
      gpio_tris_q <= (others => '1');
      gpio_q <= (others => DontCareValue);
      -- Default values for input/output mapper
      for i in 0 to 127 loop
        input_mapper_q(i) <= 0;
        output_mapper_q(i) <= 0;
      end loop;
    elsif we='1' then
      case address(8 downto 7) is
        when "00" =>
          case address(2) is
            when '0' =>
              case address(1 downto 0) is
                when "00" =>
                  gpio_q(31 downto 0) <= write;
                when "01" =>
                  gpio_q(63 downto 32) <= write;
                when "10" =>
                  gpio_q(95 downto 64) <= write;
                when "11" =>
                  gpio_q(127 downto 96) <= write;
                when others =>
              end case;
            when '1' =>
              case address(1 downto 0) is
                when "00" =>
                  gpio_tris_q(31 downto 0) <= write;
                when "01" =>
                  gpio_tris_q(63 downto 32) <= write;
                when "10" =>
                  gpio_tris_q(95 downto 64) <= write;
                when "11" =>
                  gpio_tris_q(127 downto 96) <= write;
                when others =>
              end case;
            when others =>
          end case;
        when "01" =>
          if zpuino_pps_enabled then
            input_mapper_q( conv_integer(address(6 downto 0)) ) <= conv_integer(write(6 downto 0));
          end if;
        when "10" =>
          if zpuino_pps_enabled then
            output_mapper_q( conv_integer(address(6 downto 0)) ) <= conv_integer(write(6 downto 0));
          end if;
        when others =>
      end case;
    end if;
  end if;
end process;

end behave;

