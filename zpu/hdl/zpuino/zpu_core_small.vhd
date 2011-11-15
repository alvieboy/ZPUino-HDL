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

    stack_a_read: in std_logic_vector(wordSize-1 downto 0);
    stack_b_read: in std_logic_vector(wordSize-1 downto 0);
    stack_a_write: out std_logic_vector(wordSize-1 downto 0);
    stack_b_write: out std_logic_vector(wordSize-1 downto 0);
    stack_a_writeenable: out std_logic;
    stack_a_enable: out std_logic;
    stack_b_writeenable: out std_logic;
    stack_b_enable: out std_logic;
    stack_a_addr: out std_logic_vector(stackSize_bits-1+2 downto 2);  -- Helps debugging
    stack_b_addr: out std_logic_vector(stackSize_bits-1+2 downto 2);
    stack_clk: out std_logic;

    -- Debug interface

    dbg_pc:         out std_logic_vector(maxAddrBit downto 0);
    dbg_opcode:     out std_logic_vector(7 downto 0);
    dbg_sp:         out std_logic_vector(10 downto 2);
    dbg_brk:        out std_logic;
    dbg_stacka:     out std_logic_vector(wordSize-1 downto 0);
    dbg_stackb:     out std_logic_vector(wordSize-1 downto 0)

  );
end zpu_core_small;

architecture behave of zpu_core_small is

signal memAWriteEnable:     std_logic;
signal memAWriteMask:       std_logic_vector(3 downto 0);
signal memAAddr:            unsigned(maxAddrBit downto minAddrBit);
signal memAWrite:           unsigned(wordSize-1 downto 0);
signal memARead:            unsigned(wordSize-1 downto 0);
signal memAEnable:          std_logic;

signal memBEnable:          std_logic;
signal memBWriteEnable:     std_logic;
signal memBWriteMask:       std_logic_vector(3 downto 0);
signal memBAddr:            unsigned(maxAddrBit downto minAddrBit);
signal memBWrite:           unsigned(wordSize-1 downto 0);
signal memBRead:            unsigned(wordSize-1 downto 0);

--signal busy:                std_logic;
signal begin_inst:          std_logic;

signal trace_opcode:        std_logic_vector(7 downto 0);
signal trace_pc:            std_logic_vector(maxAddrBitIncIO downto 0);
signal trace_sp:            std_logic_vector(maxAddrBitIncIO downto minAddrBit);
signal trace_topOfStack:    std_logic_vector(wordSize-1 downto 0);
signal trace_topOfStackB:   std_logic_vector(wordSize-1 downto 0);

signal doInterrupt:         std_logic;

-- state machine.
type State_Type is
(
State_Start,
State_Execute,
State_Store,
State_Load,
State_Loadb,
State_AddSP,
State_Resync1,
State_Resync2,
State_LoadSP,
State_WaitSP,
State_WaitSPB,
State_Pop
);

type DecodedOpcodeType is
(
Decoded_Nop,
Decoded_Idle,
Decoded_Im,
Decoded_LoadSP,
Decoded_Dup,
Decoded_DupStackB,
Decoded_StoreSP,
Decoded_Pop,
Decoded_PopDown,
Decoded_StoreSP8,
Decoded_AddSP,
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
--Decoded_Interrupt,
Decoded_Neqbranch,
Decoded_Eq,
Decoded_Storeb,
Decoded_Storeh,
Decoded_Ulessthan,
Decoded_Ashiftleft,
Decoded_Ashiftright,
Decoded_Loadb,
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
  state:      State_Type;
  stack_a_writeenable_q: std_logic;
  decode_load_sp: std_logic;
end record;

signal exr: zpuregs;

constant minimal_implementation: boolean := true;

subtype index is integer range 0 to 3;

signal tOpcode_sel : index;
--signal inInterrupt : std_logic;

function pc_to_cpuword(pc: unsigned) return unsigned is
  variable r: unsigned(wordSize-1 downto 0);
begin
  r := (others => DontCareValue);
  r(maxAddrBit downto 0) := pc;
  return r;
end pc_to_cpuword;

function pc_to_memaddr(pc: unsigned) return unsigned is
  variable r: unsigned(maxAddrBit downto minAddrBit);
begin
  r := (others => '0');
  r(maxAddrBit downto minAddrBit) := pc(maxAddrBit downto minAddrBit);
  return r;
end pc_to_memaddr;

-- Prefetch stage registers

type stackChangeType is (
  Stack_Same,
  Stack_Push,
  Stack_Pop
);

type decoderegs_type is record

  valid:          std_logic;
  validmem:       std_logic;
  decodedOpcode:  DecodedOpcodeType;
  opcode:         std_logic_vector(OpCode_Size-1 downto 0);
  pc:             unsigned(maxAddrBit downto 0);
  fetchpc:        unsigned(maxAddrBit downto 0);
  idim:           std_logic;
  stackOperation: stackChangeType;
  spOffset:       unsigned(4 downto 0);

end record;

type prefetchregs_type is record
  sp:             unsigned(spMaxBit downto 2);
  spnext:         unsigned(spMaxBit downto 2);
  valid:          std_logic;
  decodedOpcode:  DecodedOpcodeType;
  opcode:         std_logic_vector(OpCode_Size-1 downto 0);
  pc:             unsigned(maxAddrBit downto 0);
  fetchpc:        unsigned(maxAddrBit downto 0);
  idim:           std_logic;
  load:           std_logic;
end record;

signal prefr: prefetchregs_type;

signal sampledStackBAddress: std_logic_vector(stackSize_bits-1+2 downto 2);

signal decr: decoderegs_type;
signal sp_pushsp, sp_popsp,  sp_load:  unsigned(spMaxBit downto 2);

signal decode_freeze: std_logic;
signal decode_jump: std_logic;
signal jump_address: unsigned(maxAddrBit downto 0);
signal decode_force_pop: std_logic;

--signal topOfStack_write: unsigned(wordSize-1 downto 0);
--signal topOfStack_read: unsigned(wordSize-1 downto 0);

--signal stack_b_addr_is_offset: std_logic;

signal mult0,mult1,mult2,mult3: unsigned(31 downto 0);
signal wb_cyc_o_i: std_logic;


subtype AddrBitBRAM_range is natural range maxAddrBitBRAM downto minAddrBit;
signal memAAddr_stdlogic  : std_logic_vector(AddrBitBRAM_range);
signal memAWrite_stdlogic : std_logic_vector(memAWrite'range);
signal memARead_stdlogic  : std_logic_vector(memARead'range);
signal memBAddr_stdlogic  : std_logic_vector(AddrBitBRAM_range);
signal memBWrite_stdlogic : std_logic_vector(memBWrite'range);
signal memBRead_stdlogic  : std_logic_vector(memBRead'range);

signal do_interrupt: std_logic;


signal sampledStackOperation: stackChangeType;
signal sampledspOffset: unsigned(4 downto 0);

signal nos: unsigned(wordSize-1 downto 0);

begin

  -- Debug interface

  dbg_pc <= std_logic_vector(prefr.pc);
  dbg_opcode <= prefr.opcode;
  dbg_sp <= std_logic_vector(prefr.sp);
  dbg_brk <= exr.break;
  dbg_stacka <= std_logic_vector(exr.tos);
  dbg_stackb <= std_logic_vector(nos);

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


  memAAddr_stdlogic  <= std_logic_vector(memAAddr(AddrBitBRAM_range));
  memAWrite_stdlogic <= std_logic_vector(memAWrite);
  memBAddr_stdlogic  <= std_logic_vector(memBAddr(AddrBitBRAM_range));
  memBWrite_stdlogic <= std_logic_vector(memBWrite);
  
  memory: dualport_ram
    port map (
      clk => wb_clk_i,
      memAWriteEnable => memAWriteEnable,
      memAWriteMask => memAWriteMask,
      memAWrite => memAWrite_stdlogic,
      memAAddr => memAAddr_stdlogic,
      memARead => memARead_stdlogic,
      memAEnable => memAEnable,
      memBEnable => memBEnable,
      memBWriteEnable => memBWriteEnable,
      memBAddr => memBAddr_stdlogic,
      memBWrite => memBWrite_stdlogic,
      memBRead => memBRead_stdlogic,
      memBWriteMask => memBWriteMask,
      memErr => open
    );

  memARead <= unsigned(memARead_stdlogic);
  memBRead <= unsigned(memBRead_stdlogic);
  wb_cyc_o <= wb_cyc_o_i;

  tOpcode_sel <= to_integer(decr.fetchpc(minAddrBit-1 downto 0));

  stack_b_addr <= std_logic_vector(sp_load) when exr.decode_load_sp='1' else sampledStackBAddress;

  -- move out calculation of the opcode to a seperate process
  -- to make things a bit easier to read
  decodeControl:
  process(memBRead, tOpcode_sel, sp_load, sp_popsp, exr.decode_load_sp,decr)
    variable tOpcode : std_logic_vector(OpCode_Size-1 downto 0);
    variable localspOffset: unsigned(4 downto 0);
  begin

    --if decode_load_sp='1' then
    --  stack_b_addr <= std_logic_vector(sp_load);
    --else
    --  stack_b_addr <= std_logic_vector(sp_popsp);
    --end if;
    --sampledStackBAddress <= std_logic_vector(sp_popsp);

      case (tOpcode_sel) is

            when 0 => tOpcode := std_logic_vector(memBRead(31 downto 24));

            when 1 => tOpcode := std_logic_vector(memBRead(23 downto 16));

            when 2 => tOpcode := std_logic_vector(memBRead(15 downto 8));

            when 3 => tOpcode := std_logic_vector(memBRead(7 downto 0));

            when others =>
              tOpcode := std_logic_vector(memBRead(7 downto 0));
       end case;

    sampledOpcode <= tOpcode;
    --sampledNeedStackB <= '0';
    sampledStackOperation <= Stack_Same;

    localspOffset(4):=not tOpcode(4);
    localspOffset(3 downto 0) := unsigned(tOpcode(3 downto 0));

    if (tOpcode(7 downto 7)=OpCode_Im) then
      sampledDecodedOpcode<=Decoded_Im;

      if decr.idim='0' then
        sampledStackOperation <= Stack_Push;
      end if;
      
    elsif (tOpcode(7 downto 5)=OpCode_StoreSP) then

      sampledStackOperation <= Stack_Pop;

      if localspOffset=0 then
        sampledDecodedOpcode<=Decoded_Pop;
      elsif localspOffset=1 then
        sampledDecodedOpcode<=Decoded_PopDown;
      else
        sampledDecodedOpcode<=Decoded_StoreSP;
      end if;
    elsif (tOpcode(7 downto 5)=OpCode_LoadSP) then

      sampledStackOperation <= Stack_Push;

      if localspOffset=0 then
        sampledDecodedOpcode<=Decoded_Dup;
      elsif localspOffset=1 then
        sampledDecodedOpcode<=Decoded_DupStackB;
      else
        sampledDecodedOpcode<=Decoded_LoadSP;
        --if decode_load_sp='0' then
        --sampledStackBAddress <= std_logic_vector(decr.spnext + localspOffset);

        --end if;
     
      end if;


    elsif (tOpcode(7 downto 5)=OpCode_Emulate) then

      -- Emulated instructions implemented in hardware
      if minimal_implementation then
        sampledDecodedOpcode<=Decoded_Emulate;
        sampledStackOperation<=Stack_Push; -- will push PC
      else
      report "error" severity failure; -- TODO

      if (tOpcode(5 downto 0)=OpCode_Neqbranch) then
        sampledDecodedOpcode<=Decoded_Neqbranch;

      elsif (tOpcode(5 downto 0)=OpCode_Eq) then
        sampledDecodedOpcode<=Decoded_Eq;

--      elsif (tOpcode(5 downto 0)=OpCode_Storeb) then
--        sampledDecodedOpcode<=Decoded_Storeb;

--      elsif (tOpcode(5 downto 0)=OpCode_Storeh) then
--        sampledDecodedOpcode<=Decoded_Storeh;

      elsif (tOpcode(5 downto 0)=OpCode_Ulessthan) then
        sampledDecodedOpcode<=Decoded_Ulessthan;

--      elsif (tOpcode(5 downto 0)=OpCode_Ashiftleft) then
--        sampledDecodedOpcode<=Decoded_Ashiftleft;

      elsif (tOpcode(5 downto 0)=OpCode_Loadb) then
        sampledDecodedOpcode<=Decoded_Loadb;

--      elsif (tOpcode(5 downto 0)=OpCode_Mult) then
--        sampledDecodedOpcode<=Decoded_Mult;

      else
        sampledDecodedOpcode<=Decoded_Emulate;
      end if;
      end if;
    elsif (tOpcode(7 downto 4)=OpCode_AddSP) then
      if localspOffset=0 then
        sampledDecodedOpcode<=Decoded_Shift;
      else
        -- TODO: include addspB
        --sampledStackBAddress <= std_logic_vector(decr.spnext + localspOffset);
        sampledDecodedOpcode<=Decoded_AddSP;
      end if;
    else
      case tOpcode(3 downto 0) is
        when OpCode_Break =>
          sampledDecodedOpcode<=Decoded_Break;
        when OpCode_PushSP =>
          sampledStackOperation <= Stack_Push;
          sampledDecodedOpcode<=Decoded_PushSP;
        when OpCode_PopPC =>
          sampledStackOperation <= Stack_Pop;
          sampledDecodedOpcode<=Decoded_PopPC;
        when OpCode_Add =>
          sampledStackOperation <= Stack_Pop;
          sampledDecodedOpcode<=Decoded_Add;
        when OpCode_Or =>
          sampledStackOperation <= Stack_Pop;
          sampledDecodedOpcode<=Decoded_Or;
        when OpCode_And =>
          sampledStackOperation <= Stack_Pop;
          sampledDecodedOpcode<=Decoded_And;
        when OpCode_Load =>
          sampledDecodedOpcode<=Decoded_Load;
        when OpCode_Not =>
          sampledDecodedOpcode<=Decoded_Not;
        when OpCode_Flip =>
          sampledDecodedOpcode<=Decoded_Flip;
        when OpCode_Store =>
          sampledStackOperation <= Stack_Pop;   -- Dual pop, actually
          sampledDecodedOpcode<=Decoded_Store;
        when OpCode_PopSP =>
          sampledDecodedOpcode<=Decoded_PopSP;
        when others =>
          sampledDecodedOpcode<=Decoded_Nop;
      end case;
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

  
  sp_pushsp <= prefr.spnext - 1;
  sp_popsp <= prefr.spnext + 1;
  sp_load <= exr.tos(spMaxBit downto 2); -- Will be delayed

  memBEnable <= not decode_freeze;

  process(decr, jump_address, decode_jump, wb_clk_i, sp_load,
          sp_pushsp,sp_popsp,sampledDecodedOpcode,sampledOpcode,exr.decode_load_sp,decode_freeze,
          pcnext, wb_rst_i, sampledStackOperation, decode_force_pop, sampledspOffset
          )
    variable w: decoderegs_type;
  begin

    w := decr;

    if decode_jump='1' then
      pcnext <= jump_address;
    else
      pcnext <= decr.fetchpc + 1;
    end if;

    memBAddr <= pc_to_memaddr(pcnext);

    if wb_rst_i='1' then
      w.pc     := (others => '0');
      w.valid  := '0';
      w.validmem  := '0';
      w.fetchpc := (others => '1');
    else

      if decode_freeze='0' then
        w.fetchpc := pcnext;
      end if;

      if decode_freeze='0' then

        if decode_jump='1' then
          w.validmem := '1';
          w.valid := '0';
        else
          w.validmem := '1';
          w.valid := decr.validmem;
        end if;

        if decode_jump='0' then
          w.pc := decr.fetchpc;
        end if;

        w.opcode := sampledOpcode;
        w.decodedOpcode := sampledDecodedOpcode;
        w.stackOperation := sampledStackOperation;
        w.spOffset := sampledspOffset;
        -- Reset if we're jumping
        if decode_jump='1' then
          w.idim := '0';
        else
          w.idim := sampledOpcode(7);
        end if;

      end if;

      
    end if;

    if rising_edge(wb_clk_i) then
      decr <= w;
    end if;

  end process;


  -- Prefetch

  process(wb_clk_i, wb_rst_i, decr, prefr, sp_popsp, sp_pushsp, decode_freeze, decode_jump, sp_load,
          exr.decode_load_sp, decode_force_pop)
    variable w: prefetchregs_type;
  begin
    w := prefr;
    sampledStackBAddress <= std_logic_vector(sp_popsp);

    if wb_rst_i='1' then
      w.spnext := unsigned(spStart(10 downto 2));
      w.sp := unsigned(spStart(10 downto 2));
    else

      if decr.valid='1' then

        -- Stack
        w.load := exr.decode_load_sp;

        if exr.decode_load_sp='1' then
          w.spnext := sp_load;
        elsif decode_force_pop='1' then
          w.spnext := sp_popsp;
        else
          if (decode_freeze='0' and decode_jump='0') or prefr.load='1' then
            case decr.stackOperation is
              when Stack_Push =>
                w.spnext := sp_pushsp;
              when Stack_Pop =>
                w.spnext := sp_popsp;
              when others =>
            end case;
            w.sp := prefr.spnext;
          end if;
        end if;
      end if;

      case decr.decodedOpcode is
        when Decoded_LoadSP | decoded_AddSP =>
          if decode_force_pop='0' then
            sampledStackBAddress <= std_logic_vector(prefr.spnext + decr.spOffset);
          end if;
        when others =>
      end case;

      if decode_jump='1' then
        w.valid := '0';
      else
        w.valid := decr.valid;
      end if;
      
      if decode_freeze='0' then
        w.decodedOpcode := decr.decodedOpcode;
        w.opcode := decr.opcode;
        w.pc := decr.pc;
        w.fetchpc := decr.fetchpc;
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

  memAAddr <= exr.tos(maxAddrBit downto minAddrBit);

  -- IO Accesses
  wb_adr_o(maxAddrBitIncIO downto 0) <= std_logic_vector(exr.tos(maxAddrBitIncIO downto 0));

  do_interrupt <= '1' when wb_inta_i='1' and exr.idim='0' and exr.inInterrupt='0' and prefr.valid='1' else '0';

  process(exr, wb_inta_i, wb_clk_i, wb_rst_i, pcnext, stack_a_read,stack_b_read,
          wb_ack_i, memARead, wb_dat_i, do_interrupt,exr, prefr)
    variable spOffset: unsigned(4 downto 0);
    variable w: zpuregs;
    variable operandb: unsigned(31 downto 0);
  begin

    w := exr;

    memBWrite <= (others => '0');
    memBWriteEnable <= '0';
    memAWriteMask <= (others => '1');
    memBWriteMask <= (others => '1');

    stack_b_writeenable <= '0';
    stack_a_enable <= '1';
    stack_b_enable <= '1';

    decode_freeze <= '0';
    decode_jump <= '0';

    jump_address <= (others => DontCareValue);

    wb_cyc_o_i <= '0';
    wb_stb_o <= '0';
    wb_we_o <= DontCareValue;

    poppc_inst <= '0';
    begin_inst<='0';
    w.decode_load_sp := '0';

    stack_a_addr <= std_logic_vector( prefr.sp );

    stack_a_writeenable <= '0';
    w.stack_a_writeenable_q:='0';

    memAEnable <= '1'; -- TODO: optimize this for power. (move up in the pipeline)

    stack_b_writeenable <= '0';
    stack_a_write <= std_logic_vector(exr.tos);
    decode_force_pop<='0';

    doInterrupt <= '0';

    spOffset(4):=not prefr.opcode(4);
    spOffset(3 downto 0) := unsigned(prefr.opcode(3 downto 0));

    if wb_inta_i='0' then
      w.inInterrupt := '0';
    end if;

    stack_b_write<=(others => DontCareValue);

    if exr.stack_a_writeenable_q='1' then
      operandb := unsigned(stack_a_read);
    else
      operandb := unsigned(stack_b_read);
    end if;

    nos <= operandb;
    wb_dat_o <= std_logic_vector( nos );

    memAWrite<=nos;
    memAWriteEnable<='0';

    case exr.state is

      when State_Resync1 | State_Start  =>
        decode_freeze <= '1';
        w.state := State_Resync2;

      when State_Resync2 =>
        w.tos := unsigned(stack_b_read);
        w.state := State_Execute;

      when State_Pop =>

      when State_Execute =>

        if prefr.valid='1' then

        w.idim := '0';

        begin_inst<='1';

        if do_interrupt='1' then

           w.inInterrupt := '1';
           jump_address <= to_unsigned(32, maxAddrBit+1);
           decode_jump <= '1';

           report "Interrupt" severity note;

           w.tos := (others => '0');
           w.tos(maxAddrBit downto 0) := prefr.pc;

        else

        case prefr.decodedOpcode is
          when Decoded_Im =>

            w.idim := '1';

            if exr.idim='0' then

                for i in wordSize-1 downto 7 loop
                  w.tos(i) := prefr.opcode(6);
                end loop;

                w.tos(6 downto 0) := unsigned(prefr.opcode(6 downto 0));

                stack_a_writeenable<='1';
                w.stack_a_writeenable_q:='1';

              else
                w.tos(wordSize-1 downto 7) := exr.tos(wordSize-8 downto 0);
                w.tos(6 downto 0) := unsigned(prefr.opcode(6 downto 0));

              end if;

          when Decoded_Nop =>

          when Decoded_PopPC =>

            decode_jump <= '1';
            jump_address <= exr.tos(maxAddrBit downto 0);
            poppc_inst <= '1';

            w.tos := operandb;
            stack_b_enable<='0';

            -- Delay

            w.state := State_WaitSPB;

          when Decoded_Emulate =>

            decode_jump <= '1';
            jump_address <= (others => '0');
            jump_address(9 downto 5) <= unsigned(prefr.opcode(4 downto 0));

            w.tos := (others => '0');
            w.tos(maxAddrBit downto 0) := prefr.fetchpc;
            stack_a_writeenable<='1';
            w.stack_a_writeenable_q:='1';

          when Decoded_PushSP =>

            w.tos := (others => '0');
            w.tos(31) := '1'; -- Stack address
            w.tos(10 downto 2) := prefr.sp;
            stack_a_writeenable<='1';
            w.stack_a_writeenable_q:='1';

          when Decoded_Add =>

            w.tos := exr.tos + operandb;

          when Decoded_And =>

            w.tos := exr.tos and operandb;

          when Decoded_Eq =>

            w.tos := (others => '0');
            if operandb = exr.tos then
              w.tos(0) := '1';
            end if;

          when Decoded_Ulessthan =>

            w.tos := (others => '0');
            if exr.tos < operandb then
              w.tos(0) := '1';
            end if;

          when Decoded_Or =>

            w.tos := exr.tos or operandb;

          when Decoded_Not =>

            w.tos := not exr.tos;

          when Decoded_Flip =>
            for i in 0 to wordSize-1 loop
              w.tos(i) := exr.tos(wordSize-1-i);
            end loop;

          when Decoded_LoadSP =>

            w.tos := unsigned(stack_b_read);
            stack_a_writeenable <= '1';
            w.stack_a_writeenable_q:='1';

          when Decoded_DupStackB =>

            w.tos := operandb;
            stack_a_writeenable <= '1';
            w.stack_a_writeenable_q:='1';

          when Decoded_Dup =>

            stack_a_writeenable<='1';
            w.stack_a_writeenable_q:='1';

          when Decoded_AddSP =>

            w.tos := w.tos + unsigned(stack_b_read);
            stack_a_writeenable <= '1';

          when Decoded_Shift =>
            w.tos := exr.tos + exr.tos;

          when Decoded_StoreSP =>

            w.tos := operandb;
            stack_a_writeenable <= '1';
            w.stack_a_writeenable_q:='1';
            stack_a_addr <= std_logic_vector(prefr.sp + spOffset);
            decode_freeze <= '1';

            -- Delay so we can wait for Spb?
            w.state := State_WaitSPB;

          when Decoded_StoreSP8 =>

            w.tos := unsigned(stack_b_read);


          when Decoded_PopDown =>

            stack_a_writeenable<='1';

          when Decoded_Pop =>

            w.tos := operandb;

          when Decoded_Store =>

            if exr.tos(31)='1' then
              stack_a_addr <= std_logic_vector(exr.tos(10 downto 2));
              stack_a_write <= std_logic_vector(nos);
              stack_a_writeenable<='1';
              decode_freeze<='1';
              decode_force_pop<='1';

              w.state := State_Resync2;

            end if;

            if exr.tos(maxAddrBitIncIO)='1' then
              decode_freeze<='1';
              wb_we_o    <='1';
              wb_cyc_o_i <='1';
              wb_stb_o   <='1';

              -- Hold stack values
              stack_a_enable<='0';
              stack_b_enable<='0';
              w.state := State_Store;
            else
              memAWriteEnable<='1';
              decode_freeze<='1';
              decode_force_pop<='1';
              w.state := State_Resync2;
            end if;

          when Decoded_Load | Decoded_Loadb =>

            if exr.tos(maxAddrBitIncIO)='1' then
              wb_we_o <= '0';
              wb_cyc_o_i<='1';
              wb_stb_o<='1';
            end if;

            if exr.tos(wordSize-1)='1' then
              stack_a_addr<=std_logic_vector(exr.tos(10 downto 2));
            end if;


            decode_freeze<='1';
            w.state := State_Load;

          when Decoded_PopSP =>

            if prefr.sp /= exr.tos(spMaxBit downto 2) then
              decode_freeze <= '1';
              w.decode_load_sp := '1';

              w.state := State_Resync1;
            end if;

          when Decoded_Break =>
            w.break := '1';

          when Decoded_Neqbranch =>

            if unsigned(stack_b_read)/=0 then
              decode_jump <= '1';
              jump_address <= prefr.pc + exr.tos(maxAddrBit downto 0);
            else
              decode_freeze <= '1'; -- Going to Pop
            end if;

          when Decoded_Idle =>
            --w.idim := exr.idim;
          when others =>
            w.break := '1';

        end case;
        end if; -- interrupt
        end if; -- valid

      when State_WaitSP =>

        w.tos := unsigned(stack_a_read);
        w.state := State_Execute;


      when State_WaitSPB =>

        stack_b_enable<='0';
        w.state := State_Execute;
  
      when State_Store =>
        wb_cyc_o_i<='1';
        wb_stb_o<='1';
        wb_we_o <='1';
        
        stack_a_enable<='0';
        stack_b_enable<='0';

        if wb_ack_i='1' then
          w.state := State_Resync2;
          stack_a_enable<='0';
          stack_b_enable<='1';
          decode_force_pop<='1';
        end if;

        decode_freeze <= '1';

      when State_LoadSP =>

      when State_Load =>
        if exr.tos(maxAddrBitIncIO)='1' then
          wb_we_o <='0';
          wb_cyc_o_i<='1';
          wb_stb_o<='1';
          if wb_ack_i='0' then
            decode_freeze<='1'; -- Don't push ops while busy
          else
            w.tos := unsigned(wb_dat_i);
            w.state := State_Execute;
          end if;
        elsif exr.tos(wordSize-1)='1' then
          w.tos := unsigned(stack_a_read);
          w.state := State_Execute;
        else
          w.tos := memARead;
          w.state := State_Execute;
        end if;

      when others =>
         null;
    end case;

    if rising_edge(wb_clk_i) then
      if wb_rst_i='1' then
        exr.state <= State_Start;
        exr.idim <= '0';
        exr.inInterrupt <= '0';
        exr.break <= '0';
        exr.decode_load_sp <= '0';
      else
        exr <= w;
        if exr.break='1' then
          report "BREAK" severity failure;
        end if;
      end if;
    end if;

  end process;

end behave;

