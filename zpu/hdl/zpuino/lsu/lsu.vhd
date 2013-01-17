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
    running,
    writebackwc1,
    writebackwc2
  );

  constant wc_queue_depth_bits: integer := 8;
  constant wc_queue_depth: integer := 2**(wc_queue_depth_bits);
  constant wc_queue_delay: integer := 256;

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
    wcindex: unsigned(wc_queue_depth_bits downto 0);
    wcwb:    unsigned(wc_queue_depth_bits downto 0);
    wctimer: integer;
  end record;

  signal r: regs_type;
  signal ram_ena: std_logic;
  signal ram_wea: std_logic;

  constant ramsizebits: integer := 68;

  signal ram_dia, ram_doa: std_logic_vector(ramsizebits-1 downto 0);

  signal ram_addra: std_logic_vector(wc_queue_depth_bits-1 downto 0);

begin

  wcmem: generic_sp_ram
    generic map (
      address_bits => wc_queue_depth_bits,
      data_bits => ramsizebits
    )
    port map (
      clka  => syscon.clk,
      ena   => ram_ena,
      wea   => ram_wea,
      addra => ram_addra,
      dia   => ram_dia,
      doa   => ram_doa
    );

  wbo.dat <= mwbi.dat;

  -- WC state

  ram_dia <= r.sel & r.adr & r.dat;

  process(syscon, wbi, mwbi, tt, r, ram_doa)
    variable w: regs_type;
    variable wc_push: boolean;
    variable can_queue_request: std_logic;
    variable wc_has_data: boolean;
    variable iswc: boolean;
  begin

    w:=r;
    wc_push := false;
    can_queue_request := '0';
    ram_ena <= '1';
    ram_wea <= '0';
    ram_addra <= std_logic_vector( r.wcindex(wc_queue_depth_bits-1 downto 0) );

    mwbo.cyc  <= '0';
    mwbo.stb  <= '0';--DontCareValue;
    mwbo.adr  <= (others => '0');--DontCareValue);
    mwbo.dat  <= (others => DontCareValue);
    mwbo.we   <= '0';--DontCareValue;
    mwbo.sel  <= (others => DontCareValue);

    -- This can be a FF
    if r.wcindex=0 then
      wc_has_data:=false;
    else
      wc_has_data:=true;
    end if;

    case r.state is

          when running =>

            if r.tt="11" and (r.we='1' or wc_has_data) then
              iswc:=true;
            else
              iswc:=false;
            end if;

            if r.pending='1' then
              if iswc=false  then
                can_queue_request := not mwbi.stall;
              else
                can_queue_request := '1';
              end if;
            else
              can_queue_request := '1';
            end if;

            mwbo.cyc  <= w.cyc_dly;
            w.wcwb := (others => '0');

            if r.pending='1' then
              w.cyc_dly := '1';
              if iswc=false  then
                mwbo.cyc  <= w.cyc_dly;
                mwbo.stb  <= '1';
                mwbo.adr  <= r.adr;
                mwbo.dat  <= r.dat;
                mwbo.we   <= r.we;
                mwbo.sel  <= r.sel;
              else
                -- Memory / Writeback
                if r.we='1' then
                w.wcindex := r.wcindex + 1;
                if r.wcindex(wc_queue_depth_bits)='0' then
                  ram_ena<='1';
                  ram_wea<='1';
                  w.wcindex := r.wcindex + 1;
                  ram_addra <= std_logic_vector( r.wcindex(wc_queue_depth_bits-1 downto 0) );
                else
                  -- Overflow, need to perform wb
                  w.state := writebackwc1;
                  can_queue_request := '0';
                end if;
                else
                  -- Need WB first
                  w.state := writebackwc1;
                  can_queue_request := '0';
                end if;

              end if;
            end if;

            if wbi.cyc='0' then
              wbo.ack <= '0';
              w.cyc_dly := '0';
            else
              wbo.ack <= mwbi.ack;
            end if;


          when writebackwc1 =>
            
            can_queue_request := '0';--not r.pending;  -- Don't allow queuing requests now.
            ram_addra <= std_logic_vector(r.wcwb(wc_queue_depth_bits-1 downto 0));
            ram_ena<='1';
            w.state := writebackwc2;
            w.wcwb := r.wcwb + 1;
            wbo.ack <= '0';

            mwbo.cyc  <= '0';
            mwbo.stb  <= '0';--DontCareValue;
            mwbo.adr  <= (others => DontCareValue);
            mwbo.dat  <= (others => DontCareValue);
            mwbo.we   <= '0';--DontCareValue;
            mwbo.sel  <= (others => DontCareValue);

          when writebackwc2 =>

            can_queue_request := '0';--not r.pending;  -- Don't allow queuing requests now.

            mwbo.cyc <= '1';
            mwbo.stb <= '1';
            mwbo.dat <= ram_doa(31 downto 0);
            mwbo.adr <= ram_doa(63 downto 32);
            mwbo.sel <= ram_doa(67 downto 64);
            wbo.ack <= '0';

            ram_addra <= std_logic_vector(r.wcwb(wc_queue_depth_bits-1 downto 0));

            ram_ena <= not mwbi.stall;--'1';
            mwbo.we <= '1';

            if mwbi.stall='0' then
              w.wcwb := r.wcwb + 1;
              if r.wcwb = r.wcindex then

                w.wcindex := (others =>'0');
                w.state := running;
                -- Move this out of here, we should reset can_queue_request instead
                --if r.pending='1' then
                -- - if r.we='1' then
                --    if r.tt="11" then
                --      w.state := writecombine;
                --    else
                --      w.state := direct;
                --   end if;
                --  else
                --    w.state := direct;
                --  end if;
                --else
                --  w.state := idle;
                --end if;

               end if;
            end if;
    end case;

    wbo.stall <= not can_queue_request;
    w.cyc_dly := wbi.cyc;

    if can_queue_request='1' then
      if wbi.cyc='1' and wbi.stb='1' then
        w.adr := wbi.adr;
        w.dat := wbi.dat;
        w.we  := wbi.we;
        w.sel := wbi.sel;
        w.tt  := tt;
        w.pending := '1';
      else
        -- Perform WC flush if timer is zero now.
        if wc_has_data and r.wctimer=0 then
          --w.state := writecombine;
        end if;
        w.pending := '0';
      end if;
    end if;

    -- WC timer
    if wc_push=true then
      w.wctimer := wc_queue_delay - 1;
    else
      if w.wctimer/=0 then
        w.wctimer := r.wctimer - 1;
      end if;
    end if;

    if syscon.rst='1' then
      w.pending := '0';
      w.cyc := '0';
      w.stb := DontCareValue;
      w.adr := (others =>DontCareValue);
      w.dat := (others =>DontCareValue);
      w.sel := (others =>DontCareValue);
      w.cyc_dly := '0';
      w.we  := DontCareValue;
      w.state := running;
      w.tt := (others => DontCareValue);
      w.wcindex := (others => '0');
    end if;

    if rising_edge(syscon.clk) then
      r<=w;
    end if;
  end process;
end behave;
