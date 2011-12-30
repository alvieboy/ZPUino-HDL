library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library work;
use work.zpu_config.all;
use work.zpupkg.all;
use work.zpuinopkg.all;
use work.zpuino_config.all;

Library UNISIM;
use UNISIM.vcomponents.all;

entity zpuino_debug_spartan3e is
  port (
    jtag_data_chain_in: in std_logic_vector(97 downto 0);
    jtag_ctrl_chain_out: out std_logic_vector(9 downto 0)
  );
end entity;

architecture behave of zpuino_debug_spartan3e is

  signal DRCK1,DRCK2,CAPTURE,RESET,SHIFT,TDI,TDO1,TDO2,SEL1,SEL2,UPDATE: std_logic;

  signal dci: std_logic_vector(jtag_data_chain_in'high downto jtag_data_chain_in'low);
  signal cco: std_logic_vector(jtag_ctrl_chain_out'high downto jtag_ctrl_chain_out'low);
begin

  -- Data chain

  process(DRCK1)
  begin
    if rising_edge(DRCK1) then
      if SEL1='1' then
        if SHIFT='1' then
          dci(dci'high-1 downto dci'low) <= dci(dci'high downto dci'low+1);
          dci(dci'high)<=TDI;
        else
          -- Capture
          dci <= jtag_data_chain_in;
        end if;
      end if;
    end if;
  end process;

  TDO1 <= dci(dci'low);

  process(DRCK2)
  begin
    if rising_edge(DRCK2) then
      if SEL2='1' then
        if SHIFT='1' then
          cco(8 downto 0) <= cco(9 downto 1);
          cco(9) <= TDI;
        end if;
      end if;
    end if;
  end process;

  process(UPDATE,CAPTURE,SEL2)
  begin
    if CAPTURE='1' then
      if SEL2='1' then
        -- Reset injection
        jtag_ctrl_chain_out(1) <= '0';
      end if;
    else
    if rising_edge(UPDATE) then
      if SEL2='1' then
        jtag_ctrl_chain_out <= cco;
      end if;
    end if;
    end if;
  end process;

  TDO2 <= cco(cco'low);


BSCAN_SPARTAN3_inst: BSCAN_SPARTAN3
	port map (
      CAPTURE => CAPTURE,
			DRCK1 => DRCK1,
			DRCK2 => DRCK2,
			RESET => RESET,
			SEL1  => SEL1,
			SEL2  => SEL2,
			SHIFT => SHIFT,
			TDI   => TDI,
			UPDATE => UPDATE,
			TDO1 => TDO1,
			TDO2 => TDO2
      );

end behave;
