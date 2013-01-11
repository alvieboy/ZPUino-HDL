library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library work;
use work.zpu_config.all;
use work.zpupkg.all;
use work.zpuinopkg.all;
use work.wishbonepkg.all;

entity lsu is
  port (
    syscon:     in wb_syscon_type;

    mwbi:       in wb_miso_type;
    mwbo:       out wb_mosi_type;

    wbi:        in wb_mosi_type;
    wbo:        out wb_miso_type;
    tt:         in std_logic_vector(1 downto 0) -- Transaction type
  );
end lsu;


architecture behave of lsu is

  type state_type is (
    idle,
    read,
    write
  );

  type regs_type is record
    state:    state_type;
    cyc:  std_logic;
    stb:  std_logic;
    cyc_dly: std_logic;
    we:   std_logic;
    tt:   std_logic_vector(1 downto 0);
    sel:  std_logic_vector(3 downto 0);
    adr:  std_logic_vector(31 downto 0);
    dat:  std_logic_vector(31 downto 0);
    pending: std_logic;
  end record;

  signal r: regs_type;

  signal can_queue_request: std_logic;

begin

  wbo.dat <= mwbi.dat;
  wbo.ack <= mwbi.ack;

  process(syscon, wbi, mwbi, tt, r)
    variable w: regs_type;
  begin

    w:=r;

    case r.state is
          when idle =>

            can_queue_request<='1';
            mwbo.cyc  <= '0';
            mwbo.stb  <= '0';
            mwbo.adr  <= (others => DontCareValue);
            mwbo.dat  <= (others => DontCareValue);
            mwbo.we   <= DontCareValue;
            mwbo.sel  <= (others => DontCareValue);
            
          when write =>

            if r.pending='1' then
              can_queue_request <= not mwbi.stall;
            else
              can_queue_request <= '1';
            end if;

            mwbo.adr  <= r.adr;
            mwbo.dat  <= r.dat;
            mwbo.we   <= r.we;
            mwbo.sel  <= r.sel;
            mwbo.cyc  <= '1';
            mwbo.stb  <= r.pending;
            if wbi.cyc='0' then
              w.cyc_dly := '0';
            end if;

            if r.cyc_dly='0' and (r.pending='0' or mwbi.stall='0') then
              w.state := idle;
            end if;

          when read =>

            if r.pending='1' then
              can_queue_request <= not mwbi.stall;
            else
              can_queue_request <= '1';
            end if;

            mwbo.adr  <= r.adr;
            mwbo.dat  <= r.dat;
            mwbo.we   <= r.we;
            mwbo.sel  <= r.sel;
            mwbo.cyc  <= '1';
            mwbo.stb  <= r.pending;

            if wbi.cyc='0' then
              w.cyc_dly := '0';
            end if;

            if r.cyc_dly='0' and (r.pending='0' or mwbi.stall='0') then--r.pending='0' then
              w.state := idle;
            end if;

          when others =>
    end case;

    wbo.stall <= not can_queue_request;

    if can_queue_request='1' then
      if wbi.cyc='1' and wbi.stb='1' then
        w.adr := wbi.adr;
        w.dat := wbi.dat;
        w.we  := wbi.we;
        w.sel := wbi.sel;
        w.pending := '1';
        w.cyc_dly := wbi.cyc;

        if r.state=idle then
          if wbi.we='1' then
            w.state := write;
           else
            w.state := read;
          end if;
        end if;

      else
        w.pending := '0';
      end if;
    end if;

    if syscon.rst='1' then
      w.pending := '0';
      w.cyc := '0';
      w.stb := DontCareValue;
      w.adr := (others =>DontCareValue);
      w.dat := (others =>DontCareValue);
      w.sel := (others =>DontCareValue);
      w.we  := DontCareValue;
      w.state := idle;
      w.tt := (others => DontCareValue);
    end if;

    if rising_edge(syscon.clk) then
      r<=w;
    end if;
  end process;
end behave;
