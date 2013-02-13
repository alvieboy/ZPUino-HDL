library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library work;
use work.zpu_config.all;
use work.zpupkg.all;
use work.zpuinopkg.all;
use work.zcorev3pkg.all;
use work.wishbonepkg.all;

entity zcorev3_evu is
  port (
    syscon:       in  wb_syscon_type;
    -- Signals from delay slot
    dri:          in  prefetchregs_type;
    -- Data registers output
    dr:           out evalregs_type;
    -- Comb. signals
    valid:        out boolean;
    -- SP Load
    newsp:        in unsigned(maxAddrBitBRAM downto 2);
    loadsp:       in boolean;
    -- Memory interface (cache)
    dco:          in dcache_out_type;
    -- Pipeline control
    hold:         in  boolean;
    busy:         out boolean;
    flush:        in  boolean
  );
end entity zcorev3_evu;


architecture behave of zcorev3_evu is

  signal r: evalregs_type;
  signal busy_i: boolean;

begin

  dr <= r;

  process(r, syscon, hold, loadsp, dco.a_valid, flush)
    variable w: prefetchregs_type;
    variable is_valid: boolean;
  begin
      w := r;

      is_valid := false;
      busy_i <= true;

      if r.request='0' then
        is_valid := r.valid;
        busy_i <= false;
      else
        if dco.a_valid='1' and r.valid then
          is_valid := true;
          busy_i <= false;
        end if;
      end if;

      valid <= is_valid;

      if not hold and not busy_i then
        w.op            := dri.op;
        w.pc            := dri.pc;
        w.sp            := dri.sp;
        w.spnext        := dri.spnext;
        --if is_valid then
        --  w.sp            := dri.spnext;
        --end if;
        w.fetchpc       := dri.fetchpc;
        w.idim          := dri.idim;
        w.writeback     := dri.writeback;
        w.readback      := dri.readback;
        w.op_freeze     := dri.op_freeze;
        w.request       := dri.request;
        w.valid         := dri.valid;
        w.raddr         := dri.raddr;
      end if;

      --if r.op.decoded = Decoded_PopSP and is_valid and not loadsp then
      --  busy_i <= true;
      --end if;

      if loadsp then
        w.spnext := newsp;
        w.sp     := newsp;
      end if;

      if flush then
        w.valid := false;
        w.request := '0';
      end if;

      busy <= busy_i;

      if syscon.rst='1' then
        w.request := '0';
      end if;

      if rising_edge(syscon.clk) then
        r  <= w;
      end if;
      r.read          <= dco.a_data_out;
  end process;

end behave;
