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

entity zpuino_debug_spartan6 is
  port (
    jtag_data_chain_in: in std_logic_vector(97 downto 0);
    jtag_ctrl_chain_out: out std_logic_vector(9 downto 0)
  );
end entity;

architecture behave of zpuino_debug_spartan6 is

  signal DRCK1,DRCK2,SHIFT1,SHIFT2,TDI1,TDI2,TDO1,TDO2,SEL1,SEL2,UPDATE1,UPDATE2,CAPTURE2: std_logic;
  signal dci: std_logic_vector(jtag_data_chain_in'high downto jtag_data_chain_in'low);
  signal cco: std_logic_vector(jtag_ctrl_chain_out'high downto jtag_ctrl_chain_out'low);

begin

  -- Data chain

  process(DRCK1)
  begin
    if rising_edge(DRCK1) then
      if SEL1='1' then
        if SHIFT1='1' then
          dci(dci'high-1 downto dci'low) <= dci(dci'high downto dci'low+1);
          dci(dci'high)<=TDI1;
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
        if SHIFT2='1' then
          cco(8 downto 0) <= cco(9 downto 1);
          cco(9) <= TDI2;
        end if;
      end if;
    end if;
  end process;

  process(UPDATE2,CAPTURE2,SEL2)
  begin
    if CAPTURE2='1' then
      if SEL2='1' then
        -- Reset injection
        jtag_ctrl_chain_out(1) <= '0';
      end if;
    else
    if rising_edge(UPDATE2) then
      if SEL2='1' then
        jtag_ctrl_chain_out <= cco;
      end if;
    end if;
    end if;
  end process;

  TDO2 <= cco(cco'low);



BSCAN_SPARTAN6_inst1 : BSCAN_SPARTAN6
generic map (
  JTAG_CHAIN => 1 -- Chain number.
)
port map (
  CAPTURE => open,
  DRCK => DRCK1,
  RESET => open,
  RUNTEST => open,
  SEL => SEL1,
  SHIFT => SHIFT1,
  TCK => open,
  TDI => TDI1,
  TMS => open,
  UPDATE => UPDATE1,
  TDO => TDO1
);

BSCAN_SPARTAN6_inst2 : BSCAN_SPARTAN6
generic map (
  JTAG_CHAIN => 2 -- Chain number.
)
port map (
  CAPTURE => open, -- 1-bit Scan Data Register Capture instruction.
  DRCK => DRCK2, -- 1-bit Scan Clock instruction. DRCK is a gated version of TCTCK, it toggles during
  -- the CAPTUREDR and SHIFTDR states.
  RESET => open, -- 1-bit Scan register reset instruction.
  RUNTEST => open,--RUNTEST, -- 1-bit Asserted when TAP controller is in Run Test Idle state. Make sure is the
  -- same name as BSCAN primitive used in Spartan products.
  SEL => SEL2, -- 1-bit Scan mode Select instruction.
  SHIFT => SHIFT2, -- 1-bit Scan Chain Shift instruction.
  TCK => open, -- 1-bit Scan Clock. Fabric connection to TAP Clock pin.
  TDI => TDI2, -- 1-bit Scan Chain Output. Mirror of TDI input pin to FPGA.
  TMS => open, -- 1-bit Test Mode Select. Fabric connection to TAP.
  UPDATE => UPDATE2, -- 1-bit Scan Register Update instruction.
  TDO => TDO2 -- 1-bit Scan Chain Input.
);

end behave;
