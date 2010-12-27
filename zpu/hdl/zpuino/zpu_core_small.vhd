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


entity zpu_core_small is
  port (
    clk:            in std_logic;
    rst:            in std_logic; -- Synchronous reset
    io_busy:        in std_logic;
    io_read:        in std_logic_vector(wordSize-1 downto 0);
    io_write:       out std_logic_vector(wordSize-1 downto 0);
    io_addr:        out std_logic_vector(maxAddrBitIncIO downto 0);
    io_wr:          out std_logic;
    io_rd:          out std_logic;
    interrupt:      in std_logic;
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
signal memBAddr:            unsigned(maxAddrBit downto minAddrBit);
signal memBWrite:           unsigned(wordSize-1 downto 0);
signal memBRead:            unsigned(wordSize-1 downto 0);

signal busy:                std_logic;
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
State_Decode,
State_Resync1,
State_Resync2,
State_Interrupt,
State_Exception,
State_Neqbranch,
State_Eq,
State_Storeb,
State_LoadSP

);

type DecodedOpcodeType is
(
Decoded_Nop,
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
Decoded_Storeb
);



signal sampledOpcode: std_logic_vector(OpCode_Size-1 downto 0);
signal opcode: std_logic_vector(OpCode_Size-1 downto 0);

signal decodedOpcode : DecodedOpcodeType;
signal sampledDecodedOpcode : DecodedOpcodeType;

type zpuregs is record
  pc:         unsigned(maxAddrBit downto 0);
  sp:         unsigned(maxAddrBit downto minAddrBit);
  topOfStack: unsigned(wordSize-1 downto 0);
  idim:       std_logic;
  state:      State_Type;
  break:      std_logic;
  inInterrupt:std_logic;
end record;

signal r: zpuregs;
signal w: zpuregs;


subtype AddrBitBRAM_range is natural range maxAddrBitBRAM downto minAddrBit;
signal memAAddr_stdlogic  : std_logic_vector(AddrBitBRAM_range);
signal memAWrite_stdlogic : std_logic_vector(memAWrite'range);
signal memARead_stdlogic  : std_logic_vector(memARead'range);
signal memBAddr_stdlogic  : std_logic_vector(AddrBitBRAM_range);
signal memBWrite_stdlogic : std_logic_vector(memBWrite'range);
signal memBRead_stdlogic  : std_logic_vector(memBRead'range);
signal memErr: std_logic;

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
  variable r: unsigned(maxAddrBit downto minAddrBit);
begin
  r := (others => DontCareValue);
  r(maxAddrBit downto minAddrBit) := pc(maxAddrBit downto minAddrBit);
  return r;
end pc_to_memaddr;

begin

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
          clk         => clk,
          begin_inst  => begin_inst,
          pc          => trace_pc,
          opcode      => trace_opcode,
          sp          => trace_sp,
          memA        => trace_topOfStack,
          memB        => trace_topOfStackB,
          busy        => busy,
          intsp       => (others => 'U')
        );
  end generate;


  memAAddr_stdlogic  <= std_logic_vector(memAAddr(AddrBitBRAM_range));
  memAWrite_stdlogic <= std_logic_vector(memAWrite);
  memBAddr_stdlogic  <= std_logic_vector(memBAddr(AddrBitBRAM_range));
  memBWrite_stdlogic <= std_logic_vector(memBWrite);
  
  memory: dualport_ram
    port map (
      clk => clk,
      memAWriteEnable => memAWriteEnable,
      memAWriteMask => memAWriteMask,
      memAAddr => memAAddr_stdlogic,
      memAWrite => memAWrite_stdlogic,
      memARead => memARead_stdlogic,
      memBWriteEnable => memBWriteEnable,
      memBWriteMask => memBWriteMask,
      memBAddr => memBAddr_stdlogic,
      memBWrite => memBWrite_stdlogic,
      memBRead => memBRead_stdlogic,
      memErr => memErr
    );

  memARead <= unsigned(memARead_stdlogic);
  memBRead <= unsigned(memBRead_stdlogic);

  tOpcode_sel <= to_integer(r.pc(minAddrBit-1 downto 0));

  -- move out calculation of the opcode to a seperate process
  -- to make things a bit easier to read
  decodeControl:
  process(memBRead, r.pc, tOpcode_sel)
    variable tOpcode : std_logic_vector(OpCode_Size-1 downto 0);
    variable localspOffset: unsigned(4 downto 0);
  begin

        case (tOpcode_sel) is

            when 0 => tOpcode := std_logic_vector(memBRead(31 downto 24));

            when 1 => tOpcode := std_logic_vector(memBRead(23 downto 16));

            when 2 => tOpcode := std_logic_vector(memBRead(15 downto 8));

            when 3 => tOpcode := std_logic_vector(memBRead(7 downto 0));

            when others => tOpcode := std_logic_vector(memBRead(7 downto 0));
        end case;

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
      if (tOpcode(5 downto 0)=OpCode_Neqbranch) then
        sampledDecodedOpcode<=Decoded_Neqbranch;
      elsif (tOpcode(5 downto 0)=OpCode_Eq) then
        sampledDecodedOpcode<=Decoded_Eq;
      elsif (tOpcode(5 downto 0)=OpCode_Storeb) then
        sampledDecodedOpcode<=Decoded_Storeb;
      else
        sampledDecodedOpcode<=Decoded_Emulate;
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


  process(decodedOpcode,r,memARead,memBRead,opcode,sampledDecodedOpcode,io_read)
    variable spOffset: unsigned(4 downto 0);
  begin

    memAAddr <= (others => DontCareValue);
    memBAddr <= (others => DontCareValue);
    memAWrite <= (others => DontCareValue);
    memBWrite <= (others => DontCareValue);
    memAWriteEnable <= '0';
    memBWriteEnable <= '0';
    memAWriteMask <= (others => '1');
    memBWriteMask <= (others => '1');

    io_wr <= '0';
    io_rd <= '0';
    io_addr <= (others => DontCareValue);
    io_write <= (others => DontCareValue);
    poppc_inst <= '0';
    begin_inst<='0';

    w <= r;
    doInterrupt <= '0';

    spOffset(4):=not opcode(4);
    spOffset(3 downto 0) := unsigned(opcode(3 downto 0));

    if interrupt='0' then
          w.inInterrupt<='0';
    end if;

    case r.state is

      when State_Resync1 =>
        memAAddr <= r.sp;
        memBAddr <= pc_to_memaddr(r.pc);
        w.state <= State_Resync2;

      when State_Resync2 =>
        memAAddr <= r.sp + 1;
        w.pc <= r.pc + 1;
        w.topOfStack <= memARead;
        w.state <= State_Execute;
  
      when State_Decode =>

        memAAddr <= r.sp + 1;
        
        if interrupt='0' then
          if sampledDecodedOpcode/=Decoded_Neqbranch then
            w.pc <= r.pc + 1;
          end if;
        else
          if r.state=State_Decode and r.idim='0' and r.inInterrupt='0' then
            if interrupt='1' then
              doInterrupt<='1';
              w.inInterrupt<='1';
            else
              if sampledDecodedOpcode/=Decoded_Neqbranch then
                w.pc <= r.pc + 1;
              end if;
            end if;
          else
            if sampledDecodedOpcode/=Decoded_Neqbranch then
              w.pc <= r.pc + 1;
            end if;
          end if;
        end if;

        w.state <= State_Execute;

      when State_Execute =>

        w.idim <= '0';
        memBAddr <= pc_to_memaddr(r.pc);

        -- Trace
        begin_inst<='1';

        trace_pc <= (others => '0');
        trace_pc(maxAddrBit downto 0) <= std_logic_vector(r.pc - 1);
        trace_opcode <= opcode;
        trace_sp <= (others => '0');
        trace_sp(maxAddrBit downto minAddrBit) <= std_logic_vector(r.sp);
        trace_topOfStack <= std_logic_vector(r.topOfStack);
        trace_topOfStackB <= std_logic_vector(memARead);


        case decodedOpcode is
          when Decoded_Im =>

            w.idim <= '1';

            if r.idim='0' then
                w.sp <= r.sp - 1;
                for i in wordSize-1 downto 7 loop
                  w.topOfStack(i) <= opcode(6);
                end loop;

                w.topOfStack(6 downto 0) <= unsigned(opcode(6 downto 0));
                -- Write back
                memAAddr <= r.sp;
                memAWriteEnable <= '1';
                memAWrite <= r.topOfStack;

              else
                w.topOfStack(wordSize-1 downto 7) <= r.topOfStack(wordSize-8 downto 0);
                w.topOfStack(6 downto 0) <= unsigned(opcode(6 downto 0));
              end if;

              w.state <= State_Decode;

          when Decoded_Nop =>

            memAAddr <= r.sp;
            memAWriteEnable <= '1';
            memAWriteMask <= (others => '1');
            memAWrite <= r.topOfStack;

            w.state <= State_Decode;

          when Decoded_PopPC =>

            w.pc <= r.topOfStack(maxAddrBit downto 0);
            w.topOfStack <= memARead;
            w.sp <= r.sp + 1;
            poppc_inst <= '1';

            memBAddr <= r.topOfStack(maxAddrBit downto minAddrBit);
            memAAddr <= r.sp;
            memAWrite <= r.topOfStack;
            memAWriteEnable <= '1';

            w.state <= State_Decode;

          when Decoded_Interrupt =>

            w.pc <= to_unsigned(32, maxAddrBit+1);

            w.topOfStack <= (others => '0');
            w.topOfStack(maxAddrBit downto 0) <= r.pc;
            w.sp <= r.sp - 1;

            memBAddr <= (others => '0');
            memBAddr(minAddrBit+3 downto minAddrBit) <= "1000";

            memAAddr <= r.sp;
            memAWrite <= r.topOfStack;
            memAWriteEnable <= '1';

            w.state <= State_Decode;

          when Decoded_Emulate =>

            w.sp <= r.sp - 1;
            memAWriteEnable <= '1';
            memAAddr <= r.sp;
            memAWrite <= r.topOfStack;
            w.topOfStack <= (others => '0');
            w.topOfStack(maxAddrBit downto 0) <= r.pc;

            w.pc <= (others => '0');
            w.pc(9 downto 5) <= unsigned(opcode(4 downto 0));

            memBAddr <= (others => '0');
            memBAddr(9 downto 5) <= unsigned(opcode(4 downto 0));

            w.state <= State_Decode;

          when Decoded_PushSP =>

            w.sp <= r.sp - 1;
            memAWriteEnable <= '1';
            memAAddr <= r.sp;
            memAWrite <= r.topOfStack;

            w.topOfStack <= (others => '0');
            w.topOfStack(maxAddrBit downto minAddrBit) <= r.sp;

            w.state <= State_Decode;

          when Decoded_Add =>

            w.sp <= r.sp + 1;
            w.topOfStack <= r.topOfStack + memARead;

            w.state <= State_Decode;

          when Decoded_And =>

            w.sp <= r.sp + 1;
            w.topOfStack <= r.topOfStack and memARead;

            w.state <= State_Decode;

          when Decoded_Eq =>
            w.sp <= r.sp + 1;

            w.topOfStack <= (others => '0');
            if memARead = r.topOfStack then
              w.topOfStack(0) <= '1';
            end if;
            w.state <= State_Decode;

          when Decoded_Or =>

            w.sp <= r.sp + 1;
            w.topOfStack <= r.topOfStack or memARead;

            w.state <= State_Decode;

          when Decoded_Not =>

            w.topOfStack <= not r.topOfStack;

            w.state <= State_Decode;

          when Decoded_Flip =>

            for i in 0 to wordSize-1 loop
              w.topOfStack(i) <= r.topOfStack(wordSize-1-i);
            end loop;

            w.state <= State_Decode;

          when Decoded_LoadSP =>

            w.sp <= r.sp - 1;
            memAWriteEnable <= '1';
            memAAddr <= r.sp;
            memAWrite <= r.topOfStack;
            -- We need to load here next value.
            memBAddr <= r.sp + spOffset;
            w.state <= State_LoadSP;

          when Decoded_Dup =>

            w.sp <= r.sp - 1;
            memAWriteEnable <= '1';
            memAAddr <= r.sp;
            memAWrite <= r.topOfStack;
            w.state <= State_Decode;

          when Decoded_AddSP =>

            memAAddr <= r.sp + spOffset;
            w.state <= State_AddSP;

          when Decoded_Shift =>

            w.topOfStack <= r.topOfStack + r.topOfStack;

            w.state <= State_Decode;

          when Decoded_StoreSP =>

            w.sp <= r.sp + 1;
            memAAddr <= r.sp + spOffset;
            memAWriteEnable <= '1';
            memAWrite <= r.topOfStack;
            w.topOfStack <= memARead;

            w.state <= State_Decode;

          when Decoded_PopDown =>
            w.sp <= r.sp + 1;
            memAAddr <= r.sp;
            memAWriteEnable <= '1';
            memAWrite <= r.topOfStack;
            w.state <= State_Decode;

          when Decoded_Pop =>
            w.sp <= r.sp + 1;
            memAAddr <= r.sp;
            memAWriteEnable <= '1';
            memAWrite <= r.topOfStack;
            w.topOfStack <= memARead;
            w.state <= State_Decode;

          when Decoded_Store =>
            -- TODO: Ensure we can wait here for busy.
            if io_busy='0' then
              w.sp <= r.sp + 2;
            end if;

            io_addr(maxAddrBitIncIO downto 0) <= std_logic_vector(r.topOfStack(maxAddrBitIncIO downto 0));
            io_write <= std_logic_vector(memARead);
            memBWrite <= memARead;
            memBAddr <= r.topOfStack(maxAddrBit downto minAddrBit);
            memAAddr <= r.sp + 1;

            if r.topOfStack(maxAddrBitIncIO)='1' then
              io_wr <='1';
            else
              memBWriteEnable <= '1';
            end if;
            -- We need to maintain address for memA.

            -- TODO: fix this
            --memAAddr <= r.sp + 2;
            if io_busy='0' then
              w.state <= State_Resync1;
            else
              w.state <= State_WaitIO;
            end if;

          when Decoded_Load =>

            io_addr(maxAddrBitIncIO downto 0) <= std_logic_vector(r.topOfStack(maxAddrBitIncIO downto 0));
            memAAddr <= r.topOfStack(maxAddrBit downto minAddrBit);

            if r.topOfStack(maxAddrBitIncIO)='1' then
              io_rd <= '1';
            end if;

            w.state <= State_Load;

          when Decoded_PopSP =>
            -- The long lag...
            -- We don't need to sync top of stack here. Do we ?

            memAAddr <= r.topOfStack(maxAddrBit downto minAddrBit);
            w.sp <= r.topOfStack(maxAddrBit downto minAddrBit);

            w.state <= State_Resync2;

          when Decoded_Break =>
            w.break <= '1';

          when Decoded_Neqbranch =>

            w.sp <= r.sp + 2;
            if memARead/=0 then
              w.pc <= r.pc + r.topOfStack(maxAddrBit downto 0);
            else
              w.pc <= r.pc + 1;
            end if;
            w.state <= State_Resync1;

          when Decoded_StoreB =>
            -- This can never target IO devices.
            memAWrite <= (others => DontCareValue);
            memAAddr <= r.topOfStack(maxAddrBit downto minAddrBit);

            case r.topOfStack(1 downto 0) is
            when "00" =>
              memAWriteMask <= "1000";
              memAWrite(31 downto 24) <= memARead(7 downto 0);
              
            when "01" =>
              memAWriteMask <= "0100";
              memAWrite(23 downto 16) <= memARead(7 downto 0);

            when "10" =>
              memAWriteMask <= "0010";
              memAWrite(15 downto 8) <= memARead(7 downto 0);

            when "11" =>
              memAWriteMask <= "0001";
              memAWrite(7 downto 0) <= memARead(7 downto 0);

            when others =>
            end case;

            memAWriteEnable <= '1';
            w.sp <= r.sp + 2;
            w.state <= State_Resync1;

          when others =>
            w.break <= '1';

        end case;

      when State_WaitIO =>
        if io_busy='0' then
          w.sp <= r.sp + 2;
        end if;

        io_addr(maxAddrBitIncIO downto 0) <= std_logic_vector(r.topOfStack(maxAddrBitIncIO downto 0));
        io_write <= std_logic_vector(memARead);

        --memBAddr <= r.topOfStack(maxAddrBit downto minAddrBit);
        memAAddr <= r.sp + 1;

        io_wr <='1';

        if io_busy='0' then
          w.state <= State_Resync1;
        end if;

      when State_LoadSP =>

        memBAddr <= pc_to_memaddr(r.pc);
        -- We have now value to load.
        w.topOfStack <= memBRead;
        w.state <= State_Decode;

      when State_AddSP =>

        memBAddr <= pc_to_memaddr(r.pc);
        -- We have now value to load.
        w.topOfStack <= r.topOfStack + memARead;
        w.state <= State_Decode;
        
      when State_Load =>
        memBAddr <= pc_to_memaddr(r.pc);

        -- TODO: add wait here
        if r.topOfStack(maxAddrBitIncIO)='1' then
          if io_busy='0' then
            w.topOfStack <= unsigned(io_read);
            w.state <= State_Decode;
          end if;
        else
          w.topOfStack <= memARead;
          w.state <= State_Decode;
        end if;

      when others =>
         null;
    end case;

  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        r.sp <= unsigned(spStart(maxAddrBit downto minAddrBit));
        r.pc <= (others => '0');
        r.state <= State_Resync1;
        r.idim <= '0';
        r.topOfStack <= (others => '0');
        r.break <= '0';
        r.inInterrupt<='1';
      else
        if doInterrupt='1' then
          decodedOpcode <= Decoded_Interrupt;
          report "Interrupt!" severity note;
        else
          decodedOpcode <= sampledDecodedOpcode;
        end if;
        opcode <= sampledOpcode;
        r <= w;
        if w.break='1' then
          report "BREAK" severity failure;
        end if;
      end if;
    end if;
  end process;

end behave;

