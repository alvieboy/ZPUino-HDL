library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_signed.all;
use ieee.numeric_std.all;

library work;
use work.zpu_config.all;
use work.zpupkg.all;
use work.zpuinopkg.all;
use work.wishbonepkg.all;
-- synopsys translate_off
use work.txt_util.all;
-- synopsys translate_on

entity zcorev3_dbuf is
  port (
    syscon: in wb_syscon_type;
    we:     in std_logic;
    waddr:  in std_logic_vector(maxAddrBitBRAM downto 2);
    wdat:   in std_logic_vector(31 downto 0);
    raddr:  in std_logic_vector(maxAddrBitBRAM downto 2);
    re:     in std_logic;
    present: out std_logic;
    rdat:    out std_logic_vector(31 downto 0)
  );
end entity zcorev3_dbuf;

architecture behave of zcorev3_dbuf is

  type lt_type is record
    addr: std_logic_vector(waddr'RANGE);
    data: std_logic_vector(wdat'RANGE);
  end record;

  type lt_array_type is array(0 to 1) of lt_type;
  type lt_present_type is array(0 to 1) of boolean;

  signal lt: lt_array_type;
  signal lt_v: lt_present_type;
  signal curwptr: integer range 0 to 1;

  signal writing_in_slot: lt_present_type; -- same type

begin

  -- Small note: watch for DMA issues....
  ws: for i in 0 to 1 generate
    writing_in_slot(i) <= true when curwptr=i and we='1' else false;
  end generate;

  process(syscon)
  begin
    if rising_edge(syscon.clk) then
      if we='1' then
        lt(curwptr).addr <= waddr;
        lt(curwptr).data <= wdat;

        if (curwptr = 1) then
          curwptr <= 0;
        else
          curwptr <= curwptr + 1;
        end if;
      end if;
    end if;
  end process;

  process(lt,raddr)
  begin
    --if rising_edge(syscon.clk) then
      for i in 0 to 1 loop
        if lt(i).addr = raddr then
          lt_v(i) <= true;
        else
          lt_v(i) <= false;
        end if;
      end loop;
    --end if;
  end process;

  process(lt_v, re, we, waddr, raddr, lt, lt_v, curwptr, wdat, syscon.clk, writing_in_slot)
  begin
    present <= '0';
    rdat <= (others => DontCareValue);

    if re='1' then
      -- if we just wrote ....
      if we='1' and waddr=raddr then
        rdat <= wdat;
        present<='1';
        --report "Direct RW hit, address " & hstr(waddr);
      else
        case curwptr is
          when 1 =>
            if lt_v(0) then
              present<='1';
              rdat <= lt(0).data;
            elsif lt_v(1) then
              present<='1';
              rdat <= lt(1).data;
            end if;

          when 0 =>
            if lt_v(1) then
              present<='1';
              rdat <= lt(1).data;
            elsif lt_v(0) then
              present<='1';
              rdat <= lt(0).data;
            end if;
          when others =>

        end case;
      end if;
    end if;
  end process;

end behave;
