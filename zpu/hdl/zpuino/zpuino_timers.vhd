--
--  Timers for ZPUINO
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

entity zpuino_timers is
  port (
    clk:      in std_logic;
	 	areset:   in std_logic;
    read:     out std_logic_vector(wordSize-1 downto 0);
    write:    in std_logic_vector(wordSize-1 downto 0);
    address:  in std_logic_vector(maxIObit downto minIObit);
    we:       in std_logic;
    re:       in std_logic;
    spp_data: out std_logic_vector(1 downto 0);
    spp_en:   out std_logic_vector(1 downto 0);
    busy:     out std_logic;
    comp:     out std_logic;
    interrupt0:out std_logic;
    interrupt1:out std_logic
  );
end entity zpuino_timers;


architecture behave of zpuino_timers is

  component timer is
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

    comp:     out std_logic;

    busy:     out std_logic;
    interrupt:out std_logic
  );
  end component timer;

  signal timer0_read:       std_logic_vector(wordSize-1 downto 0);
  signal timer0_re:         std_logic;
  signal timer0_we:         std_logic;
  signal timer0_interrupt:  std_logic;
  signal timer0_busy:       std_logic;
  signal timer0_comp:       std_logic;
  signal timer0_spp_data:   std_logic;
  signal timer0_spp_en  :   std_logic;

  signal timer1_read:       std_logic_vector(wordSize-1 downto 0);
  signal timer1_re:         std_logic;
  signal timer1_we:         std_logic;
  signal timer1_interrupt:  std_logic;
  signal timer1_busy:       std_logic;
  signal timer1_spp_data:   std_logic;
  signal timer1_spp_en  :   std_logic;

begin

  interrupt0 <= timer0_interrupt;
  interrupt1 <= timer1_interrupt;

  comp <= timer0_comp;

  timer0_inst: timer
    generic map (
      TSCENABLED => true
    )
    port map (
      clk     => clk,
      areset  => areset,
      read    => timer0_read,
      write   => write,
      address => address(3 downto 2),
      re      => timer0_re,
      we      => timer0_we,
      spp_data=> timer0_spp_data,
      spp_en  => timer0_spp_en,
      busy    => timer0_busy,
      comp    => timer0_comp,
      interrupt=>timer0_interrupt
    );

  timer1_inst: timer
    port map (
      clk     => clk,
      areset  => areset,
      read    => timer1_read,
      write   => write,
      address => address(3 downto 2),
      re      => timer1_re,
      we      => timer1_we,
      spp_data=> timer1_spp_data,
      spp_en  => timer1_spp_en,
      busy    => timer1_busy,
      interrupt=>timer1_interrupt
    );


  process(address,timer0_read,timer1_read)
  begin
    read <= (others => '0');
    case address(4) is
      when '0' =>
        read <= timer0_read;
      when '1' =>
        read <= timer1_read;
      when others =>
        read <= (others => DontCareValue);
    end case;
  end process;

  timer0_re <= '1' when address(4)='0' and re='1' else '0';
  timer1_re <= '1' when address(4)='1' and re='1' else '0';

  timer0_we <= '1' when address(4)='0' and we='1' else '0';
  timer1_we <= '1' when address(4)='1' and we='1' else '0';

  busy <= timer0_busy or timer1_busy;
  
  spp_data(0) <= timer0_spp_data;
  spp_data(1) <= timer1_spp_data;

  spp_en(0) <= timer0_spp_en;
  spp_en(1) <= timer1_spp_en;

end behave;
