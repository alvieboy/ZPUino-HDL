library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.all;

use ieee.numeric_std.all;

library work;
use work.zpu_config.all;
use work.zpupkg.all;
use work.zpuinopkg.all;
use work.wishbonepkg.all;
-- synopsys translate_off
use work.txt_util.all;
-- synopsys translate_on

entity rdcache is
  generic (
      ADDRESS_HIGH: integer := 26;
      CACHE_MAX_BITS: integer := 18; -- 8 Kb
      CACHE_LINE_SIZE_BITS: integer := 6 -- 64 bytes
  );
  port (
    syscon:     in wb_syscon_type;
    ci:         in dcache_in_type;
    co:         out dcache_out_type;
    mwbi:       in wb_miso_type;
    mwbo:       out wb_mosi_type
  );
end rdcache;

architecture behave of rdcache is

  signal wci: dcache_in_type;
  signal wco: dcache_out_type;
  
begin

  -- Objective: delay

  cache: zpuino_dcache
  generic map (
      ADDRESS_HIGH          => ADDRESS_HIGH,
      CACHE_MAX_BITS        => CACHE_MAX_BITS,
      CACHE_LINE_SIZE_BITS  => CACHE_LINE_SIZE_BITS
  )
  port map (
    syscon  => syscon,
    ci      => wci,
    co      => wco,
    mwbi    => mwbi,
    mwbo    => mwbo
  );

end behave;
