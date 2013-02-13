library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library work;
use work.zpu_config.all;
use work.zpupkg.all;
use work.zpuinopkg.all;
use work.zcorev3pkg.all;
use work.wishbonepkg.all;

entity zcorev3_pfu is
  port (
    syscon:       in  wb_syscon_type;
    -- Signals from decoder
    dri:          in  decoderegs_type;
    -- Data registers output
    dr:           out prefetchregs_type;
    -- SP Load
    newsp:        in  unsigned(maxAddrBitBRAM downto 2);
    loadsp:       in  boolean;
    -- Dcache connection
    dci:          out dcache_in_type;
    dco:          in dcache_out_type;
    -- Pipeline control
    hold:         in  boolean;
    busy:         out boolean;
    flush:        in  boolean
  );
end entity zcorev3_pfu;

architecture behave of zcorev3_pfu is

  signal r: prefetchregs_type;
  signal read_address: std_logic_vector(31 downto 0);

begin

  dr <= r;

    process(dri.op.decoded, r.spnext, dri.op.spOffset, flush)
    begin
      read_address <= (others => '0');
      read_address(maxAddrBitBRAM downto 2) <= std_logic_vector(r.spnext + 2);
      if not flush then
        if dri.op.decoded=Decoded_LoadSP or dri.op.decoded=decoded_AddSP then
          read_address(maxAddrBitBRAM downto 2) <= std_logic_vector(r.spnext + dri.op.spOffset);
        end if;
      end if;
    end process;

    dci.a_address <= read_address;

    process(syscon,
            dco, dri, dri.op, r, r.op, hold, flush, newsp,
            loadsp, hold, flush)
      variable w: prefetchregs_type;
      variable writeback: std_logic;
      variable readback: std_logic;
      variable a_enable: std_logic;
      variable a_strobe: std_logic;
      variable request_done: std_logic;
      variable do_hold_dfu: std_logic;
      variable op_freeze: boolean;
      variable busy_i: boolean;
    begin

      w := r;
      if not hold or dco.a_valid='0' then
        a_enable := '1';
      else
        a_enable := '0';
      end if;


      a_strobe := '0';

      if r.request='1' then
        request_done := dco.a_valid;
      else
        request_done := not r.pending;
      end if;

      --w.load := loadsp;

      -- Moved op_will_freeze from decoder to here
      case dri.op.decoded is
        when Decoded_Ashiftleft | Decoded_Mult | Decoded_MultF16 |
            Decoded_Store | Decoded_StoreB | Decoded_Storeh |
            Decoded_Load | Decoded_Loadb | Decoded_Loadh |
            Decoded_PopSP | Decoded_Neqbranch =>
          op_freeze := true;
        when others =>
          op_freeze := false;
      end case;

      case r.state is
        when running =>

          if not hold then

            if dri.valid then
              -- Strobe signal
              case dri.op.stackOper is
                when Stack_Pop =>     a_strobe := '1';
                when Stack_DualPop => a_strobe := '1';
                when others =>
              end case;
              case dri.op.decoded is
                when Decoded_LoadSP | decoded_AddSP =>
                  a_strobe := '1';
                when others =>
              end case;

              -- PopSP
              if dri.op.decoded = Decoded_PopSP then
                w.state := popsp;
              end if;

            --end if;

            -- Pass to next stage, unless we cannot place the
            -- memory request.

            if (a_strobe='1' and a_enable='1' and dco.a_stall='0') or a_strobe='0' then

              case dri.op.stackOper is
                when Stack_Push =>      w.spnext := r.spnext - 1;
                when Stack_Pop =>       w.spnext := r.spnext + 1;
                when Stack_DualPop =>   w.spnext := r.spnext + 2;
                when others =>
              end case;

              w.sp := r.spnext;

            end if;
            end if;
          end if; -- not hold

        when popsp =>

          if loadsp or flush then
            w.state := running;
          end if;

      end case;


      if loadsp then
        busy_i := true;
        w.spnext := newsp(maxAddrBitBRAM downto 2);
      else

        if dri.valid then

          if not hold and not flush then
            case dri.op.stackOper is
              when Stack_Push =>    a_strobe := '0';
              when Stack_Pop =>     a_strobe := '1';
              when Stack_DualPop => a_strobe := '1';
              when others =>
            end case;

            case dri.op.decoded is
              when Decoded_LoadSP | decoded_AddSP =>
                a_strobe := '1';
              when others =>
            end case;
            w.abort := '0';
          end if;

          busy_i := false;

          if (a_strobe='1' and dco.a_stall='1') then
            busy_i := true;
          end if;

          if (not hold and not flush and not busy_i) then

            case dri.op.stackOper is
              when Stack_Push =>      w.spnext := r.spnext - 1;
              when Stack_Pop =>       w.spnext := r.spnext + 1;
              when Stack_DualPop =>   w.spnext := r.spnext + 2;
              when others =>
            end case;

            w.sp := r.spnext;
            w.op := dri.op;
            w.pc := dri.pc;
            w.fetchpc := dri.pcint;
            w.idim := dri.idim;
            w.writeback     := writeback;
            w.readback      := readback;
            w.op_freeze     := op_freeze;
            w.raddr         := read_address(maxAddrBitBRAM downto 2);
          end if;

          if flush then     -- this is a pipeline "invalidate" flag.
            w.valid := false;
            w.spnext := r.sp;
          end if;

          --if flush='1' then
           -- dfu_hold <= '0';
          --end if;

        end if;

      end if;

      busy <= busy_i;

    if flush then     -- this is a pipeline "invalidate" flag.
      w.valid := false;
      -- we lost SP ...
      w.spnext := r.sp;
      w.request := '0';
    else
      if hold=false then --and request_done='1' then
        w.valid := dri.valid;
      end if;
    end if;

    writeback:='0';
    readback:='0';

    case dri.op.stackOper is
      when Stack_Push =>
        writeback := '1';
      when Stack_Pop =>
        readback := '1';
      when Stack_DualPop =>
        readback := '1';
      when others =>
    end case;

    if a_strobe='1' and a_enable='1' and dco.a_stall='1' and flush=false then
      w.pending:='1';
    else
      w.pending:='0';
    end if;

    dci.a_enable <= a_enable;
    dci.a_strobe <= a_strobe;

 --   if not hold and request_done='1' then
--      w.op            := dri.op;
 --     w.pc            := dri.pc;
--      w.fetchpc       := dri.pcint;
--      w.idim          := dri.idim;
--      w.writeback     := writeback;
--      w.readback      := readback;
--      w.op_freeze     := op_freeze;
--    end if;

    if flush then
      w.request := '0';
    else
      w.request := a_strobe;
    end if;

    if syscon.rst='1' then
      w.spnext := unsigned(spStart(maxAddrBitBRAM downto 2));
      w.valid := false;
      w.abort := '0';
      w.idim := '0';
      --w.recompute_sp:='0';
      w.request:='0';
      w.pending:='0';
    end if;

    if rising_edge(syscon.clk) then
      r <= w;
    end if;
   
  end process;

end behave;

