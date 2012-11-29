-- ZPU
--
-- Copyright 2004-2008 oharboe - Øyvind Harboe - oyvind.harboe@zylin.com
-- Copyright 2010-2012 Alvaro Lopes - alvieboy@alvie.com
-- 
-- The FreeBSD license
-- 
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:
-- 
-- 1. Redistributions of source code must retain the above copyright
--    notice, this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above
--    copyright notice, this list of conditions and the following
--    disclaimer in the documentation and/or other materials
--    provided with the distribution.
-- 
-- THIS SOFTWARE IS PROVIDED BY THE ZPU PROJECT ``AS IS'' AND ANY
-- EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
-- PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
-- ZPU PROJECT OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
-- INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
-- OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
-- STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
-- ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
-- 
-- The views and conclusions contained in the software and documentation
-- are those of the authors and should not be interpreted as representing
-- official policies, either expressed or implied, of the ZPU Project.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library work;
use work.zpu_config.all;
use work.zpupkg.all;
use work.zpuinopkg.all;
use work.wishbonepkg.all;


entity zcorev3 is
  port (
    syscon:         in wb_syscon_type;

    -- Master wishbone interface (RAM)
    mwbi:           in wb_miso_type;
    mwbo:           out wb_mosi_type;

    -- Master wishbone interface (IO) - non-pipelined
    iowbi:           in wb_miso_type;
    iowbo:           out wb_mosi_type;

    poppc_inst:     out std_logic;
    break:          out std_logic;

    -- ROM wb interface
    rwbi:           in wb_miso_type;
    rwbo:           out wb_mosi_type;

    icache_flush:        in std_logic;
    dcache_flush:        in std_logic;
    -- Debug interface

    dbg_out:            out zpu_dbg_out_type;
    dbg_in:             in zpu_dbg_in_type
  );
end zcorev3;

architecture behave of zcorev3 is

signal ico:         icache_out_type;
signal ici:         icache_in_type;

signal lshifter_enable: std_logic;
signal lshifter_done: std_logic;
signal lshifter_input: std_logic_vector(31 downto 0);
signal lshifter_amount: std_logic_vector(31 downto 0);
signal lshifter_output: std_logic_vector(63 downto 0);
signal lshifter_multorshift: std_logic;

signal begin_inst:          std_logic;
signal trace_opcode:        std_logic_vector(7 downto 0);
signal trace_pc:            std_logic_vector(maxAddrBitIncIO downto 0);
signal trace_sp:            std_logic_vector(maxAddrBitIncIO downto minAddrBit);
signal trace_topOfStack:    std_logic_vector(wordSize-1 downto 0);
signal trace_topOfStackB:   std_logic_vector(wordSize-1 downto 0);

-- state machine.

type State_Type is
(
State_Execute,
State_LoadStack,
State_Loadb,
State_Loadh,
State_Resync2,
State_ResyncNos,
State_WaitSPB,
State_ResyncFromStoreStack,
State_Neqbranch,
State_Ashiftleft,
State_Mult,
State_MultF16
);

type DecodedOpcodeType is
(
Decoded_Nop,
Decoded_Idle,
Decoded_Im0,
Decoded_ImN,
Decoded_LoadSP,
Decoded_Dup,
Decoded_DupStackB,
Decoded_StoreSP,
Decoded_Pop,
Decoded_PopDown,
Decoded_PopDownDown,
Decoded_AddSP,
Decoded_AddStackB,
Decoded_Shift,
Decoded_Emulate,
Decoded_Break,
Decoded_PushSP,
Decoded_PopPC,
Decoded_Add,
Decoded_Or,
Decoded_And,
Decoded_Load,
Decoded_Not,
Decoded_Flip,
Decoded_Store,
Decoded_PopSP,
Decoded_Interrupt,
Decoded_Neqbranch,
Decoded_Eq,
Decoded_Storeb,
Decoded_Storeh,
Decoded_Ulessthan,
Decoded_Lessthan,
Decoded_Ashiftleft,
Decoded_Ashiftright,
Decoded_Loadb,
Decoded_Loadh,
Decoded_Call,
Decoded_Mult,
Decoded_MultF16
);

constant spMaxBit: integer := stackSize_bits-1;
constant minimal_implementation: boolean := false;

subtype index is integer range 0 to 3;
signal tOpcode_sel : index;

function pc_to_cpuword(pc: unsigned) return unsigned is
  variable r: unsigned(wordSize-1 downto 0);
begin
  r := (others => DontCareValue);
  r(maxAddrBit downto 0) := pc;
  return r;
end pc_to_cpuword;

function pc_to_memaddr(pc: unsigned) return unsigned is
  variable r: unsigned(maxAddrBit downto 0);
begin
  r := (others => '0');
  r(maxAddrBit downto minAddrBit) := pc(maxAddrBit downto minAddrBit);
  return r;
end pc_to_memaddr;

-- Prefetch stage registers

type stackChangeType is (
  Stack_Same,
  Stack_Push,
  Stack_Pop,
  Stack_DualPop
);

type tosSourceType is
(
  Tos_Source_PC,
  Tos_Source_FetchPC,
  Tos_Source_Idim0,
  Tos_Source_IdimN,
  Tos_Source_StackB,
  Tos_Source_SP,
  Tos_Source_Add,
  Tos_Source_And,
  Tos_Source_Or,
  Tos_Source_Eq,
  Tos_Source_Not,
  Tos_Source_Flip,
  Tos_Source_LoadSP,
  Tos_Source_AddSP,
  Tos_Source_AddStackB,
  Tos_Source_Shift,
  Tos_Source_Ulessthan,
  Tos_Source_Lessthan,
  Tos_Source_LSU,
  Tos_Source_None
);

type decoderstate_type is (
  State_Run,
  State_Jump
  --,
--  State_Inject,
--  State_InjectJump
);


-- Sampled signals from the opcode. Left as signals
-- in order to simulate design.

type opcode_type is record
  opcode:         std_logic_vector(OpCode_Size-1 downto 0);
  decoded:        DecodedOpcodeType;
  freeze:         std_logic;
  stackOper:      stackChangeType;
  spOffset:       unsigned(4 downto 0);
  tosSource:      tosSourceType;
end record;


type decoderegs_type is record

  valid:          std_logic;
  op:             opcode_type;
  pc:             unsigned(maxAddrBitBRAM downto 0);
  fetchpc:        unsigned(maxAddrBitBRAM downto 0);
  pcint:          unsigned(maxAddrBitBRAM downto 0);
  idim:           std_logic;
  im:             std_logic;
  im_emu:         std_logic;
  break:          std_logic;
  state:          decoderstate_type;
end record;

type prefetchregs_type is record
  sp:             unsigned(maxAddrBitBRAM downto 2);
  op:             opcode_type;
  spnext:         unsigned(maxAddrBitBRAM downto 2);
  valid:          std_logic;
  pc:             unsigned(maxAddrBitBRAM downto 0);
  fetchpc:        unsigned(maxAddrBitBRAM downto 0);
  idim:           std_logic;
  break:          std_logic;
  load:           std_logic;
  readback:       std_logic;
  writeback:      std_logic;
  recompute_sp:   std_logic;
  request:        std_logic;
  pending:        std_logic;
  abort:          std_logic;
end record;

type exuregs_type is record
  idim:       std_logic;
  break:      std_logic;
  inInterrupt:std_logic;
  tos:        unsigned(wordSize-1 downto 0);
  nos:        unsigned(wordSize-1 downto 0);
  tos_save:   unsigned(wordSize-1 downto 0);
  nos_save:   unsigned(wordSize-1 downto 0);
  state:      State_Type;
  wroteback:  std_logic;
  -- Wishbone control signals (registered)
  wb_cyc:     std_logic;
  wb_stb:     std_logic;
  wb_we:      std_logic;
  wb_adr:     std_logic_vector(maxAddrBitIncIO downto 2);
  wb_dat:     std_logic_vector(wordSize-1 downto 0);

end record;

-- Registers for each stage
signal exr:     exuregs_type;
signal prefr:   prefetchregs_type;
signal decr:    decoderegs_type;

signal pcnext:          unsigned(maxAddrBitBRAM downto 0);  -- Helper only. TODO: move into variable
signal sp_load:         unsigned(maxAddrBitBRAM downto 2);    -- SP value to load, coming from EXU into PFU
signal decode_load_sp:  std_logic;                      -- Load SP signal from EXU to PFU
signal exu_busy:        std_logic;                      -- EXU busy ( stalls PFU )
signal pfu_busy:        std_logic;                      -- PFU busy ( stalls DFU )
signal decode_jump:     std_logic;                      -- Jump signal from EXU to DFU
signal jump_address:    unsigned(maxAddrBitBRAM downto 0);  -- Jump address from EXU to DFU
signal do_interrupt:    std_logic;                      -- Helper.

signal nos:                   unsigned(wordSize-1 downto 0); -- This is only a helper
--signal wroteback_q:           std_logic; -- TODO: get rid of this here, move to EXU regs

signal dci: dcache_in_type;
signal dco: dcache_out_type;
signal dfu_hold: std_logic;
signal prefr_valid: std_logic; -- Valid insn/prefetch data

begin

  shl: lshifter
  port map (
    clk     => syscon.clk,
    rst     => syscon.rst,
    enable  => lshifter_enable,
    done    => lshifter_done,
    inputA   => lshifter_input,
    inputB  => lshifter_amount,
    output  => lshifter_output,
    multorshift => lshifter_multorshift
  );

  -- synopsys translate_off

  traceFileGenerate:
   if Generate_Trace generate
      trace_file: trace
        port map (
          clk         => syscon.clk,
          begin_inst  => begin_inst,
          pc          => trace_pc,
          opcode      => trace_opcode,
          sp          => trace_sp,
          memA        => trace_topOfStack,
          memB        => trace_topOfStackB,
          busy        => '0',--busy,
          intsp       => (others => 'U')
        );
  end generate;

  -- synopsys translate_on

  icache: zpuino_icache
  generic map (
    ADDRESS_HIGH => maxAddrBitBRAM
  )
  port map (
    syscon    => syscon,
    ci        => ici,
    co        => ico,
    mwbi      => rwbi,
    mwbo      => rwbo
  );

  ici.flush <= icache_flush;

  dcache: zpuino_dcache
  generic map (
      ADDRESS_HIGH    => maxAddrBitBRAM
  )
  port map (
    syscon  => syscon,
    ci      => dci,
    co      => dco,
    mwbi    => mwbi,
    mwbo    => mwbo
  );

  dci.flush <= dcache_flush;


  do_interrupt <= '1' when iowbi.int='1'
    and exr.inInterrupt='0'
    else '0';




























  -- Decode/Fetch unit

  dfu: block
    signal sop: opcode_type;
  begin

  tOpcode_sel <= to_integer(decr.pcint(minAddrBit-1 downto 0));

  decodeControl: process(ico, tOpcode_sel, decr, do_interrupt)

    variable tOpcode : std_logic_vector(OpCode_Size-1 downto 0);
    variable localspOffset: unsigned(4 downto 0);

  begin
      case (tOpcode_sel) is
            when 0 => tOpcode := std_logic_vector(ico.data(31 downto 24));
            when 1 => tOpcode := std_logic_vector(ico.data(23 downto 16));
            when 2 => tOpcode := std_logic_vector(ico.data(15 downto 8));
            when 3 => tOpcode := std_logic_vector(ico.data(7 downto 0));
            -- synopsys translate_off
            when others => null;
            -- synopsys translate_on
       end case;

    sop.opcode    <= tOpcode;
    sop.stackOper <= Stack_Same;
    sop.tosSource <= Tos_Source_None;
    sop.freeze    <= '0';

    localspOffset(4):=not tOpcode(4);
    localspOffset(3 downto 0) := unsigned(tOpcode(3 downto 0));

    if do_interrupt='1' and decr.im='0' then
      sop.decoded <= Decoded_Interrupt;
      sop.stackOper <= Stack_Push;
      sop.tosSource <= Tos_Source_PC;
    else
    if (tOpcode(7 downto 7)=OpCode_Im) then
      if decr.im='0' then
        sop.stackOper <= Stack_Push;
        sop.tosSource <= Tos_Source_Idim0;
        sop.decoded<=Decoded_Im0;
      else
        sop.tosSource <= Tos_Source_IdimN;
        sop.decoded<=Decoded_ImN;
      end if;
      
    elsif (tOpcode(7 downto 5)=OpCode_StoreSP) then

      sop.stackOper <= Stack_Pop;
      sop.tosSource <= Tos_Source_StackB;
      if localspOffset=0 then
        sop.decoded<=Decoded_Pop;
        sop.tosSource <= Tos_Source_StackB;
      elsif localspOffset=1 then
        sop.decoded<=Decoded_PopDown;
        sop.tosSource <= Tos_Source_None;
      elsif localspOffset=2 then
        sop.decoded<=Decoded_PopDownDown;
        sop.tosSource <= Tos_Source_StackB;
      else
        sop.decoded<=Decoded_StoreSP;
        sop.freeze<='1';
        sop.tosSource <= Tos_Source_StackB;
      end if;
    elsif (tOpcode(7 downto 5)=OpCode_LoadSP) then

      sop.stackOper <= Stack_Push;

      if localspOffset=0 then
        sop.decoded<=Decoded_Dup;
      elsif localspOffset=1 then
        sop.decoded<=Decoded_DupStackB;
        sop.tosSource <= Tos_Source_StackB;
      else
        sop.decoded<=Decoded_LoadSP;
        sop.tosSource <= Tos_Source_LoadSP;
      end if;


    elsif (tOpcode(7 downto 5)=OpCode_Emulate) then

      -- Emulated instructions implemented in hardware
      if minimal_implementation then
        sop.decoded<=Decoded_Emulate;
        sop.stackOper<=Stack_Push; -- will push PC
        sop.tosSource <= Tos_Source_FetchPC;
      else

        if (tOpcode(5 downto 0)=OpCode_Loadb) then
          sop.stackOper<=Stack_Same;
          sop.decoded<=Decoded_Loadb;
          sop.tosSource <= Tos_Source_LSU;
        elsif (tOpcode(5 downto 0)=OpCode_Loadh) then
          sop.stackOper<=Stack_Same;
          sop.decoded<=Decoded_Loadh;
          sop.tosSource <= Tos_Source_LSU;
        elsif (tOpcode(5 downto 0)=OpCode_Neqbranch) then
          sop.stackOper<=Stack_DualPop;
          sop.decoded<=Decoded_Neqbranch;
          sop.freeze <= '1';
        elsif (tOpcode(5 downto 0)=OpCode_Call) then
          sop.decoded<=Decoded_Call;
          sop.stackOper<=Stack_Same;
          sop.tosSource<=Tos_Source_FetchPC;

        elsif (tOpcode(5 downto 0)=OpCode_Eq) then
          sop.decoded<=Decoded_Eq;
          sop.stackOper<=Stack_Pop;
          sop.tosSource<=Tos_Source_Eq;
        elsif (tOpcode(5 downto 0)=OpCode_Ulessthan) then
          sop.decoded<=Decoded_Ulessthan;
          sop.stackOper<=Stack_Pop;
          sop.tosSource<=Tos_Source_Ulessthan;

        elsif (tOpcode(5 downto 0)=OpCode_Lessthan) then
          sop.decoded<=Decoded_Lessthan;
          sop.stackOper<=Stack_Pop;
          sop.tosSource<=Tos_Source_Lessthan;

        elsif (tOpcode(5 downto 0)=OpCode_StoreB) then
          sop.decoded<=Decoded_StoreB;
          sop.stackOper<=Stack_DualPop;
          sop.freeze<='1';
        --elsif (tOpcode(5 downto 0)=OpCode_StoreH) then
        --  sop.decoded<=Decoded_StoreH;
        --  sop.stackOper<=Stack_DualPop;
        --  sop.freeze<='1';
        elsif (tOpcode(5 downto 0)=OpCode_Mult) then
          sop.decoded<=Decoded_Mult;
          sop.stackOper<=Stack_Pop;
          sop.freeze<='1';
        elsif (tOpcode(5 downto 0)=OpCode_Ashiftleft) then
          sop.decoded<=Decoded_Ashiftleft;
          sop.stackOper<=Stack_Pop;
          sop.freeze<='1';
        else
          sop.decoded<=Decoded_Emulate;
          sop.stackOper<=Stack_Push; -- will push PC
          sop.tosSource <= Tos_Source_FetchPC;
        end if;
      end if;
    elsif (tOpcode(7 downto 4)=OpCode_AddSP) then
      if localspOffset=0 then
        sop.decoded<=Decoded_Shift;
        sop.tosSource <= Tos_Source_Shift;
      elsif localspOffset=1 then
        sop.decoded<=Decoded_AddStackB;
        sop.tosSource <= Tos_Source_AddStackB;
      else
        sop.decoded<=Decoded_AddSP;
        sop.tosSource <= Tos_Source_AddSP;
      end if;
    else
      case tOpcode(3 downto 0) is
        when OpCode_Break =>
          sop.decoded<=Decoded_Break;
          sop.freeze <= '1';
        when OpCode_PushSP =>
          sop.stackOper <= Stack_Push;
          sop.decoded<=Decoded_PushSP;
          sop.tosSource <= Tos_Source_SP;
        when OpCode_PopPC =>
          sop.stackOper <= Stack_Pop;
          sop.decoded<=Decoded_PopPC;
          sop.tosSource <= Tos_Source_StackB;
        when OpCode_Add =>
          sop.stackOper <= Stack_Pop;
          sop.decoded<=Decoded_Add;
          sop.tosSource <= Tos_Source_Add;
        when OpCode_Or =>
          sop.stackOper <= Stack_Pop;
          sop.decoded<=Decoded_Or;
          sop.tosSource <= Tos_Source_Or;
        when OpCode_And =>
          sop.stackOper <= Stack_Pop;
          sop.decoded<=Decoded_And;
          sop.tosSource <= Tos_Source_And;
        when OpCode_Load =>
          sop.decoded<=Decoded_Load;
          sop.tosSource <= Tos_Source_LSU;
        when OpCode_Not =>
          sop.decoded<=Decoded_Not;
          sop.tosSource <= Tos_Source_Not;
        when OpCode_Flip =>
          sop.decoded<=Decoded_Flip;
          sop.tosSource <= Tos_Source_Flip;
        when OpCode_Store =>
          sop.stackOper <= Stack_DualPop;
          sop.decoded<=Decoded_Store;
          sop.freeze<='1';
        when OpCode_PopSP =>
          sop.decoded<=Decoded_PopSP;
          sop.stackOper <= Stack_Push; -- Enforce writeback
          sop.freeze<='1';
        when OpCode_NA4 =>
          if enable_fmul16 then
            sop.decoded<=Decoded_MultF16;
            sop.stackOper<=Stack_Pop;
            sop.freeze<='1';
          else
            sop.decoded<=Decoded_Nop;
          end if;
        when others =>
          sop.decoded<=Decoded_Nop;
      end case;
    end if;

    end if;

    sop.spOffset <= localspOffset;

    end process;

    pcnext <= decr.fetchpc + 1;

    process(decr, jump_address, decode_jump, syscon, sop, dfu_hold, ico, pcnext )
      variable w: decoderegs_type;
    begin

      w := decr;
      ici.address(maxAddrBitBRAM downto 0) <= std_logic_vector(decr.fetchpc(maxAddrBitBRAM downto 0));

      case decr.state is

        when State_Run =>

          if dfu_hold='0' or decr.valid='0' then
            if decr.valid='0' then
              ici.strobe <= '1';
              ici.enable <= '1';
            else
              ici.strobe <= not dfu_hold;
              ici.enable <= not dfu_hold;
            end if;
            if ico.stall='0' then
              w.fetchpc := pcnext;
            end if;

            if decode_jump='1' then
              w.valid := '0';
              w.im := '0';
              w.break := '0'; -- Invalidate eventual break after branch instruction
              ici.strobe <='0';
              w.fetchpc := jump_address;
              w.state := State_Jump;
            else
              w.valid := ico.valid;

              if ico.valid='1' then
                w.im := sop.opcode(7);
              end if;

              if ico.stall='0' then
                w.pcint := decr.fetchpc;
                w.pc := decr.pcint;
              end if;
            end if;

            w.op := sop;
            w.idim := decr.im;
          else
            ici.strobe <= '0';
            ici.enable <= '0';

          end if;

        when State_Jump =>

          w.valid := '0';
          ici.strobe <= '1';
          ici.enable <= '1';
          if ico.stall='0' then
            w.pcint := decr.fetchpc;
            w.fetchpc := pcnext;
            w.state := State_Run;
          end if;

      end case;

    --
    -- Reset handling
    --
    if syscon.rst='1' then
      --w.pc      := (others => '0');
      --w.pcint   := (others => '0');
      w.valid   := '0';
      w.fetchpc := (others => '0');
      w.im      :='0';
      w.im_emu  :='0';
      w.state   := State_Run;
      --w.break   := '0';
    end if;

    if rising_edge(syscon.clk) then
      decr <= w;
    end if;

  end process;

  end block; -- End of DFU






--  dfu_hold <= '1' when pfu_busy='1' or exu_busy='1' else '0';






  sp_load <= exr.tos(maxAddrBitBRAM downto 2); -- Will be delayed one clock cycle

  pfu: block
    signal pfu_invalidate : std_logic;
    signal pfu_hold : std_logic;


  begin

    pfu_hold <= exu_busy;
    pfu_invalidate <= decode_jump;


    process(syscon,
            dco, decr, prefr, exu_busy, decode_jump, sp_load,
            decode_load_sp, pfu_hold, pfu_invalidate)
      variable w: prefetchregs_type;
      variable writeback: std_logic;
      variable readback: std_logic;
      variable a_enable: std_logic;
      variable a_strobe: std_logic;
      variable request_done: std_logic;
      variable do_hold_dfu: std_logic;
    begin

      w := prefr;

      dci.a_address <= (others => '0');
      dci.a_address(maxAddrBitBRAM downto 2) <= std_logic_vector(prefr.spnext + 2);
      a_enable := not exu_busy or not dco.a_valid;
      a_strobe := '0';
      dfu_hold <= '0';

      w.recompute_sp:='0';

      if prefr.request='1' then
        request_done := dco.a_valid;
      else
        request_done := not prefr.pending;
      end if;

      -- Stack
      w.load := decode_load_sp;

      if decode_load_sp='1' then

        pfu_busy <= '1';
        dfu_hold <= '1';

        w.spnext := sp_load(maxAddrBitBRAM downto 2);
        w.recompute_sp := '1';

      else

        pfu_busy <= exu_busy or (not dco.a_valid) or prefr.abort;

        if decr.valid='1' then

          if (pfu_hold='0' and pfu_invalidate='0') then 
            case decr.op.stackOper is
              when Stack_Push =>    a_strobe := '0';
              when Stack_Pop =>     a_strobe := '1';
              when Stack_DualPop => a_strobe := '1';
              when others =>
            end case;

            case decr.op.decoded is
              when Decoded_LoadSP | decoded_AddSP =>

                dci.a_address(maxAddrBitBRAM downto 2) <= std_logic_vector(prefr.spnext + decr.op.spOffset);
                --a_enable := '1';
                a_strobe := '1';
              when others =>
            end case;
            w.abort := '0';
          end if;

          do_hold_dfu := exu_busy or (prefr.request and not dco.a_valid) or  (a_strobe and dco.a_stall);
          dfu_hold <= do_hold_dfu;

          if (pfu_hold='0' and pfu_invalidate='0' and do_hold_dfu='0') then

            case decr.op.stackOper is
              when Stack_Push =>      w.spnext := prefr.spnext - 1;
              when Stack_Pop =>       w.spnext := prefr.spnext + 1;
              when Stack_DualPop =>   w.spnext := prefr.spnext + 2;
              when others =>
            end case;

            w.sp := prefr.spnext;

          end if;



          if pfu_invalidate='1' then
            pfu_busy <= '0';
            dfu_hold <= '0';
          end if;

        end if;

      end if;


    if decode_jump='1' then     -- this is a pipeline "invalidate" flag.
      w.valid := '0';
    else
      if exu_busy='0' and request_done='1' then
        w.valid := decr.valid;
      end if;
    end if;

    -- Moved op_will_freeze from decoder to here
    case decr.op.decoded is
      when Decoded_StoreSP
          | Decoded_LoadB
          | Decoded_Neqbranch
          | Decoded_StoreB
          | Decoded_Mult
          | Decoded_Ashiftleft
          | Decoded_Break
          --| Decoded_Load
          | Decoded_LoadH
          | Decoded_Store
          | Decoded_StoreH
          | Decoded_PopSP
          | Decoded_MultF16 =>

        --i_op_freeze := '1';

      when others =>
        --i_op_freeze := '0';
    end case;

    writeback:='0';
    readback:='0';

    case decr.op.stackOper is
      when Stack_Push =>
        writeback := '1';
      when Stack_Pop =>
        readback := '1';
      when Stack_DualPop =>
        readback := '1';
      when others =>
    end case;



    pfu_busy <= dco.a_stall and a_strobe;

    

    if prefr.request='0' then
      w.request := (a_strobe and a_enable) and not dco.a_stall;
    else
      if dco.a_valid='1' then
        w.request := (a_strobe and a_enable) and not dco.a_stall;
      end if;
    end if;

   --if pfu_hold='0' then
      if a_strobe='1' and a_enable='1' and dco.a_stall='1' then
        w.pending:='1';
      else
        w.pending:='0';
      end if;
   --end if;

    -- If we were halted and we were not able to place
    -- request, reset valid.
    prefr_valid <= prefr.valid and request_done and not prefr.abort;

    if prefr.pending='1' and pfu_hold='1' then
      -- This is buggy - we can miss instructions here.
      w.abort := '1';
      w.pending := '0';
--      report "Pending request and holding at same time!" severity note;
      --w.pending := '0';
      --w.request := '0';
      --a_enable  := '0';
      --a_strobe:='0';
      --w.valid := '0';
    end if;


    dci.a_enable <= a_enable;
    dci.a_strobe <= a_strobe;

    if a_enable<='0' then
      dci.a_address <= (others => DontCareValue);
    end if;

    if exu_busy='0' and request_done='1' then
      w.op            := decr.op;
      w.pc            := decr.pc;
      w.fetchpc       := decr.pcint;
      w.idim          := decr.idim;
      w.writeback     := writeback;
      w.readback      := readback;
    end if;

    if syscon.rst='1' then
      w.spnext := unsigned(spStart(maxAddrBitBRAM downto 2));
      w.valid := '0';
      w.abort := '0';
      w.idim := '0';
      w.recompute_sp:='0';
      w.request:='0';
      w.pending:='0';
    end if;

    if rising_edge(syscon.clk) then
      prefr <= w;
    end if;
   
  end process;

  end block; -- PFU

  dbg: block
    signal dco_a_valid: std_logic;
    signal dco_b_valid: std_logic;
    signal dco_a_stall: std_logic;
    signal dco_b_stall: std_logic;
    signal prefr_valid: std_logic;
    signal prefr_abort: std_logic;
    signal prefr_pending: std_logic;
  begin
    dco_a_valid <= dco.a_valid;
    dco_b_valid <= dco.b_valid;
    dco_a_stall <= dco.a_stall;
    dco_b_stall <= dco.b_stall;
    prefr_valid <= prefr.valid;
    prefr_abort <= prefr.abort;
    prefr_pending <= prefr.pending;
  end block;



  process(prefr,exr,nos)
  begin
        trace_pc <= (others => '0');
        trace_pc(maxAddrBit downto 0) <= std_logic_vector(prefr.pc);
        trace_opcode <= prefr.op.opcode;
        trace_sp <= (others => '0');
        --trace_sp(maxAddrBit downto spMaxBit+1) <= std_logic_vector(prefr.spseg);
        trace_sp(maxAddrBitBRAM downto 2) <= std_logic_vector(prefr.sp);
        trace_topOfStack <= std_logic_vector( exr.tos );
        trace_topOfStackB <= std_logic_vector( nos );
  end process;

  -- IO/Memory Accesses
  iowbo.cyc <= exr.wb_cyc;
  iowbo.stb <= exr.wb_stb;
  iowbo.we <= exr.wb_we;
  process(exr.wb_adr)
  begin
    iowbo.adr <= (others => '0');
    iowbo.adr(maxAddrBitIncIO downto 2) <= exr.wb_adr;
  end process;
  iowbo.dat <= exr.wb_dat;
  --wb_cyc_o    <= exr.wb_cyc;
  --wb_stb_o    <= exr.wb_stb;
  --wb_we_o     <= exr.wb_we;
  --lsu_data_write <= std_logic_vector( nos );

  --freeze_all  <= dbg_in.freeze;

  process(exr, syscon, pcnext, dco,
          do_interrupt,
          exr, prefr, prefr_valid,
          nos,
          iowbi,
          lshifter_done,
          lshifter_output
          )

    --variable spOffset: unsigned(4 downto 0);
    variable w: exuregs_type;
    variable instruction_executed: std_logic;
    variable wroteback: std_logic;
    variable datawrite: std_logic_vector(wordSize-1 downto 0);
    variable sel: std_logic_vector(3 downto 0);
    --variable stackptrfull: unsigned(spMaxBit downto 2):= (others => '1');
    --variable a_strobe: std_logic;
    variable b_strobe: std_logic;
    variable b_enable: std_logic;
  begin

    w := exr;

    instruction_executed := '0';

    w.wb_stb := DontCareValue;
    w.wb_cyc := '0';
    w.wb_we := DontCareValue;
    w.wb_adr := (others => DontCareValue);
    w.wb_dat := (others => DontCareValue);

    b_enable :='1';
    b_strobe :='0';

    dci.b_we <= '0';
    dci.b_wmask <= "0000";

    exu_busy <= '0';
    --exu_busy <= dco.b_stall;

    decode_jump <= '0';

    jump_address <= (others => DontCareValue);

    lshifter_enable <= '0';
    lshifter_amount <= std_logic_vector(exr.tos_save);
    lshifter_input <= std_logic_vector(exr.nos_save);
    lshifter_multorshift <= '0';

    poppc_inst <= '0';
    begin_inst<='0';

    dci.b_address <= (others => '0');
    dci.b_address(maxAddrBitBRAM downto 2) <= std_logic_vector( prefr.sp );
    dci.b_data_in <= std_logic_vector( exr.tos );

    if iowbi.int='0' then
      w.inInterrupt := '0';
    end if;


    nos <= exr.nos;

    decode_load_sp <= '0';

    case exr.state is

      when State_ResyncFromStoreStack =>
        exu_busy <= '1';
        w.state := State_ResyncNos;
        dci.b_address(maxAddrBitBRAM downto 2) <= std_logic_vector(prefr.spnext+1);--exr.tos(maxAddrBitBRAM downto 2)+1);
        b_enable := '1';
        b_strobe := '1';
        wroteback := '0';

      when State_ResyncNos =>

        w.nos := unsigned( dco.b_data_out );
        dci.b_address(maxAddrBitBRAM downto 2)  <= std_logic_vector(prefr.spnext);
        b_enable := '1';
        b_strobe := '1';
        exu_busy <= '1';
        wroteback := '0';
        if dco.b_valid='1' then
          w.state := State_Resync2;
        end if;

      when State_Resync2 =>

        w.tos := unsigned( dco.b_data_out );
        instruction_executed := '1';
        wroteback := '0';
        exu_busy<='1';
        if dco.b_valid='1' then
          w.state := State_Execute;
          exu_busy <= '0';
        end if;

      when State_Execute =>

       instruction_executed:='0';

       if prefr_valid='1' then

        exu_busy <= '0';



        if true then

        wroteback := '0';
        w.nos_save := nos;
        w.tos_save := exr.tos;
        w.idim := prefr.idim;
        w.break:= prefr.break;

        instruction_executed := '1';
        begin_inst<='1';

        -- NOS computation
        if prefr.writeback='1' then
          w.nos := exr.tos;
          b_enable := '1';
          b_strobe := '1';
        end if;

        if prefr.readback='1' then
          w.nos := unsigned(dco.a_data_out);
        end if;

        -- TOS big muxer

        case prefr.op.tosSource is
          when Tos_Source_PC =>
            w.tos := (others => '0');
            w.tos(maxAddrBit downto 0) := prefr.pc;

          when Tos_Source_FetchPC =>
            w.tos := (others => '0');
            w.tos(maxAddrBit downto 0) := prefr.fetchpc;

          when Tos_Source_Idim0 =>
            for i in wordSize-1 downto 7 loop
              w.tos(i) := prefr.op.opcode(6);
            end loop;
            w.tos(6 downto 0) := unsigned(prefr.op.opcode(6 downto 0));

          when Tos_Source_IdimN =>
            w.tos(wordSize-1 downto 7) := exr.tos(wordSize-8 downto 0);
            w.tos(6 downto 0) := unsigned(prefr.op.opcode(6 downto 0));

          when Tos_Source_StackB =>
            w.tos := nos;

          when Tos_Source_SP =>
            w.tos := (others => '0');
            --w.tos(31) := '1'; -- Stack address
            --w.tos(maxAddrBit downto spMaxBit+1) := prefr.spseg;
            w.tos(maxAddrBitBRAM downto 2) := prefr.sp;

          when Tos_Source_Add =>
            w.tos := exr.tos + nos;

          when Tos_Source_And =>
            w.tos := exr.tos and nos;

          when Tos_Source_Or =>
            w.tos := exr.tos or nos;

          when Tos_Source_Eq =>
            w.tos := (others => '0');
            if nos = exr.tos then
              w.tos(0) := '1';
            end if;

          when Tos_Source_Ulessthan =>
            w.tos := (others => '0');
            if exr.tos < nos then
              w.tos(0) := '1';
            end if;

          when Tos_Source_Lessthan =>
            w.tos := (others => '0');
            if signed(exr.tos) < signed(nos) then
              w.tos(0) := '1';
            end if;

          when Tos_Source_Not =>
            w.tos := not exr.tos;

          when Tos_Source_Flip =>
            for i in 0 to wordSize-1 loop
              w.tos(i) := exr.tos(wordSize-1-i);
            end loop;

          when Tos_Source_LoadSP =>
            w.tos := unsigned( dco.a_data_out );

          when Tos_Source_AddSP =>
            w.tos := w.tos + unsigned( dco.a_data_out );

          when Tos_Source_AddStackB =>
            w.tos := w.tos + nos;

          when Tos_Source_Shift =>
            w.tos := exr.tos + exr.tos;

          --when Tos_Source_LSU =>
          --  if lsu_busy='0' then
          --    w.tos := unsigned(lsu_data_read);
          --  end if;
          when others =>

        end case;

        case prefr.op.decoded is

          when Decoded_Interrupt =>

           w.inInterrupt := '1';
           jump_address <= to_unsigned(32, maxAddrBit+1);
           decode_jump <= '1';
           dci.b_we <='1';
           dci.b_wmask <="1111";

           wroteback:='1';
           instruction_executed := '0';
           --w.state := State_WaitSPB;

          when Decoded_Im0 =>

           dci.b_we <='1';
           dci.b_wmask <="1111";
           wroteback:='1';

          when Decoded_ImN =>

          when Decoded_Nop =>

          when Decoded_PopPC =>

            decode_jump <= not dco.b_stall;
            jump_address <= exr.tos(maxAddrBit downto 0);
            poppc_inst <= not dco.b_stall;
            instruction_executed := '0';

          when Decoded_Call =>

            decode_jump <= '1';
            jump_address <= exr.tos(maxAddrBit downto 0);
            instruction_executed := '0';

          when Decoded_Emulate =>

            decode_jump <= not dco.b_stall;
            jump_address <= (others => '0');
            jump_address(9 downto 5) <= unsigned(prefr.op.opcode(4 downto 0));

            dci.b_we <='1';
            dci.b_wmask <="1111";

            wroteback:='1';

          when Decoded_PushSP =>
            dci.b_we <='1';
            dci.b_wmask <="1111";

            --stack_a_writeenable<=(others =>'1');
            --w.nos := exr.tos;
            wroteback:='1';

          when Decoded_LoadSP =>
            dci.b_we <='1';
            dci.b_wmask <="1111";
--            stack_a_writeenable <= (others =>'1');
            --w.nos := exr.tos;
            wroteback:='1';

          when Decoded_DupStackB =>
            dci.b_we <='1';
            dci.b_wmask <="1111";
            --w.nos := exr.tos;
            --stack_a_writeenable <= (others => '1');
            wroteback:='1';

          when Decoded_Dup =>
            dci.b_we <='1';
            dci.b_wmask <="1111";
            --w.nos := exr.tos;
            --stack_a_writeenable<= (others =>'1');
            wroteback:='1';

          when Decoded_AddSP =>
            dci.b_we <='1';
            dci.b_wmask <="1111";

--            stack_a_writeenable <= (others =>'1');

          when Decoded_StoreSP =>
            dci.b_we <='1';
            dci.b_wmask <="1111";
            --w.nos := exr.tos;

--            stack_a_writeenable <= (others =>'1');
            b_strobe := '1';
            wroteback:='1';
            dci.b_address(maxAddrBitBRAM downto 2) <= std_logic_vector(prefr.sp + prefr.op.spOffset);
            instruction_executed := '0';
            --w.state := State_WaitSPB;

          when Decoded_PopDown =>
            --dci.b_we <='1';
            --dci.b_wmask <="1111";

          when Decoded_PopDownDown =>
            dci.b_we <='1';
            dci.b_wmask <="1111";
            w.nos := exr.tos;
            b_strobe := '1';
            wroteback:='1';
            dci.b_address(maxAddrBitBRAM downto 2) <= std_logic_vector(prefr.sp + prefr.op.spOffset);

--            stack_a_writeenable<=(others =>'1');

          when Decoded_Pop =>

          when Decoded_Ashiftleft =>
            exu_busy<='1';
            w.state := State_Ashiftleft;

          when Decoded_Mult  =>
            exu_busy<='1';
            w.state := State_Mult;

          when Decoded_MultF16  =>
            exu_busy<='1';
            w.state := State_MultF16;

          when Decoded_Store | Decoded_StoreB | Decoded_StoreH =>

              if prefr.op.decoded=Decoded_Store then
                datawrite := std_logic_vector(nos);
                sel := "1111";

              elsif prefr.op.decoded=Decoded_StoreH then
                datawrite := (others => DontCareValue);
                if exr.tos(1)='1' then
                  datawrite(15 downto 0) := std_logic_vector(nos(15 downto 0))  ;
                  sel := "0011";
                else
                  datawrite(31 downto 16) := std_logic_vector(nos(15 downto 0))  ;
                  sel := "1100";
                end if;
              else
                datawrite := (others => DontCareValue);
                case exr.tos(1 downto 0) is
                  when "11" =>
                    datawrite(7 downto 0) := std_logic_vector(nos(7 downto 0))  ;
                    sel := "0001";
                  when "10" =>
                    datawrite(15 downto 8) := std_logic_vector(nos(7 downto 0))  ;
                    sel := "0010";
                  when "01" =>
                    datawrite(23 downto 16) := std_logic_vector(nos(7 downto 0))  ;
                    sel := "0100";
                  when "00" =>
                    datawrite(31 downto 24) := std_logic_vector(nos(7 downto 0))  ;
                    sel := "1000";
                  when others =>
                end case;
              end if;

            w.nos := exr.nos;
            instruction_executed:='0';

            if exr.tos(maxAddrBitIncIO)='0' then

              b_enable := '1';
              b_strobe := '1';
              dci.b_we <='1';
              dci.b_wmask <= sel;

              if dco.b_stall='0' then
                w.state := State_ResyncFromStoreStack;
                instruction_executed:='1';
              end if;

            else
              b_enable :='0';
              b_strobe :='0';
              dci.b_we <='0';
              dci.b_wmask <= (others => '0');
              w.wb_cyc := '1';
              w.wb_stb := '1';
              w.wb_we := '1';
              w.wb_adr := std_logic_vector(exr.tos(exr.wb_adr'RANGE));
              w.wb_dat := std_logic_vector(exr.nos);

              if iowbi.ack='1' then
                instruction_executed:='1';
                w.wb_cyc := '0';
                w.state := State_ResyncFromStoreStack;
              end if;

            end if;

            dci.b_address(maxAddrBitBRAM downto 2)  <= std_logic_vector(exr.tos(maxAddrBitBRAM downto 2));
            dci.b_data_in <= datawrite;
            exu_busy <= '1';

          when Decoded_Load | Decoded_Loadb | Decoded_Loadh =>

            --w.tos_save := exr.tos; -- Byte select

            instruction_executed := '0';
            --wroteback := wroteback_q; -- Keep WB

            --if inside_stack='1' then --exr.tos(wordSize-1)='1' then

            dci.b_address(maxAddrBitBRAM downto 2) <= std_logic_vector(exr.tos(maxAddrBitBRAM downto 2));
            exu_busy <= '1';

            if exr.tos(maxAddrBitIncIO)='0' then
              b_enable := '1';
              b_strobe := '1';
              if dco.b_stall='0' then
                w.state := State_LoadStack;
              end if;
            else
              b_enable := '0';
              b_strobe := '0';

              w.wb_cyc:='1';
              w.wb_stb:='1';
              w.wb_we:='0';
              w.wb_adr := std_logic_vector(exr.tos(exr.wb_adr'RANGE));
              if iowbi.ack='1' then
                w.tos := unsigned(iowbi.dat);

                if prefr.op.decoded=Decoded_Loadb then
                  exu_busy<='1';
                  w.state:=State_Loadb;
                elsif prefr.op.decoded=Decoded_Loadh then
                  exu_busy<='1';
                  w.state:=State_Loadh;
                else
                  instruction_executed:='1';
                  wroteback := '0';
                  exu_busy <= '0';--w.state := State_Execute;
                end if;

              end if;

            end if;

            

            --else
            --  exu_busy <= lsu_busy;
            --  lsu_req <= '1';
            --  lsu_we  <= '0';
            --  stack_a_enable <= '0';
            --  stack_a_addr  <= (others => DontCareValue);
            --  stack_a_write <= (others => DontCareValue);
            --  stack_b_enable <= not lsu_busy;

            --  if lsu_busy='0' then
            --    if prefr.decodedOpcode=Decoded_Loadb then
            --      exu_busy<='1';
            --      w.state:=State_Loadb;
            --    elsif prefr.decodedOpcode=Decoded_Loadh then
            --      exu_busy<='1';
            --      w.state:=State_Loadh;
            --    end if;
            --  end if;
            --end if;

          when Decoded_PopSP =>

            decode_load_sp <= '1';
            w.state := State_ResyncFromStoreStack;
            --dci.b_address(maxAddrBitBRAM downto 2) <= std_logic_vector(exr.tos(maxAddrBitBRAM downto 2)+1);
            --b_enable := '1';
            --b_strobe := '1';
            exu_busy <= '1';
            dci.b_we <='1';
            dci.b_wmask <="1111";

            --else
              --report "Implement me" severity failure;
            --  w.state := State_WriteBackStack;
            --  stack_a_addr <= (others => '0');
            --  w.fillspread := (others => '0');
            --  w.fillspwrite := (others => '0');
            --end if;

            instruction_executed := '0';
            

          when Decoded_Break =>

            w.break := '1';

          when Decoded_Neqbranch =>
            exu_busy <= '1';
            instruction_executed := '0';
            w.state := State_NeqBranch;

          when others =>

        end case;
      else -- freeze_all
        --
        -- Freeze the entire pipeline.
        --
        exu_busy<='1';
        --dci.a_enable <= '0';
        b_enable := '0';
        --dci.a_address <= (others => DontCareValue);
        dci.b_address <= (others => DontCareValue);

       end if;
      else
        -- not valid
        dci.b_address <= (others => DontCareValue);
        dci.b_data_in <= (others => DontCareValue);

      end if; -- valid

      when State_Ashiftleft =>
        exu_busy <= '1';
        lshifter_enable <= '1';
        w.tos := unsigned(lshifter_output(31 downto 0));

        if lshifter_done='1' then
          exu_busy<='0';
          w.state := State_Execute;
        end if;

      when State_Mult =>
        exu_busy <= '1';
        lshifter_enable <= '1';
        lshifter_multorshift <='1';
        w.tos := unsigned(lshifter_output(31 downto 0));

        if lshifter_done='1' then
          exu_busy<='0';
          w.state := State_Execute;
        end if;

      when State_MultF16 =>
        exu_busy <= '1';
        lshifter_enable <= '1';
        lshifter_multorshift <='1';
        w.tos := unsigned(lshifter_output(47 downto 16));

        if lshifter_done='1' then
          exu_busy<='0';
          w.state := State_Execute;
        end if;

      when State_WaitSPB =>

        instruction_executed:='1';
        wroteback := '0';
        w.state := State_Execute;
  
      when State_Loadb =>
        w.tos(wordSize-1 downto 8) := (others => '0');
        case exr.tos_save(1 downto 0) is
          when "11" =>
            w.tos(7 downto 0) := unsigned(exr.tos(7 downto 0));
          when "10" =>
            w.tos(7 downto 0) := unsigned(exr.tos(15 downto 8));
          when "01" =>
            w.tos(7 downto 0) := unsigned(exr.tos(23 downto 16));
          when "00" =>
            w.tos(7 downto 0) := unsigned(exr.tos(31 downto 24));
          when others =>
            null;
        end case;
        instruction_executed:='1';
        wroteback := '0';
        w.state := State_Execute;

      when State_Loadh =>
        w.tos(wordSize-1 downto 8) := (others => '0');

        case exr.tos_save(1) is
          when '1' =>
            w.tos(15 downto 0) := unsigned(exr.tos(15 downto 0));
          when '0' =>
            w.tos(15 downto 0) := unsigned(exr.tos(31 downto 16));
          when others =>
            null;
        end case;
        instruction_executed:='1';
        wroteback := '0';
        w.state := State_Execute;

      when State_LoadStack =>
        w.tos := unsigned( dco.b_data_out );

        if dco.b_valid='1' then
        if prefr.op.decoded=Decoded_Loadb then
          exu_busy<='1';
          w.state:=State_Loadb;
        elsif prefr.op.decoded=Decoded_Loadh then
          exu_busy<='1';
          w.state:=State_Loadh;
        else
          instruction_executed:='1';
          wroteback := '0';
          w.state := State_Execute;
        end if;
        else
          exu_busy<='1';
        end if;

      when State_NeqBranch =>
        if exr.nos_save/=0 then
          decode_jump <= '1';
          jump_address <= exr.tos(maxAddrBit downto 0) + prefr.pc;
          poppc_inst <= '1';
          exu_busy <= '1';
        else
          exu_busy <='1';
        end if;

        instruction_executed := '0';

        --dci.b_address(maxAddrBitBRAM downto 2) <= std_logic_vector(prefr.spnext);
        --wroteback:='0';
        --w.state := State_Resync2;
        w.state := State_ResyncNos;
        dci.b_address(maxAddrBitBRAM downto 2) <= std_logic_vector(prefr.spnext+1);--exr.tos(maxAddrBitBRAM downto 2)+1);
        b_enable := '1';
        b_strobe := '1';

      when others =>
         null;

    end case;

    if b_strobe='1' and dco.b_stall='1' then
      exu_busy<='1';
      w := exr; -- Hold everything
    end if;
  

    if w.state = State_Execute and prefr.valid='1' then
      w.wroteback := prefr.writeback;
    end if;

    dci.b_enable <= b_enable;
    dci.b_strobe <= b_strobe;

    if rising_edge(syscon.clk) then
      if syscon.rst='1' then
        exr.state <= State_Execute;
        exr.idim <= DontCareValue;
        exr.inInterrupt <= '0';
        exr.break <= '0';
        exr.wb_cyc <= '0';
        -- synopsys translate_off
        exr.tos <= x"deadbeef";
        exr.nos <= x"cafecafe";
        -- synopsys translate_on
        

        exr.wroteback <= '0';
      else
        exr <= w;

        if exr.break='1' then
          report "BREAK" severity failure;
        end if;

        -- Some sanity checks, to be caught in simulation
        if prefr.valid='1' then
          if prefr.op.tosSource=Tos_Source_Idim0 and prefr.idim='1' then
            report "Invalid IDIM flag 0" severity error;
          end if;
  
          if prefr.op.tosSource=Tos_Source_IdimN and prefr.idim='0' then
            report "Invalid IDIM flag 1" severity error;
          end if;
        end if;

      end if;
    end if;

  end process;

end behave;

