-- ZPU
--
-- Copyright 2004-2008 oharboe - Øyvind Harboe - oyvind.harboe@zylin.com
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
use work.wishbonepkg.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity zpu_core_small is
  port (
    wb_clk_i:       in std_logic;
    wb_rst_i:       in std_logic;

    -- Master wishbone interface

    wb_ack_i:       in std_logic;
    wb_dat_i:       in std_logic_vector(wordSize-1 downto 0);
    wb_dat_o:       out std_logic_vector(wordSize-1 downto 0);
    wb_adr_o:       out std_logic_vector(maxAddrBitIncIO downto 0);
    wb_cyc_o:       out std_logic;
    wb_stb_o:       out std_logic;
    wb_we_o:        out std_logic;

    wb_inta_i:      in std_logic;
    poppc_inst:     out std_logic;
    break:          out std_logic;

    -- STACK

    stack_a_read:         in std_logic_vector(wordSize-1 downto 0);
    stack_b_read:         in std_logic_vector(wordSize-1 downto 0);
    stack_a_write:        out std_logic_vector(wordSize-1 downto 0);
    stack_b_write:        out std_logic_vector(wordSize-1 downto 0);
    stack_a_writeenable:  out std_logic;
    stack_a_enable:       out std_logic;
    stack_b_writeenable:  out std_logic;
    stack_b_enable:       out std_logic;
    stack_a_addr:         out std_logic_vector(stackSize_bits+1 downto 2);
    stack_b_addr:         out std_logic_vector(stackSize_bits+1 downto 2);
    stack_clk:            out std_logic;

    -- ROM wb interface

    rom_wb_ack_i:       in std_logic;
    rom_wb_dat_i:       in std_logic_vector(wordSize-1 downto 0);
    rom_wb_adr_o:       out std_logic_vector(maxAddrBitIncIO downto 0);
    rom_wb_cyc_o:       out std_logic;
    rom_wb_stb_o:       out std_logic;
    rom_wb_cti_o:       out std_logic_vector(2 downto 0);

    -- Debug interface

    dbg_pc:         out std_logic_vector(maxAddrBit downto 0);
    dbg_opcode:     out std_logic_vector(7 downto 0);
    dbg_sp:         out std_logic_vector(10 downto 2);
    dbg_brk:        out std_logic;
    dbg_stacka:     out std_logic_vector(wordSize-1 downto 0);
    dbg_stackb:     out std_logic_vector(wordSize-1 downto 0);
    dbg_step:       in std_logic; -- async
    dbg_freeze:     in std_logic -- async

  );
end zpu_core_small;

architecture behave of zpu_core_small is

component pulse is
  port (
    pulse_in: in std_logic;
    pulse_out: out std_logic;
    clk: in std_logic;
    rst: in std_logic
  );
end component;

component lshifter is
  port (
    clk: in std_logic;
    rst: in std_logic;
    enable:  in std_logic;
    done: out std_logic;
    input:  in std_logic_vector(31 downto 0);
    amount: in std_logic_vector(4 downto 0);
    output: out std_logic_vector(31 downto 0)

  );
end component;

signal lshifter_enable: std_logic;
signal lshifter_done: std_logic;
signal lshifter_input: std_logic_vector(31 downto 0);
signal lshifter_amount: std_logic_vector(4 downto 0);
signal lshifter_output: std_logic_vector(31 downto 0);

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
State_Store,
State_StoreB,
State_Load,
State_LoadMemory,
State_LoadStack,
State_Loadb,
State_Resync1,
State_Resync2,
State_LoadSP,
State_WaitSPB,
State_ResyncFromStoreStack,
State_Neqbranch,
State_Ashiftleft
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
Decoded_Call,
Decoded_Mult
);

signal sampledOpcode: std_logic_vector(OpCode_Size-1 downto 0);
signal sampledDecodedOpcode : DecodedOpcodeType;

signal pcnext:     unsigned(maxAddrBit downto 0);

constant spMaxBit: integer := 10;

type zpuregs is record
  idim:       std_logic;
  break:      std_logic;
  inInterrupt:std_logic;
  tos:        unsigned(wordSize-1 downto 0);
  tos_save:   unsigned(wordSize-1 downto 0);
  nos_save:   unsigned(wordSize-1 downto 0);
  state:      State_Type;
  --jumpdly: std_logic;
  --jaddr:      unsigned(maxAddrBit downto 0);
  --bytesel:  unsigned(1 downto 0);
  -- Wishbone control signals (registered)
  wb_cyc:     std_logic;
  wb_stb:     std_logic;
  wb_we:      std_logic;
end record;

signal decode_load_sp: std_logic;

signal exr: zpuregs;

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
  variable r: unsigned(maxAddrBitIncIO downto 0);
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
  Tos_Source_None
);

type decoderegs_type is record

  valid:          std_logic;
  decodedOpcode:  DecodedOpcodeType;
  tosSource:      tosSourceType;
  opWillFreeze:   std_logic; -- '1' if we know in advance this opcode will freeze pipeline
  opcode:         std_logic_vector(OpCode_Size-1 downto 0);
  pc:             unsigned(maxAddrBit downto 0);
  fetchpc:        unsigned(maxAddrBit downto 0);
  pcint:          unsigned(maxAddrBit downto 0);
  idim:           std_logic;
  stackOperation: stackChangeType;
  spOffset:       unsigned(4 downto 0);

end record;

type prefetchregs_type is record
  sp:             unsigned(spMaxBit downto 2);
  spnext:         unsigned(spMaxBit downto 2);
  valid:          std_logic;
  decodedOpcode:  DecodedOpcodeType;
  tosSource:      tosSourceType;
  opcode:         std_logic_vector(OpCode_Size-1 downto 0);
  pc:             unsigned(maxAddrBit downto 0);
  fetchpc:        unsigned(maxAddrBit downto 0);
  idim:           std_logic;
  load:           std_logic;
  opWillFreeze:   std_logic;
  recompute_sp:   std_logic;
end record;

signal prefr: prefetchregs_type;

signal sampledStackBAddress: std_logic_vector(stackSize_bits-1+2 downto 2);
signal sampledOpWillFreeze: std_logic;

signal decr: decoderegs_type;

signal sp_pushsp, sp_popsp, sp_dualpopsp, sp_load:  unsigned(spMaxBit downto 2);

signal decode_freeze: std_logic;
signal decode_jump: std_logic;
signal jump_address: unsigned(maxAddrBit downto 0);
signal mult0,mult1,mult2,mult3: unsigned(31 downto 0);
signal wb_cyc_o_i: std_logic;

signal do_interrupt: std_logic;


signal sampledStackOperation: stackChangeType;
signal sampledspOffset: unsigned(4 downto 0);
signal sampledTosSource: tosSourceType;
signal nos: unsigned(wordSize-1 downto 0);
signal wroteback_q: std_logic;

-- Test

signal jump_q : std_logic;
signal freeze_all: std_logic := '0';
signal single_step: std_logic := '0';

begin


  -- Debug interface

  dbg_pc <= std_logic_vector(prefr.pc);
  dbg_opcode <= prefr.opcode;
  dbg_sp <= std_logic_vector(prefr.sp);
  dbg_brk <= exr.break;
  dbg_stacka <= std_logic_vector(exr.tos);
  dbg_stackb <= std_logic_vector(nos);

  shl: lshifter
  port map (
    clk     => wb_clk_i,
    rst     => wb_rst_i,
    enable  => lshifter_enable,
    done    => lshifter_done,
    input   => lshifter_input,
    amount  => lshifter_amount,
    output  => lshifter_output
  );

  stack_clk <= wb_clk_i;

  traceFileGenerate:
   if Generate_Trace generate
      trace_file: trace
        port map (
          clk         => wb_clk_i,
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


  wb_cyc_o <= wb_cyc_o_i;

  tOpcode_sel <= to_integer(decr.pcint(minAddrBit-1 downto 0));

  stack_b_addr <= sampledStackBAddress;

  do_interrupt <= '1' when wb_inta_i='1'
    and exr.inInterrupt='0'
    and prefr.valid='1'
    else '0';

  decodeControl:
  process(rom_wb_dat_i, tOpcode_sel, sp_load, sp_popsp, decr,
    do_interrupt)
    variable tOpcode : std_logic_vector(OpCode_Size-1 downto 0);
    variable localspOffset: unsigned(4 downto 0);
  begin

      case (tOpcode_sel) is

            when 0 => tOpcode := std_logic_vector(rom_wb_dat_i(31 downto 24));

            when 1 => tOpcode := std_logic_vector(rom_wb_dat_i(23 downto 16));

            when 2 => tOpcode := std_logic_vector(rom_wb_dat_i(15 downto 8));

            when 3 => tOpcode := std_logic_vector(rom_wb_dat_i(7 downto 0));

            when others =>
              null;
       end case;

    sampledOpcode <= tOpcode;
    sampledStackOperation <= Stack_Same;
    sampledTosSource <= Tos_Source_None;
    sampledOpWillFreeze <= '0';

    localspOffset(4):=not tOpcode(4);
    localspOffset(3 downto 0) := unsigned(tOpcode(3 downto 0));

    if do_interrupt='1' and decr.idim='0' then
      sampledDecodedOpcode <= Decoded_Interrupt;
      sampledStackOperation <= Stack_Push;
      sampledTosSource <= Tos_Source_PC;
    else
    if (tOpcode(7 downto 7)=OpCode_Im) then
      if decr.idim='0' then
        sampledStackOperation <= Stack_Push;
        sampledTosSource <= Tos_Source_Idim0;
        sampledDecodedOpcode<=Decoded_Im0;
      else
        sampledTosSource <= Tos_Source_IdimN;
        sampledDecodedOpcode<=Decoded_ImN;
      end if;
      
    elsif (tOpcode(7 downto 5)=OpCode_StoreSP) then

      sampledStackOperation <= Stack_Pop;
      sampledTosSource <= Tos_Source_StackB;
      if localspOffset=0 then
        sampledDecodedOpcode<=Decoded_Pop;
        sampledTosSource <= Tos_Source_StackB;
      elsif localspOffset=1 then
        sampledDecodedOpcode<=Decoded_PopDown;
        sampledTosSource <= Tos_Source_None;
      else
        sampledDecodedOpcode<=Decoded_StoreSP;
        sampledOpWillFreeze<='1';
        sampledTosSource <= Tos_Source_StackB;
      end if;
    elsif (tOpcode(7 downto 5)=OpCode_LoadSP) then

      sampledStackOperation <= Stack_Push;

      if localspOffset=0 then
        sampledDecodedOpcode<=Decoded_Dup;
      elsif localspOffset=1 then
        sampledDecodedOpcode<=Decoded_DupStackB;
        sampledTosSource <= Tos_Source_StackB;
      else
        sampledDecodedOpcode<=Decoded_LoadSP;
        sampledTosSource <= Tos_Source_LoadSP;
      end if;


    elsif (tOpcode(7 downto 5)=OpCode_Emulate) then

      -- Emulated instructions implemented in hardware
      if minimal_implementation then
        sampledDecodedOpcode<=Decoded_Emulate;
        sampledStackOperation<=Stack_Push; -- will push PC
        sampledTosSource <= Tos_Source_FetchPC;
      else

        if (tOpcode(5 downto 0)=OpCode_Loadb) then
          sampledStackOperation<=Stack_Same;
          sampledDecodedOpcode<=Decoded_Loadb;
          sampledOpWillFreeze<='1';
        elsif (tOpcode(5 downto 0)=OpCode_Neqbranch) then
          sampledStackOperation<=Stack_DualPop;
          sampledDecodedOpcode<=Decoded_Neqbranch;
          sampledOpWillFreeze <= '1';
        elsif (tOpcode(5 downto 0)=OpCode_Call) then
          sampledDecodedOpcode<=Decoded_Call;
          sampledStackOperation<=Stack_Same;
          sampledTosSource<=Tos_Source_FetchPC;

        elsif (tOpcode(5 downto 0)=OpCode_Eq) then
          sampledDecodedOpcode<=Decoded_Eq;
          sampledStackOperation<=Stack_Pop;
          sampledTosSource<=Tos_Source_Eq;
        elsif (tOpcode(5 downto 0)=OpCode_Ulessthan) then
          sampledDecodedOpcode<=Decoded_Ulessthan;
          sampledStackOperation<=Stack_Pop;
          sampledTosSource<=Tos_Source_Ulessthan;

        elsif (tOpcode(5 downto 0)=OpCode_Lessthan) then
          sampledDecodedOpcode<=Decoded_Lessthan;
          sampledStackOperation<=Stack_Pop;
          sampledTosSource<=Tos_Source_Lessthan;

--        elsif (tOpcode(5 downto 0)=OpCode_StoreB) then
--          sampledDecodedOpcode<=Decoded_StoreB;
--          sampledStackOperation<=Stack_DualPop;
--          sampledOpWillFreeze<='1';
        elsif (tOpcode(5 downto 0)=OpCode_Ashiftleft) then
          sampledDecodedOpcode<=Decoded_Ashiftleft;
          sampledStackOperation<=Stack_Pop;
          sampledOpWillFreeze<='1';
        else
          sampledDecodedOpcode<=Decoded_Emulate;
          sampledStackOperation<=Stack_Push; -- will push PC
          sampledTosSource <= Tos_Source_FetchPC;
        end if;
      end if;
    elsif (tOpcode(7 downto 4)=OpCode_AddSP) then
      if localspOffset=0 then
        sampledDecodedOpcode<=Decoded_Shift;
        sampledTosSource <= Tos_Source_Shift;
      elsif localspOffset=1 then
        sampledDecodedOpcode<=Decoded_AddStackB;
        sampledTosSource <= Tos_Source_AddStackB;
      else
        sampledDecodedOpcode<=Decoded_AddSP;
        sampledTosSource <= Tos_Source_AddSP;
      end if;
    else
      case tOpcode(3 downto 0) is
        when OpCode_Break =>
          sampledDecodedOpcode<=Decoded_Break;
          sampledOpWillFreeze <= '1';
        when OpCode_PushSP =>
          sampledStackOperation <= Stack_Push;
          sampledDecodedOpcode<=Decoded_PushSP;
          sampledTosSource <= Tos_Source_SP;
        when OpCode_PopPC =>
          sampledStackOperation <= Stack_Pop;
          sampledDecodedOpcode<=Decoded_PopPC;
          sampledTosSource <= Tos_Source_StackB;
        when OpCode_Add =>
          sampledStackOperation <= Stack_Pop;
          sampledDecodedOpcode<=Decoded_Add;
          sampledTosSource <= Tos_Source_Add;
        when OpCode_Or =>
          sampledStackOperation <= Stack_Pop;
          sampledDecodedOpcode<=Decoded_Or;
          sampledTosSource <= Tos_Source_Or;
        when OpCode_And =>
          sampledStackOperation <= Stack_Pop;
          sampledDecodedOpcode<=Decoded_And;
          sampledTosSource <= Tos_Source_And;
        when OpCode_Load =>
          sampledDecodedOpcode<=Decoded_Load;
          sampledOpWillFreeze<='1';
        when OpCode_Not =>
          sampledDecodedOpcode<=Decoded_Not;
          sampledTosSource <= Tos_Source_Not;
        when OpCode_Flip =>
          sampledDecodedOpcode<=Decoded_Flip;
          sampledTosSource <= Tos_Source_Flip;
        when OpCode_Store =>
          sampledStackOperation <= Stack_DualPop;   -- Dual pop, actually
          sampledDecodedOpcode<=Decoded_Store;
          sampledOpWillFreeze<='1';
        when OpCode_PopSP =>
          sampledDecodedOpcode<=Decoded_PopSP;
          sampledOpWillFreeze<='1';
        when others =>
          sampledDecodedOpcode<=Decoded_Nop;
      end case;
    end if;

    end if;
    sampledspOffset <= localspOffset;

  end process;

  -- Multiplier
--  process(wb_clk_i)
--    variable multR: unsigned(wordSize*2-1 downto 0);
--  begin
--    if rising_edge(wb_clk_i) then
--      multR := r.multInA * r.multInB;
--      mult3 <= multR(wordSize-1 downto 0);
--      mult2 <= mult3;
--      mult1 <= mult2;
--      mult0 <= mult1;
--    end if;
--  end process;



  -- Decode/Fetch unit

  rom_wb_cyc_o <= '1';
  rom_wb_stb_o <= not decode_freeze;

  process(decr, jump_address, decode_jump, wb_clk_i, sp_load,sp_dualpopsp,
          sp_pushsp,sp_popsp,sampledDecodedOpcode,sampledOpcode,decode_load_sp,decode_freeze,
          pcnext, rom_wb_ack_i, wb_rst_i, sampledStackOperation, sampledspOffset,
          jump_q,sampledTosSource, prefr.recompute_sp, sampledOpWillFreeze
          )
    variable w: decoderegs_type;
  begin

    w := decr;

    pcnext <= decr.fetchpc + 1;

    rom_wb_adr_o <= std_logic_vector(pc_to_memaddr(w.fetchpc));

    rom_wb_cti_o <= CTI_CYCLE_INCRADDR;

    if wb_rst_i='1' then
      w.pc     := (others => '0');
      w.valid  := '0';
      w.fetchpc := (others => '0');
    else

      if (decode_freeze='0' or prefr.recompute_sp='1' ) and decode_load_sp='0' then
          w.fetchpc := pcnext;

        if decode_jump='1' then
          w.fetchpc := jump_address;
          w.valid := '0';
          rom_wb_cti_o <= CTI_CYCLE_ENDOFBURST;
        else
          w.valid := rom_wb_ack_i and not jump_q;
          w.pcint := decr.fetchpc;
          w.pc := decr.pcint;
        end if;

        w.opcode := sampledOpcode;
        w.opWillFreeze := sampledOpWillFreeze;
        w.decodedOpcode := sampledDecodedOpcode;
        w.stackOperation := sampledStackOperation;
        w.spOffset := sampledspOffset;
        w.tosSource := sampledTosSource;
        -- Reset IDIM if we're jumping. Also don't set if we are injecting a Pop instruction
        if decode_jump='1' then
          w.idim := '0';
        else
          if rom_wb_ack_i='1' and jump_q='0' then
            w.idim := sampledOpcode(7);
          end if;
        end if;

      end if;

    end if;

    if rising_edge(wb_clk_i) then
      decr <= w;
      jump_q <= decode_jump;
    end if;

  end process;


  -- Prefetch/Load unit.
  
  sp_pushsp <= prefr.spnext - 1;
  sp_popsp <= prefr.spnext + 1;
  sp_dualpopsp <= prefr.spnext + 2;
  sp_load <= exr.tos(spMaxBit downto 2); -- Will be delayed

  process(wb_clk_i, wb_rst_i, decr, prefr, sp_popsp, sp_pushsp, sp_dualpopsp, decode_freeze, decode_jump, sp_load,
          decode_load_sp)
    variable w: prefetchregs_type;
  begin
    w := prefr;

    sampledStackBAddress <= std_logic_vector(sp_popsp);

    if wb_rst_i='1' then
      w.spnext := unsigned(spStart(10 downto 2));
      w.sp := unsigned(spStart(10 downto 2));
      w.valid := '0';
      w.idim := '0';
      w.recompute_sp:='0';
    else
      w.recompute_sp:='0';
      if decr.valid='1' then

        -- Stack
        w.load := decode_load_sp;

        if decode_load_sp='1' then
          w.spnext := sp_load;
          w.recompute_sp := '1';
        else
          if (decode_freeze='0' and decode_jump='0') or prefr.recompute_sp='1' then
            case decr.stackOperation is
              when Stack_Push =>
                w.spnext := sp_pushsp;
              when Stack_Pop =>
                w.spnext := sp_popsp;
              when Stack_DualPop =>
                w.spnext := sp_dualpopsp;
              when others =>
            end case;
            w.sp := prefr.spnext;
          end if;
        end if;
      end if;

      case decr.decodedOpcode is
        when Decoded_LoadSP | decoded_AddSP =>
            sampledStackBAddress <= std_logic_vector(prefr.spnext + decr.spOffset);
        when others =>
      end case;

      if decode_jump='1' then
        w.valid := '0';
      else
        w.valid := decr.valid;
      end if;
      
      if decode_freeze='0' then
        w.decodedOpcode := decr.decodedOpcode;
        w.tosSource := decr.tosSource;
        w.opcode := decr.opcode;
        w.opWillFreeze := decr.opWillFreeze;
        w.pc := decr.pc;
        w.fetchpc := decr.pcint;
        w.idim := decr.idim;
      end if;
    end if;

    if rising_edge(wb_clk_i) then
      prefr <= w;
    end if;
   
  end process;

  process(prefr,exr,nos)
  begin
        trace_pc <= (others => '0');
        trace_pc(maxAddrBit downto 0) <= std_logic_vector(prefr.pc);
        trace_opcode <= prefr.opcode;
        trace_sp <= (others => '0');
        trace_sp(10 downto 2) <= std_logic_vector(prefr.sp);
        trace_topOfStack <= std_logic_vector( exr.tos );
        trace_topOfStackB <= std_logic_vector( nos );
  end process;

  -- IO/Memory Accesses

  -- wb_adr_o(maxAddrBitIncIO downto 0) <= std_logic_vector(exr.tos(maxAddrBitIncIO downto 0));
  wb_adr_o(maxAddrBitIncIO downto 0) <= std_logic_vector(exr.tos_save(maxAddrBitIncIO downto 0));
  wb_cyc_o_i <= exr.wb_cyc;
  wb_stb_o <= exr.wb_stb;
  wb_we_o <= exr.wb_we;
  --wb_dat_o <= std_logic_vector( nos );
  wb_dat_o <= std_logic_vector( exr.nos_save );

  freeze_all <= dbg_freeze;

  process(exr, wb_inta_i, wb_clk_i, wb_rst_i, pcnext, stack_a_read,stack_b_read,
          wb_ack_i, wb_dat_i, do_interrupt,exr, prefr, nos,
          single_step, freeze_all, dbg_step, wroteback_q,lshifter_done,lshifter_output)
    variable spOffset: unsigned(4 downto 0);
    variable w: zpuregs;
    variable instruction_executed: std_logic;
    variable wroteback: std_logic;
  begin

    w := exr;

    instruction_executed := '0';

    stack_b_writeenable <= '0';
    stack_a_enable <= '1';
    stack_b_enable <= '1';

    decode_freeze <= '0';
    decode_jump <= '0';

    jump_address <= (others => DontCareValue);

    lshifter_enable <= '0';
    lshifter_amount <= std_logic_vector(exr.tos_save(4 downto 0));
    lshifter_input <= std_logic_vector(exr.nos_save);

    poppc_inst <= '0';
    begin_inst<='0';

    stack_a_addr <= std_logic_vector( prefr.sp );

    stack_a_writeenable <= '0';
    wroteback := wroteback_q;

    stack_b_writeenable <= '0';
    stack_a_write <= std_logic_vector(exr.tos);

    spOffset(4):=not prefr.opcode(4);
    spOffset(3 downto 0) := unsigned(prefr.opcode(3 downto 0));

    if wb_inta_i='0' then
      w.inInterrupt := '0';
    end if;

    stack_b_write<=(others => DontCareValue);

    if wroteback_q='1' then
      nos <= unsigned(stack_a_read);
    else
      nos <= unsigned(stack_b_read);
    end if;


    decode_load_sp <= '0';

    case exr.state is

      when State_Resync1 =>
        decode_freeze <= '1';

        stack_a_enable<='1';
        w.state := State_Resync2;
        wroteback := '0';

      when State_ResyncFromStoreStack =>
        decode_freeze <= '1';
        stack_a_addr <= std_logic_vector(prefr.spnext);
        stack_a_enable<='1';
        w.state := State_Resync2;
        wroteback := '0';

      when State_Resync2 =>

        w.tos := unsigned(stack_a_read);
        instruction_executed := '1';
        decode_freeze <= '0';
        wroteback := '0';
        stack_b_enable <= '1';
        w.state := State_Execute;

      when State_Execute =>
       instruction_executed:='0';

       if prefr.valid='1' then

        decode_freeze <= prefr.opWillFreeze;

        if freeze_all='0' or single_step='1' then

        wroteback := '0';
        w.idim := '0';
        w.nos_save := nos;
        w.tos_save := exr.tos;

        begin_inst<='1';

        instruction_executed := '1';

        -- TOS
        case prefr.tosSource is
          when Tos_Source_PC =>
            w.tos := (others => '0');
            w.tos(maxAddrBit downto 0) := prefr.pc;

          when Tos_Source_FetchPC =>
            w.tos := (others => '0');
            w.tos(maxAddrBit downto 0) := prefr.fetchpc;

          when Tos_Source_Idim0 =>
            for i in wordSize-1 downto 7 loop
              w.tos(i) := prefr.opcode(6);
            end loop;
            w.tos(6 downto 0) := unsigned(prefr.opcode(6 downto 0));

          when Tos_Source_IdimN =>
            w.tos(wordSize-1 downto 7) := exr.tos(wordSize-8 downto 0);
            w.tos(6 downto 0) := unsigned(prefr.opcode(6 downto 0));

          when Tos_Source_StackB =>
            w.tos := nos;

          when Tos_Source_SP =>
            w.tos := (others => '0');
            w.tos(31) := '1'; -- Stack address
            w.tos(10 downto 2) := prefr.sp;

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
            w.tos := unsigned(stack_b_read);

          when Tos_Source_AddSP =>
            w.tos := w.tos + unsigned(stack_b_read);

          when Tos_Source_AddStackB =>
            w.tos := w.tos + nos;

          when Tos_Source_Shift =>
            w.tos := exr.tos + exr.tos;
          when others =>

        end case;

        case prefr.decodedOpcode is

          when Decoded_Interrupt =>

           w.inInterrupt := '1';
           jump_address <= to_unsigned(32, maxAddrBit+1);
           decode_jump <= '1';
           stack_a_writeenable<='1';
           wroteback:='1';
           stack_b_enable<='0';
           instruction_executed := '0';
           w.state := State_WaitSPB;

          when Decoded_Im0 =>

            stack_a_writeenable<='1';
            wroteback:='1';

          when Decoded_ImN =>

          when Decoded_Nop =>

          when Decoded_PopPC | Decoded_Call =>

            decode_jump <= '1';
            jump_address <= exr.tos(maxAddrBit downto 0);
            poppc_inst <= '1';

            stack_b_enable<='0';

            -- Delay
            instruction_executed := '0';

            w.state := State_WaitSPB;

          when Decoded_Emulate =>

            decode_jump <= '1';
            jump_address <= (others => '0');
            jump_address(9 downto 5) <= unsigned(prefr.opcode(4 downto 0));

            stack_a_writeenable<='1';
            wroteback:='1';

          when Decoded_PushSP =>

            stack_a_writeenable<='1';
            wroteback:='1';

          when Decoded_LoadSP =>

            stack_a_writeenable <= '1';
            wroteback:='1';

          when Decoded_DupStackB =>

            stack_a_writeenable <= '1';
            wroteback:='1';

          when Decoded_Dup =>

            stack_a_writeenable<='1';
            wroteback:='1';

          when Decoded_AddSP =>

            stack_a_writeenable <= '1';

          when Decoded_StoreSP =>

            stack_a_writeenable <= '1';
            wroteback:='1';
            stack_a_addr <= std_logic_vector(prefr.sp + spOffset);
            instruction_executed := '0';
            w.state := State_WaitSPB;

          when Decoded_PopDown =>

            stack_a_writeenable<='1';

          when Decoded_Pop =>

          when Decoded_Ashiftleft =>
            w.state := State_Ashiftleft;

          when Decoded_Store =>

            if exr.tos(31)='1' then
              stack_a_addr <= std_logic_vector(exr.tos(10 downto 2));
              stack_a_write <= std_logic_vector(nos);
              stack_a_writeenable<='1';
              w.state := State_ResyncFromStoreStack;
            else

              w.wb_we  := '1';
              w.wb_cyc := '1';
              w.wb_stb := '1';

              wroteback := wroteback_q; -- Keep WB
              stack_a_enable<='0';
              stack_a_addr  <= (others => DontCareValue);
              stack_a_write <= (others => DontCareValue);

              stack_b_enable<='0';

              instruction_executed := '0';
              w.state := State_Store;

            end if;

          when Decoded_Load | Decoded_Loadb | Decoded_StoreB =>

            --w.tos_save := exr.tos; -- Byte select

            instruction_executed := '0';
            wroteback := wroteback_q; -- Keep WB

            if exr.tos(wordSize-1)='1' then
              stack_a_addr<=std_logic_vector(exr.tos(10 downto 2));
              stack_a_enable<='1';
              w.state := State_LoadStack;
            else
              stack_a_enable <= '0';
              stack_a_addr  <= (others => DontCareValue);
              stack_a_write <= (others => DontCareValue);

              w.wb_we  :='0';
              w.wb_cyc :='1';
              w.wb_stb :='1';
              w.state := State_Load;
            end if;

          when Decoded_PopSP =>

            decode_load_sp <= '1';
            instruction_executed := '0';
            stack_a_addr <= std_logic_vector(exr.tos(10 downto 2));
            w.state := State_Resync2;

          when Decoded_Break =>

            w.break := '1';

          when Decoded_Neqbranch =>
            
            instruction_executed := '0';
            w.state := State_NeqBranch;

          when others =>

        end case;
      else -- freeze_all
        --
        -- Freeze the entire pipeline.
        --
        decode_freeze<='1';
        stack_a_enable<='0';
        stack_b_enable<='0';
        stack_a_addr  <= (others => DontCareValue);
        stack_a_write <= (others => DontCareValue);

       end if;
       end if; -- valid

      when State_Ashiftleft =>
        decode_freeze <= '1';
        lshifter_enable <= '1';

        if lshifter_done='1' then
          decode_freeze<='0';
          w.tos := unsigned(lshifter_output);
          w.state := State_Execute;
        end if;

      when State_WaitSPB =>

        instruction_executed:='1';
        wroteback := '0';
        w.state := State_Execute;
  
      when State_Store =>
        

        decode_freeze <= '1';

        
        -- Keep writeback flag
        wroteback := wroteback_q;

        if wb_ack_i='1' then
          stack_a_addr <= std_logic_vector(prefr.spnext);
          stack_a_enable<='1';
          stack_b_enable<='1';
          wroteback := '0';
          --decode_freeze <= '1';
          w.wb_cyc := '0';
          w.state := State_Resync2;
        else
          stack_a_addr  <= (others => DontCareValue);
          stack_a_write <= (others => DontCareValue);
          stack_a_enable<='0';
          stack_b_enable<='0';
        end if;

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

      when State_Load =>

          if wb_ack_i='0' then
            decode_freeze<='1';
          else
            w.tos := unsigned(wb_dat_i);
            w.wb_cyc := '0';

            if prefr.decodedOpcode=Decoded_Loadb then
              decode_freeze<='1';
              w.state := State_Loadb;
            elsif prefr.decodedOpcode=Decoded_Storeb then
              decode_freeze<='1';
              w.state := State_Storeb;
            else
              instruction_executed:='1';
              wroteback := '0';
              w.state := State_Execute;
            end if;

          end if;

      when State_LoadStack =>
        w.tos := unsigned(stack_a_read);

        if prefr.decodedOpcode=Decoded_Loadb then
          decode_freeze<='1';
          w.state:=State_Loadb;
        elsif prefr.decodedOpcode=Decoded_Storeb then
          decode_freeze<='1';
          w.state:=State_Storeb;
        else
          instruction_executed:='1';
          wroteback := '0';
          w.state := State_Execute;
        end if;

      when State_NeqBranch =>
        if exr.nos_save/=0 then
          decode_jump <= '1';
          jump_address <= exr.tos(maxAddrBit downto 0) + prefr.pc;
          poppc_inst <= '1';
          decode_freeze <= '0';
        else
          decode_freeze <='1';
        end if;

        instruction_executed := '0';

        stack_a_addr <= std_logic_vector(prefr.spnext);
        wroteback:='0';
        w.state := State_Resync2;

      when State_StoreB =>
        decode_freeze <= '1';
        --
        -- At this point, we have loaded the 32-bit, and it's in TOS
        -- The IO address is still saved in save_TOS.
        -- The original write value is still at save_NOS
        --
        -- So we mangle the write value, and update save_NOS, and restore
        -- the IO address to TOS
        --
        -- This is still buggy - don't use. Problems arise when writing to stack.
        --

        w.nos_save := exr.tos;

        case exr.tos_save(1 downto 0) is
          when "00" =>
            w.nos_save(31 downto 24) := exr.nos_save(7 downto 0);
          when "01" =>
            w.nos_save(23 downto 16) := exr.nos_save(7 downto 0);
          when "10" =>
            w.nos_save(15 downto 8) := exr.nos_save(7 downto 0);
          when "11" =>
            w.nos_save(7 downto 0) := exr.nos_save(7 downto 0);
          when others =>
            null;
        end case;


      when others =>
         null;

    end case;


    if rising_edge(wb_clk_i) then
      if wb_rst_i='1' then
        exr.state <= State_Execute;
        exr.idim <= '0';
        exr.inInterrupt <= '0';
        exr.break <= '0';
        exr.wb_cyc <= '0';
        exr.wb_stb <= '1';
      else
        exr <= w;
        wroteback_q <= wroteback;

        if exr.break='1' then
          report "BREAK" severity failure;
        end if;
      end if;
    end if;

  end process;

  sstep: pulse
    port map (
      pulse_in => dbg_step,
      pulse_out => single_step,
      clk => wb_clk_i,
      rst => wb_rst_i
    );

end behave;

