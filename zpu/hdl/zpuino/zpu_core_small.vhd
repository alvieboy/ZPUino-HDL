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
    stack_b_writeenable: out std_logic;
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

signal io_we: std_logic;

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
--signal opcode: std_logic_vector(OpCode_Size-1 downto 0);

--signal decodedOpcode : DecodedOpcodeType;
signal i_decodedOpcode : DecodedOpcodeType;
signal sampledDecodedOpcode : DecodedOpcodeType;

--signal pc:         unsigned(maxAddrBit downto 0);
--signal pce:        unsigned(maxAddrBit downto 0);

signal pcnext:     unsigned(maxAddrBit downto 0);
constant spMaxBit: integer := 10;

type zpuregs is record
  idim:       std_logic;
  break:      std_logic;
  inInterrupt:std_logic;
  sp:         unsigned(spMaxBit downto 2);
  tos:        unsigned(wordSize-1 downto 0);
  --nos:        unsigned(wordSize-1 downto 0);
  state:      State_Type;
end record;

signal exr: zpuregs;

signal spnext:     unsigned(spMaxBit downto 2);
signal spnext_b:   unsigned(spMaxBit downto 2);

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

-- Decoder registers

type decoderegs_type is record

  freeze:         std_logic;
  valid:          std_logic;
  decodedOpcode:  DecodedOpcodeType;
  needStackB:     std_logic;
  opcode:         std_logic_vector(OpCode_Size-1 downto 0);
  pc:             unsigned(maxAddrBit downto 0);
  fetchpc:        unsigned(maxAddrBit downto 0);

end record;

signal decr: decoderegs_type;

signal decode_freeze: std_logic;
signal decode_jump: std_logic;
signal jump_address: unsigned(maxAddrBit downto 0);

--signal topOfStack_write: unsigned(wordSize-1 downto 0);
--signal topOfStack_read: unsigned(wordSize-1 downto 0);

signal stack_b_addr_is_offset: std_logic;

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
signal sampledNeedStackB: std_logic;

begin

  -- Debug interface

  dbg_pc <= std_logic_vector(decr.pc);
  dbg_opcode <= decr.opcode;
  dbg_sp <= std_logic_vector(exr.sp);
  dbg_brk <= exr.break;
  dbg_stacka <= std_logic_vector(exr.tos);
  dbg_stackb <= stack_b_read;

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

  -- move out calculation of the opcode to a seperate process
  -- to make things a bit easier to read
  decodeControl:
  process(memBRead, tOpcode_sel)
    variable tOpcode : std_logic_vector(OpCode_Size-1 downto 0);
    variable localspOffset: unsigned(4 downto 0);
  begin

        case (tOpcode_sel) is

            when 0 => tOpcode := std_logic_vector(memBRead(31 downto 24));

            when 1 => tOpcode := std_logic_vector(memBRead(23 downto 16));

            when 2 => tOpcode := std_logic_vector(memBRead(15 downto 8));

            when 3 => tOpcode := std_logic_vector(memBRead(7 downto 0));

            when others =>
              tOpcode := std_logic_vector(memBRead(7 downto 0));
       end case;

    sampledOpcode <= tOpcode;
    sampledNeedStackB <= '0';

    localspOffset(4):=not tOpcode(4);
    localspOffset(3 downto 0) := unsigned(tOpcode(3 downto 0));

    if (tOpcode(7 downto 7)=OpCode_Im) then
      sampledDecodedOpcode<=Decoded_Im;
      
    elsif (tOpcode(7 downto 5)=OpCode_StoreSP) then

      if localspOffset=0 then
        sampledDecodedOpcode<=Decoded_Pop;
      elsif localspOffset=1 then
        sampledDecodedOpcode<=Decoded_PopDown;
      else
        sampledDecodedOpcode<=Decoded_StoreSP;
      end if;
    elsif (tOpcode(7 downto 5)=OpCode_LoadSP) then

      if localspOffset=0 then
        sampledDecodedOpcode<=Decoded_Dup;
      else
        sampledDecodedOpcode<=Decoded_LoadSP;
      end if;


    elsif (tOpcode(7 downto 5)=OpCode_Emulate) then

      -- Emulated instructions implemented in hardware
      if minimal_implementation then
        sampledDecodedOpcode<=Decoded_Emulate;
      else
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
        sampledDecodedOpcode<=Decoded_AddSP;
      end if;
    else
      case tOpcode(3 downto 0) is
        when OpCode_Break =>
          sampledDecodedOpcode<=Decoded_Break;
        when OpCode_PushSP =>
          sampledDecodedOpcode<=Decoded_PushSP;
        when OpCode_PopPC =>
          sampledDecodedOpcode<=Decoded_PopPC;
        when OpCode_Add =>
          sampledDecodedOpcode<=Decoded_Add;
        when OpCode_Or =>
          sampledDecodedOpcode<=Decoded_Or;
        when OpCode_And =>
          sampledDecodedOpcode<=Decoded_And;
        when OpCode_Load =>
          sampledDecodedOpcode<=Decoded_Load;
        when OpCode_Not =>
          sampledDecodedOpcode<=Decoded_Not;
        when OpCode_Flip =>
          sampledDecodedOpcode<=Decoded_Flip;
        when OpCode_Store =>
          sampledDecodedOpcode<=Decoded_Store;
        when OpCode_PopSP =>
          sampledDecodedOpcode<=Decoded_PopSP;
        when others =>
          sampledDecodedOpcode<=Decoded_Nop;
      end case;
    end if;
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

  -- Decode unit

  -- Input: wait
  -- Input: jump

  process(decr, jump_address, decode_jump, wb_clk_i)
    variable w: decoderegs_type;
  begin

    w := decr;

    if decode_jump='1' then
      pcnext <= jump_address;
    else
      pcnext <= decr.fetchpc + 1;
    end if;

    if wb_rst_i='1' then
      w.pc     := (others => '0');
      w.valid  := '0';
      w.freeze := '1';
      w.fetchpc := (others => '1');
    else

      w.freeze := decode_freeze;

      if decode_freeze='0' then
        w.fetchpc := pcnext;
        --w.valid := not decode_jump;
      end if;

      if decr.freeze='0' then
        w.valid := not decode_jump;
        w.pc := decr.fetchpc;
        w.opcode := sampledOpcode;
        w.decodedOpcode := sampledDecodedOpcode;
      end if;

    end if;

    if rising_edge(wb_clk_i) then
      decr <= w;
    end if;

  end process;

  process(decr,exr)
  begin
        trace_pc <= (others => '0');
        trace_pc(maxAddrBit downto 0) <= std_logic_vector(decr.pc);
        trace_opcode <= decr.opcode;
        trace_sp <= (others => '0');
        trace_sp(10 downto 2) <= std_logic_vector(exr.sp);
        trace_topOfStack <= std_logic_vector( exr.tos );
        trace_topOfStackB <= std_logic_vector( stack_b_read );
  end process;

  --process(i_decodedOpcode, decode_valid_q )
  --begin
  --  if decode_valid_q='1' then
  --    decodedOpcode <= i_decodedOpcode;
  --  else
  --    decodedOpcode <= Decoded_Idle;
  --  end if;
  --end process;


--  stack_b_addr <= std_logic_vector(spnext_b);

--  process(spnext,state,sp,opcode,stack_b_addr_is_offset)
--    variable spOffset: unsigned(4 downto 0);
--  begin
--    if state=State_Resync1 then
--      stack_a_addr(8 downto 0) <= std_logic_vector(sp(10 downto 2));
--    else
--      stack_a_addr(8 downto 0) <= std_logic_vector(spnext(10 downto 2));
--    end if;
--  end process;

  memAAddr <= exr.tos(maxAddrBit downto minAddrBit);--topOfStack_read(maxAddrBit downto minAddrBit);

  -- IO Accesses
  wb_adr_o(maxAddrBitIncIO downto 0) <= std_logic_vector(exr.tos(maxAddrBitIncIO downto 0));
  wb_dat_o <= std_logic_vector( stack_b_read );


  do_interrupt <= '1' when wb_inta_i='1' and exr.idim='0' and exr.inInterrupt='0' and decr.valid='1' else '0';
  --do_interrupt<='0';

  process(decr, exr, wb_inta_i, wb_clk_i, wb_rst_i, pcnext, stack_b_read, wb_ack_i, memARead, wb_dat_i, do_interrupt,exr)
    variable spOffset: unsigned(4 downto 0);
    variable w: zpuregs;
  begin

    memBWrite <= (others => '0');
    memBWriteEnable <= '0';
    memAWriteMask <= (others => '1');
    memBWriteMask <= (others => '1');
    stack_b_addr_is_offset<='0';
    stack_b_writeenable <= '0';

    decode_freeze <= '0';
    decode_jump <= '0';
    jump_address <= (others => DontCareValue);

    wb_cyc_o_i <= '0';
    wb_stb_o <= '0';
    wb_we_o <= DontCareValue;

    poppc_inst <= '0';
    begin_inst<='0';

    w := exr;

    stack_a_addr <= std_logic_vector( exr.sp );
    stack_b_addr <= std_logic_vector( exr.sp + 2 );
    stack_a_writeenable <= '0';
    stack_b_writeenable <= '0';

--    spnext <= exr.sp;
--    spnext_b <= exr.sp + 1;

    doInterrupt <= '0';

    spOffset(4):=not decr.opcode(4);
    spOffset(3 downto 0) := unsigned(decr.opcode(3 downto 0));

    if wb_inta_i='0' then
      w.inInterrupt := '0';
    end if;

    memBAddr <= pc_to_memaddr(pcnext);
    stack_b_write<=(others => DontCareValue);

    case exr.state is

      when State_Resync1 | State_Start  =>
        decode_freeze <= '1';
        
        w.state := State_Resync2;

      when State_Resync2 =>
        --spnext <= exr.sp;
        --spnext_b <= exr.sp + 1;
        --decode_freeze <= '1';
        w.tos := unsigned(stack_a_read);
        w.nos := unsigned(stack_b_read);
        w.state := State_Execute;

      when State_Pop =>
        w.sp := exr.sp + 1;
        --spnext_b <= sp + 2;

      when State_Execute =>

        if decr.valid='1' then

        w.idim := '0';

        -- Trace
        --if decr.decodedOpcode/=Decoded_Idle then
          begin_inst<='1';
        --end if;

        if do_interrupt='1' then

           w.inInterrupt := '1';
           jump_address <= to_unsigned(32, maxAddrBit+1);
           decode_jump <= '1';
           w.sp := exr.sp - 1;
           --spnext_b <= sp;
           report "Interrupt" severity note;

           w.tos := (others => '0');
           w.tos(maxAddrBit downto 0) := decr.pc;
           w.nos := exr.tos;

            -- Write back NOS
        else

        case decr.decodedOpcode is
          when Decoded_Im =>

            w.idim := '1';

            if exr.idim='0' then

                w.sp := exr.sp - 1;
                --spnext_b <= sp;

                for i in wordSize-1 downto 7 loop
                  w.tos(i) := decr.opcode(6);
                end loop;

                w.tos(6 downto 0) := unsigned(decr.opcode(6 downto 0));
                -- Write back NOS
                w.nos := exr.tos;

                stack_b_writeenable<='1';
                stack_b_write <=std_logic_vector(exr.nos);
                stack_b_addr <= std_logic_vector(exr.sp + 1);

              else
                w.tos(wordSize-1 downto 7) := exr.tos(wordSize-8 downto 0);
                w.tos(6 downto 0) := unsigned(decr.opcode(6 downto 0));

              end if;

          when Decoded_Nop =>

          when Decoded_PopPC =>

            decode_jump <= '1';
            jump_address <= exr.tos(maxAddrBit downto 0);
            w.sp := exr.sp + 1;
            poppc_inst <= '1';

            w.tos := exr.nos;


            -- Read back 

            w.state := State_WaitSPB;
            --w.nos := unsigned(stack_b_read);

          when Decoded_Emulate =>

            w.sp := exr.sp - 1;
            --spnext_b <= sp;

            decode_jump <= '1';
            jump_address <= (others => '0');
            jump_address(9 downto 5) <= unsigned(decr.opcode(4 downto 0));

            w.tos := (others => '0');
            w.tos(maxAddrBit downto 0) := decr.fetchpc;
            -- Write Back NOS
            w.nos := exr.tos;
            stack_b_writeenable<='1';
            stack_b_addr <= std_logic_vector(exr.sp + 1);
            stack_b_write<=std_logic_vector(exr.nos);


          when Decoded_PushSP =>

            w.sp := exr.sp - 1;
            --spnext_b <= sp;
            w.tos := (others => '0');
            w.tos(31) := '1'; -- Stack address
            w.tos(10 downto 2) := exr.sp;
            -- Write Back
            w.nos := exr.tos;
            stack_b_writeenable<='1';
            stack_b_addr <= std_logic_vector(exr.sp + 1);
            stack_b_write<=std_logic_vector(exr.nos);


          when Decoded_Add =>

            w.sp := exr.sp + 1;
            --spnext_b <= sp + 2;
            w.tos := exr.tos + exr.nos;
            -- Read back
            w.nos := unsigned(stack_b_read);

          when Decoded_And =>

            w.sp := exr.sp + 1;
            --spnext_b <= sp + 2;
            w.tos := exr.tos and exr.nos;
            -- Read back

          when Decoded_Eq =>
            w.sp := exr.sp + 1;
            --spnext_b <= sp + 2;

            w.tos := (others => '0');
            if exr.nos = exr.tos then
              w.tos(0) := '1';
            end if;
            -- Read back


          when Decoded_Ulessthan =>
            w.sp := exr.sp + 1;
            --spnext_b <= sp + 2;

            w.tos := (others => '0');
            if exr.tos < exr.nos then
              w.tos(0) := '1';
            end if;
            -- Read back

          when Decoded_Or =>
            w.sp := exr.sp + 1;
            --spnext_b <= sp + 2;
            w.tos := exr.tos or exr.nos;
            -- Read back

          when Decoded_Not =>
            w.tos := not exr.tos;

          when Decoded_Flip =>
            for i in 0 to wordSize-1 loop
              w.tos(i) := exr.tos(wordSize-1-i);
            end loop;

          when Decoded_LoadSP =>

            w.sp := exr.sp - 1;

            stack_a_addr <= std_logic_vector( exr.sp + spOffset );
            --stack_b_addr <= std_logic_vector( exr.sp + 1 );
            w.nos := exr.tos;
            stack_b_writeenable<='1';
            stack_b_write<=std_logic_vector(exr.nos);
            stack_b_addr <= std_logic_vector(exr.sp + 1);

            decode_freeze <= '1';

            w.state := State_WaitSP;

          when Decoded_Dup =>

            w.sp := exr.sp - 1;
            --spnext_b <= sp;
            --decode_freeze <= '1';
            --w.state := State_Dup;
            w.nos := exr.tos;
            -- Write back

          when Decoded_DupStackB =>

            w.sp := exr.sp - 1;
            --spnext_b <= sp;
            --decode_freeze <= '1';
            --w.state := State_Dup;
            w.tos := exr.nos;
            w.nos := exr.tos;
            -- Write back

          when Decoded_AddSP =>

            decode_freeze <= '1';
            --spnext_b <= sp + spOffset;

            w.state := State_AddSP;

          when Decoded_Shift =>
            w.tos := exr.tos + exr.tos;

          when Decoded_StoreSP =>

            w.sp := exr.sp + 1;
            --spnext_b <= sp + spOffset;

            --stack_b_writeenable <= '1';
            --stack_b_write <= std_logic_vector(tos);
            w.tos := exr.nos;

            stack_b_addr <= std_logic_vector(exr.sp + 2);
            --stack_a_addr <= std_logic_vector(exr.sp);

            decode_freeze <= '1';

            -- Read back ?
            w.state := State_WaitSPB;

          when Decoded_StoreSP8 =>

            w.sp := exr.sp + 1;
            w.tos := exr.nos;
            w.nos := exr.tos;
            --decode_freeze <= '1';

            -- Read back ?
            --w.state := State_WaitSPB;


          when Decoded_PopDown =>
            w.sp := exr.sp + 1;
            --spnext_b <= sp + 2;
            decode_freeze <= '1';
            w.state := State_WaitSP;

          when Decoded_Pop =>
            w.sp := exr.sp + 1;
            --spnext_b <= sp + 2;
            decode_freeze <= '1';
            w.tos := exr.nos;
            -- Read back
            w.state := State_WaitSP;

          when Decoded_Store =>

            --stack_b_write <= std_logic_vector(nos);

            if exr.tos(31)='1' then
              --spnext_b <= tos(spMaxBit downto 2);
              --stack_b_writeenable <= '1';
            end if;

            if exr.tos(maxAddrBitIncIO)='1' then
              decode_freeze<='1';
              wb_we_o    <='1';
              wb_cyc_o_i <='1';
              wb_stb_o   <='1';
              w.state := State_Store;
            else
              w.sp := exr.sp + 1;
              -- Read back
              w.tos := exr.nos;

            end if;

          when Decoded_Load | Decoded_Loadb =>

            if exr.tos(maxAddrBitIncIO)='1' then
              wb_we_o <= '0';
              wb_cyc_o_i<='1';
              wb_stb_o<='1';
            end if;

            w.state := State_Load;
            --spnext_b <= tos(spMaxBit downto 2);

            decode_freeze<='1';

          when Decoded_PopSP =>
            w.sp := exr.tos(10 downto 2);
            stack_a_addr <= std_logic_vector( exr.tos(10 downto 2) );
            stack_b_addr <= std_logic_vector( exr.tos(10 downto 2) + 1);

            decode_freeze <= '1';
            w.state := State_Resync2;

          when Decoded_Break =>
            w.break := '1';

          when Decoded_Neqbranch =>

            w.sp  := exr.sp + 1;
            --spnext_b <= sp + 2;

            --decode_freeze <= '1';
            if unsigned(exr.nos)/=0 then
              decode_jump <= '1';
              jump_address <= decr.pc + exr.tos(maxAddrBit downto 0);
            else
              decode_freeze <= '1'; -- Going to Pop
            end if;

          when Decoded_Idle =>
            -- TODO: Restore idim!!!
            w.idim := exr.idim;
          when others =>
            w.break := '1';

        end case;
        end if; -- interrupt
        end if; -- valid

      when State_WaitSP =>

        w.tos := unsigned(stack_a_read);
        --w.nos := unsigned(stack_b_read);
        --decode_freeze <='1';
        w.state := State_Execute;


      when State_WaitSPB =>

        w.nos := unsigned(stack_b_read);
        --decode_freeze <= '1';
        w.state := State_Execute;
  
      when State_Store =>
        wb_cyc_o_i<='1';
        wb_stb_o<='1';
        wb_we_o <='1';

        if wb_ack_i='1' then
          w.sp := exr.sp + 1;
          w.tos := unsigned(wb_dat_i);
          w.state := State_Execute;
          --spnext_b <= sp + 2;
        end if;

        decode_freeze <= '1';

      when State_LoadSP =>

      when State_AddSP =>
        
      when State_Load =>
        if exr.tos(maxAddrBitIncIO)='1' then
          wb_we_o <='0';
          wb_cyc_o_i<='1';
          wb_stb_o<='1';
          if wb_ack_i='0' then
            decode_freeze<='1'; -- Don't push ops while busy
          end if;
        else

          w.state := State_Execute;
        end if;

      when others =>
         null;
    end case;

    if rising_edge(wb_clk_i) then
      if wb_rst_i='1' then
        exr.sp <= unsigned(spStart(10 downto 2));
        exr.state <= State_Start;
        exr.idim <= '0';
        exr.inInterrupt <= '0';
        exr.break <= '0';
      else
        exr <= w;
      end if;
    end if;

  end process;

end behave;

