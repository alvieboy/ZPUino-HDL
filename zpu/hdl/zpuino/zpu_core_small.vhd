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
    break:          out std_logic
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
signal memBAddr:            unsigned(maxAddrBit downto 0);
signal memBWrite:           unsigned(7 downto 0);
signal memBRead:            unsigned(7 downto 0);

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
State_Start2,
State_Fetch,
State_WriteIODone,
State_WaitIO,
State_Execute,
State_StoreToStack,
State_Add,
State_Or,
State_And,
State_Store,
State_ReadIO,
State_WriteIO,
State_Load,
State_FetchNext,
State_AddSP,
State_ReadIODone,
State_Resync1,
State_Resync2,
State_Interrupt,
State_Neqbranch,
State_Eq,
State_Storeb,
State_Storeh,
State_LoadSP,
State_Loadb,
State_Ashiftleft,
State_WaitSP,
State_Pop
);

type DecodedOpcodeType is
(
Decoded_Nop,
Decoded_Idle,
Decoded_Im,
Decoded_LoadSP,
Decoded_Dup,
Decoded_StoreSP,
Decoded_Pop,
Decoded_PopDown,
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
Decoded_Interrupt,
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
signal opcode: std_logic_vector(OpCode_Size-1 downto 0);

signal decodedOpcode : DecodedOpcodeType;
signal i_decodedOpcode : DecodedOpcodeType;
signal sampledDecodedOpcode : DecodedOpcodeType;

signal pc:         unsigned(maxAddrBit downto 0);
signal pce:        unsigned(maxAddrBit downto 0);
signal pcnext:     unsigned(maxAddrBit downto 0);
signal state:      State_Type;

type zpuregs is record
  idim:       std_logic;
  break:      std_logic;
  inInterrupt:std_logic;
  shiftAmount:unsigned(4 downto 0);
  shiftValue: unsigned(wordSize-1 downto 0);
  isStore:    std_logic;
  multInA:    unsigned(31 downto 0);
  multInB:    unsigned(31 downto 0);
  aluop:      std_logic;
  aluresult:  unsigned(wordSize-1 downto 0);
end record;

signal r: zpuregs;
signal w: zpuregs;

constant spMaxBit: integer := 10;

signal sp:         unsigned(spMaxBit downto 2);
signal spnext:     unsigned(spMaxBit downto 2);
signal spnext_b:   unsigned(spMaxBit downto 2);

constant minimal_implementation: boolean := true;


subtype AddrBitBRAM_range is natural range maxAddrBitBRAM downto minAddrBit;
signal memAAddr_stdlogic  : std_logic_vector(AddrBitBRAM_range);
signal memAWrite_stdlogic : std_logic_vector(memAWrite'range);
signal memARead_stdlogic  : std_logic_vector(memARead'range);
signal memBAddr_stdlogic  : std_logic_vector(maxAddrBitBRAM downto 0);
signal memBWrite_stdlogic : std_logic_vector(memBWrite'range);
signal memBRead_stdlogic  : std_logic_vector(memBRead'range);
signal memErr: std_logic;

constant minimal_implementation: boolean := false;

subtype index is integer range 0 to 3;

signal tOpcode_sel : index;
signal inInterrupt : std_logic;

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
  r := (others => DontCareValue);
  r(maxAddrBit downto 0) := pc(maxAddrBit downto 0);
  return r;
end pc_to_memaddr;

-- Decoder control

signal decode_freeze: std_logic;
signal decode_freeze_q: std_logic;

signal decode_jump: std_logic;
signal decode_valid_q: std_logic;
--signal decode_membusy: std_logic;

signal decode_valid_dly_q: std_logic;
signal jump_address: unsigned(maxAddrBit downto 0);

signal topOfStack_write: unsigned(wordSize-1 downto 0);
signal topOfStack_read: unsigned(wordSize-1 downto 0);

signal stack_a_addr,stack_b_addr: std_logic_vector(8 downto 0);
signal stack_a_writeenable, stack_b_writeenable: std_logic;
signal stack_a_write,stack_b_write: std_logic_vector(31 downto 0);
signal stack_a_read,stack_b_read: std_logic_vector(31 downto 0);
signal dipa,dipb: std_logic_vector(3 downto 0) := (others => '0');

signal stack_b_addr_is_offset: std_logic;

begin

  stack_a_write <= std_logic_vector(topOfStack_write);
  topOfStack_read <= unsigned(stack_a_read);

  -- STACK

  stack: RAMB16_S36_S36
  generic map (
    WRITE_MODE_A => "WRITE_FIRST",
    WRITE_MODE_B => "WRITE_FIRST"
    )
  port map (
    DOA  => stack_a_read,
    DOB  => stack_b_read,
    DOPA => open,
    DOPB => open,

    ADDRA => stack_a_addr,
    ADDRB => stack_b_addr,
    CLKA  => clk,
    CLKB  => clk,
    DIA   => stack_a_write,
    DIB   => stack_b_write,
    DIPA  => dipa,
    DIPB  => dipb,
    ENA   => '1',
    ENB   => '1',
    SSRA  => '0',
    SSRB  => '0',
    WEA   => stack_a_writeenable,
    WEB   => stack_b_writeenable
    );


  -- generate a trace file.
  -- 
  -- This is only used in simulation to see what instructions are
  -- executed. 
  --
  -- a quick & dirty regression test is then to commit trace files
  -- to CVS and compare the latest trace file against the last known
  -- good trace file

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
  memBAddr_stdlogic  <= std_logic_vector(memBAddr);
  memBWrite_stdlogic <= std_logic_vector(memBWrite);
  
  memory: dualport_ram
    port map (
      clk => wb_clk_i,
      memAWriteEnable => memAWriteEnable,
      memAWriteMask => memAWriteMask,
      memAAddr => memAAddr_stdlogic,
      memAWrite => memAWrite_stdlogic,
      memARead => memARead_stdlogic,
      memBWriteEnable => memBWriteEnable,
      --memBWriteMask => memBWriteMask,
      memBAddr => memBAddr_stdlogic,
      memBWrite => memBWrite_stdlogic,
      memBRead => memBRead_stdlogic,
      memErr => open
    );

  memARead <= unsigned(memARead_stdlogic);
  memBRead <= unsigned(memBRead_stdlogic);
  wb_we_o <= io_we;

  tOpcode_sel <= to_integer(pc(minAddrBit-1 downto 0));

  -- move out calculation of the opcode to a seperate process
  -- to make things a bit easier to read
  decodeControl:
  process(memBRead, tOpcode_sel)
    variable tOpcode : std_logic_vector(OpCode_Size-1 downto 0);
    variable localspOffset: unsigned(4 downto 0);
  begin

        --case (tOpcode_sel) is

        --    when 0 => tOpcode := std_logic_vector(memBRead(31 downto 24));

        --    when 1 => tOpcode := std_logic_vector(memBRead(23 downto 16));

        --    when 2 => tOpcode := std_logic_vector(memBRead(15 downto 8));

            --when 3 =>
            tOpcode := std_logic_vector(memBRead(7 downto 0));

        --    when others => tOpcode := std_logic_vector(memBRead(7 downto 0));
       -- end case;

    sampledOpcode <= tOpcode;
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

      elsif (tOpcode(5 downto 0)=OpCode_Storeb) then
        sampledDecodedOpcode<=Decoded_Storeb;

      elsif (tOpcode(5 downto 0)=OpCode_Storeh) then
        sampledDecodedOpcode<=Decoded_Storeh;

      elsif (tOpcode(5 downto 0)=OpCode_Ulessthan) then
        sampledDecodedOpcode<=Decoded_Ulessthan;

      elsif (tOpcode(5 downto 0)=OpCode_Ashiftleft) then
        sampledDecodedOpcode<=Decoded_Ashiftleft;

      elsif (tOpcode(5 downto 0)=OpCode_Ashiftright) then
        sampledDecodedOpcode<=Decoded_Ashiftright;

      elsif (tOpcode(5 downto 0)=OpCode_Loadb) then
        sampledDecodedOpcode<=Decoded_Loadb;

      elsif (tOpcode(5 downto 0)=OpCode_Mult) then
        sampledDecodedOpcode<=Decoded_Mult;

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
  process(wb_clk_i)
    variable multR: unsigned(wordSize*2-1 downto 0);
  begin
    if rising_edge(wb_clk_i) then
      multR := r.multInA * r.multInB;
      mult3 <= multR(wordSize-1 downto 0);
      mult2 <= mult3;
      mult1 <= mult2;
      mult0 <= mult1;
    end if;
  end process;

  -- Decode unit

  -- Input: wait
  -- Input: jump

  process(pc,jump_address,decode_jump)
  begin
    if decode_jump='1' then
      pcnext <= jump_address;    else
      pcnext <= pc + 1;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        pc <= (others => '1');
        decode_valid_q <= '0';
      else

        decode_freeze_q <= decode_freeze;

        decode_valid_q<='1';

        if decode_jump='1' then
          decode_valid_q <= '0';
        end if;
  
        if decode_freeze='0' then
          pc <= pcnext;
        end if;

        if decode_freeze_q='0' then
            pce <= pc;
            opcode <= sampledOpcode;
            i_decodedOpcode <= sampledDecodedOpcode;
        end if;

        decode_valid_dly_q<=decode_valid_q;

      end if;
    end if;
  end process;


  process(i_decodedOpcode, decode_valid_q )
  begin
    if decode_valid_q='1' then
      decodedOpcode <= i_decodedOpcode;
    else
      decodedOpcode <= Decoded_Idle;
    end if;
  end process;


  stack_b_addr <= std_logic_vector(spnext_b);

  process(spnext,state,sp,opcode,stack_b_addr_is_offset)
    variable spOffset: unsigned(4 downto 0);
  begin
    if state=State_Resync1 then
      stack_a_addr(8 downto 0) <= std_logic_vector(sp(10 downto 2));
    else
      stack_a_addr(8 downto 0) <= std_logic_vector(spnext(10 downto 2));
    end if;
  end process;

  memAAddr <= topOfStack_read(maxAddrBit downto minAddrBit);

  -- IO Accesses
  io_addr(maxAddrBitIncIO downto 0) <= std_logic_vector(topOfStack_read(maxAddrBitIncIO downto 0));
  io_write <= stack_b_read;

  process(topOfStack_read, r, opcode, interrupt, pcnext, decodedOpcode, pce, stack_b_read, pc, io_busy, memARead, io_read, sp, state)
    variable spOffset: unsigned(4 downto 0);
  begin

    --memAAddr <= (others => DontCareValue);
    --memBAddr <= (others => DontCareValue);
    --memAWrite <= (others => DontCareValue);
    memBWrite <= (others => DontCareValue);
    memBWriteEnable <= '0';
    memAWriteMask <= (others => '1');
    memBWriteMask <= (others => '1');

    stack_b_addr_is_offset<='0';

    stack_b_writeenable <= '0';

    decode_freeze <= '0';
    decode_jump <= '0';

    jump_address <= (others => DontCareValue);

    io_wr <= '0';
    io_rd <= '0';
    poppc_inst <= '0';
    begin_inst<='0';

    w <= r;
    spnext <= sp;
    spnext_b <= sp + 1;

    doInterrupt <= '0';

    spOffset(4):=not opcode(4);
    spOffset(3 downto 0) := unsigned(opcode(3 downto 0));

    --w.pcdly <= r.pc; -- Save PC for Neqbranch operations

    if interrupt='0' then
      w.inInterrupt<='0';
    end if;

    --stack_b_write <= std_logic_vector(topOfStack_read);
    stack_b_write<=(others => DontCareValue);

    memBAddr <= pc_to_memaddr(pcnext);
          --memAAddr <= topOfStack_read(maxAddrBit downto minAddrBit);
    case state is

      when State_Start2 =>
        decode_freeze <= '1';

      when State_Resync2 =>
        spnext <= sp;
        spnext_b <= sp + 1;

      when State_Pop =>
        --decode_freeze <= '1';
        spnext <= sp + 1;
        spnext_b <= sp + 2;

      when State_Execute =>

        w.idim <= '0';
        --spnext <= sp;
        --spnext_b <= sp + 1;

        -- Trace
        if decodedOpcode/=Decoded_Idle then
          begin_inst<='1';
        end if;

        trace_pc <= (others => '0');
        trace_pc(maxAddrBit downto 0) <= std_logic_vector(pce);
        trace_opcode <= opcode;
        trace_sp <= (others => '0');
        trace_sp(10 downto 2) <= std_logic_vector(sp);
        trace_topOfStack <= std_logic_vector( topOfStack_read );
        trace_topOfStackB <= std_logic_vector( stack_b_read );


        case decodedOpcode is
          when Decoded_Im =>

            w.idim <= '1';

            --memAAddr <= r.sp + 1;

            if r.idim='0' then

                spnext <= sp - 1;
                spnext_b <= sp;

            end if;


          when Decoded_Nop =>

            --memAAddr <= r.sp;
            --memAWriteMask <= (others => '1');
            --memAWrite <= r.topOfStack;


          when Decoded_PopPC =>
            decode_jump <= '1';
            jump_address <= topOfStack_read(maxAddrBit downto 0);
            --w.pc <= r.topOfStack(maxAddrBit downto 0);
            --w.topOfStack <= memARead;
            spnext <= sp + 1;
            spnext_b <= sp + 2;

            poppc_inst <= '1';

            --memAAddr <= r.sp;
            --memAWrite <= r.topOfStack;

          when Decoded_Interrupt =>

            --w.pc <= to_unsigned(32, maxAddrBit+1);
            jump_address <= to_unsigned(32, maxAddrBit+1);
            decode_jump <= '1';


            spnext <= sp - 1;
            spnext_b <= sp;

            report "FIXME" severity failure;

            --memBAddr <= (others => '0');
            --memBAddr(minAddrBit+3 downto minAddrBit) <= "1000";

            --memAAddr <= r.sp;
            --memAWrite <= r.topOfStack;


          when Decoded_Emulate =>

            spnext <= sp - 1;
            spnext_b <= sp;

            --memAAddr <= r.sp;
            --memAWrite <= r.topOfStack;

            --w.pc <= (others => '0');
            --w.pc(9 downto 5) <= unsigned(opcode(4 downto 0));

            decode_jump <= '1';
            jump_address <= (others => '0');
            jump_address(9 downto 5) <= unsigned(opcode(4 downto 0));

            --memBAddr <= (others => '0');
            --memBAddr(9 downto 5) <= unsigned(opcode(4 downto 0));


          when Decoded_PushSP =>

            spnext <= sp - 1;
            spnext_b <= sp;


          when Decoded_Add =>

            spnext <= sp + 1;
            spnext_b <= sp + 2;

            --decode_freeze<='1';

          when Decoded_And =>

            spnext <= sp + 1;
            spnext_b <= sp + 2;
            --decode_freeze<='1';

          when Decoded_Eq =>
            spnext <= sp + 1;
            spnext_b <= sp + 2;

            --decode_freeze<='1';

          when Decoded_Ulessthan =>
            spnext <= sp + 1;
            spnext_b <= sp + 2;


          when Decoded_Or =>

            spnext <= sp + 1;
            spnext_b <= sp + 2;

            --decode_freeze<='1';

          when Decoded_Not =>


          when Decoded_Flip =>


          when Decoded_LoadSP =>

            spnext <= sp - 1;
            spnext_b <= sp + spOffset;

            decode_freeze <= '1';

          when Decoded_Dup =>

            spnext <= sp - 1;
            spnext_b <= sp;
            decode_freeze <= '1';

          when Decoded_AddSP =>

            decode_freeze <= '1';
            spnext_b <= sp + spOffset;

          when Decoded_Shift =>

          when Decoded_StoreSP =>

            spnext <= sp + 1;
            spnext_b <= sp + spOffset;

            stack_b_writeenable <= '1';
            stack_b_write <= std_logic_vector(topOfStack_read);

            decode_freeze <= '1';


          when Decoded_PopDown =>
            spnext <= sp + 1;
            spnext_b <= sp + 2;
            decode_freeze <= '1';


          when Decoded_Pop =>
            spnext <= sp + 1;
            spnext_b <= sp + 2;
            decode_freeze <= '1';

          when Decoded_Store =>
            -- TODO: Ensure we can wait here for busy.
            if io_busy='0' then
              spnext <= sp + 1;      -- REMOVE THIS PLEASE
              spnext_b <= sp + 2;
            end if;

            decode_freeze<='1';

            -- If stack access, change SP immediatly
            if topOfStack_read(31)='1' then
              spnext_b <= topOfStack_read(spMaxBit downto 2);
              stack_b_writeenable <= '1';
            end if;

            stack_b_write <= std_logic_vector(stack_b_read);

            if topOfStack_read(maxAddrBitIncIO)='1' then
              io_wr <='1';
            end if;

          when Decoded_Load =>

            if topOfStack_read(maxAddrBitIncIO)='1' then
              io_rd <= '1';
            end if;

            -- If stack access, change SP immediatly
            if topOfStack_read(31)='1' then
              spnext_b <= topOfStack_read(spMaxBit downto 2);
            end if;

            decode_freeze<='1';


          when Decoded_PopSP =>
            spnext <= topOfStack_read(10 downto 2);
            spnext_b <= (others => DontCareValue);

            decode_freeze <= '1';


          when Decoded_Break =>
            w.break <= '1';

          when Decoded_Neqbranch =>

            spnext <= sp + 1;
            spnext_b <= sp + 2;

            decode_freeze <= '1';
            if unsigned(stack_b_read)/=0 then
              --w.pc <= r.pcdly + r.topOfStack(maxAddrBit downto 0);
              decode_jump <= '1';
              jump_address <= pce + topOfStack_read(maxAddrBit downto 0);
--            else
--              w.pc <= r.pc + 1;
            end if;

          when Decoded_Idle =>
            -- Restore idim!!!

          when others =>
            w.break <= '1';

        end case;

      when State_WaitSP =>

  
      when State_WaitIO =>
        if io_busy='0' then
          spnext <= sp + 1;
          spnext_b <= sp + 2;
        end if;

        decode_freeze <= '1';

      when State_LoadSP =>

      when State_AddSP =>
        
      when State_Load =>

      when others =>
         null;
    end case;

  end process;


  process(state, decodedOpcode, topOfStack_read,stack_b_read)
  begin
    memAWriteEnable <= '0';
    memAWrite <= (others => DontCareValue);

    case state is
      when State_Execute =>
        case decodedOpcode is
          when Decoded_Store =>
            if topOfStack_read(maxAddrBitIncIO)='0' then
              memAWriteEnable <= '1';
              memAWrite <= unsigned(stack_b_read);
            end if;
          when others =>
        end case;
      when others =>
    end case;
  end process;



  -- Top of stack generator

  process(topOfStack_read, r, opcode, interrupt, pcnext, decodedOpcode, pce, stack_b_read, pc, io_busy, memARead, io_read, sp, state)
    variable spOffset: unsigned(4 downto 0);
  begin

    topOfStack_write <= topOfStack_read;
    stack_a_writeenable <= '1';

    case state is

      when State_Resync2 =>
        topOfStack_write <= (others => DontCareValue);
        stack_a_writeenable<='0';
  
      when State_Execute =>
        case decodedOpcode is
          when Decoded_Im =>
            if r.idim='0' then
                for i in wordSize-1 downto 7 loop
                  topOfStack_write(i) <= opcode(6);
                end loop;

                topOfStack_write(6 downto 0) <= unsigned(opcode(6 downto 0));
              else
                topOfStack_write(wordSize-1 downto 7) <= topOfStack_read(wordSize-8 downto 0);
                topOfStack_write(6 downto 0) <= unsigned(opcode(6 downto 0));
              end if;

          when Decoded_Nop =>

          when Decoded_PopPC =>

            stack_a_writeenable <= '0';
            topOfStack_write <= (others => DontCareValue);

          when Decoded_Interrupt =>

            topOfStack_write <= (others => '0');
            topOfStack_write(maxAddrBit downto 0) <= pc;

          when Decoded_Emulate =>

            topOfStack_write <= (others => '0');
            topOfStack_write(maxAddrBit downto 0) <= pc;

          when Decoded_PushSP =>

            topOfStack_write <= (others => '0');
            topOfStack_write(31) <= '1'; -- Stack address
            topOfStack_write(10 downto 2) <= sp;

          when Decoded_Add =>

            topOfStack_write <= topOfStack_read + unsigned(stack_b_read);

          when Decoded_And =>

            topOfStack_write <= topOfStack_read and unsigned(stack_b_read);

          when Decoded_Eq =>

            topOfStack_write <= (others => '0');
            if unsigned(stack_b_read) = topOfStack_read then
              topOfStack_write(0) <= '1';
            end if;

          when Decoded_Ulessthan =>

            topOfStack_write <= (others => '0');
            if topOfStack_read < unsigned(stack_b_read) then
              topOfStack_write(0) <= '1';
            end if;


          when Decoded_Or =>

            topOfStack_write <= topOfStack_read or unsigned(stack_b_read);

          when Decoded_Not =>

            topOfStack_write <= not topOfStack_read;

          when Decoded_Flip =>

            for i in 0 to wordSize-1 loop
              topOfStack_write(i) <= topOfStack_read(wordSize-1-i);
            end loop;

          when Decoded_LoadSP =>

            --stack_a_writeenable<='0';
            --topOfStack_write<=(others => DontCareValue);

          when Decoded_Dup =>

          when Decoded_AddSP =>

            stack_a_writeenable<='0';
            topOfStack_write<=(others => DontCareValue);

          when Decoded_Shift =>

            topOfStack_write <= topOfStack_read + topOfStack_read;

          when Decoded_StoreSP =>

            stack_a_writeenable<='0';
            topOfStack_write <= (others => DontCareValue);

          when Decoded_PopDown =>

          when Decoded_Pop =>

          when Decoded_Store =>

            stack_a_writeenable <= '0';
            topOfStack_write <= (others => DontCareValue);

          when Decoded_Load =>

          when Decoded_PopSP =>

            stack_a_writeenable <= '0';
            topOfStack_write <= (others => DontCareValue);

          when Decoded_Break =>
            stack_a_writeenable <= DontCareValue;
            topOfStack_write <= (others => DontCareValue);

          when Decoded_Neqbranch =>

          when Decoded_Idle =>

          when others =>
            null;

        end case;

      when State_WaitSP =>

        stack_a_writeenable<='0';
        topOfStack_write <= (others => DontCareValue);
  
      when State_Pop =>
        stack_a_writeenable<='0';
        topOfStack_write <= (others => DontCareValue);

      when State_WaitIO =>


        stack_a_writeenable <= '0';
        topOfStack_write <= (others => DontCareValue);

      when State_LoadSP =>

        topOfStack_write <= unsigned(stack_b_read);

      when State_AddSP =>

        topOfStack_write <= topOfStack_read + unsigned(stack_b_read);
        
      when State_Load =>

        if topOfStack_read(31) = '1' then
          -- It's a stack access
          topOfStack_write <= unsigned(stack_b_read);

        else
        if topOfStack_read(maxAddrBitIncIO)='1' then
          --if io_busy='0' then
          -- NOTE: keep writing even if IO is busy
            topOfStack_write <= unsigned(io_read);
          --end if;
        else
          topOfStack_write <= memARead;
        end if;
        end if;
      when others =>

    end case;

  end process;

  -- State machine

  process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        state <= State_Start;
      else
      case state is
        when State_Start =>
          --state <= State_Start2;
          state <= State_Resync1;

        when State_Start2 =>
          state <= State_Resync1;

        when State_Resync1 =>
          state <= State_Execute;

        when State_Resync2 =>
          state <= State_Execute;
  
        when State_Pop =>
          state <= State_Execute;
  
        when State_Execute =>
          case decodedOpcode is
            when Decoded_LoadSP =>
              state <= State_LoadSP;

            when Decoded_Dup =>
              state <= State_WaitSP;

            when Decoded_AddSP =>
              state <= State_AddSP;

            when Decoded_StoreSP =>
              state <= State_WaitSP;

            when Decoded_PopDown =>
              state <= State_WaitSP;

            when Decoded_Pop =>
              state <= State_WaitSP;

            when Decoded_Store =>
              if io_busy='0' then
                state <= State_Pop;
              else
                state <= State_WaitIO;
              end if;

            when Decoded_Load =>
              state <= State_Load;

            when Decoded_PopSP =>
              state <= State_Resync2;

            when Decoded_Neqbranch =>
              state <= State_Pop;

          when others =>
        end case;

        when State_WaitSP =>
          state <= State_Execute;
  
        when State_WaitIO =>
          if io_busy='0' then
            state <= State_Pop;
          end if;

        when State_LoadSP =>
          state <= State_Execute;

        when State_AddSP =>
          state <= State_Execute;
        
        when State_Load =>
          if topOfStack_read(31)='1' then
            state <= State_Execute;
          else

          if topOfStack_read(maxAddrBitIncIO)='1' then
            if io_busy='0' then
              state <= State_Execute;
            end if;
          else
            state <= State_Execute;
          end if;
          end if;
        when others =>
      end case;
    end if;
    end if;
  end process;






  process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        sp <= unsigned(spStart(10 downto 2));
--        r.state <= State_Start;
        r.idim <= '0';
        --topOfStack <= (others => '0');
        r.break <= '0';
        r.inInterrupt<='1';
      else
        r <= w;
        sp <= spnext;
        if w.break='1' then
          report "BREAK" severity failure;
        end if;
      end if;
    end if;
  end process;

end behave;

