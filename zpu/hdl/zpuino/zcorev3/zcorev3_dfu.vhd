library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library work;
use work.zpu_config.all;
use work.zpupkg.all;
use work.zpuinopkg.all;
use work.zcorev3pkg.all;
use work.wishbonepkg.all;

entity zcorev3_dfu is

  port (
    syscon:       in  wb_syscon_type;
    -- Data registers output
    dr:           out decoderegs_type;
    -- Instruction cache interface
    ici:          out icache_in_type;
    ico:          in  icache_out_type;
    -- Interrupt request
    int:          in boolean;
    -- Jump request and address
    jmp:          in boolean;
    ja:           in unsigned(maxAddrBitBRAM downto 0);
    -- Hold request
    hold:         in boolean
  );

end entity zcorev3_dfu;


architecture behave of zcorev3_dfu is

  signal r:       decoderegs_type;
  signal sop:     opcode_type;
  signal pcnext:  unsigned(maxAddrBitBRAM downto 0);  -- Helper only. TODO: move into variable


begin

  dr <= r;

  decodeControl: process(ico, r.pcint, r, int)

    variable tOpcode : std_logic_vector(OpCode_Size-1 downto 0);
    variable localspOffset: unsigned(4 downto 0);
    variable tOpcode_sel: integer range 0 to 3;

  begin
      tOpcode_sel := to_integer(r.pcint(minAddrBit-1 downto 0));

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

    if int and r.im='0' then
      sop.decoded <= Decoded_Interrupt;
      sop.stackOper <= Stack_Push;
      sop.tosSource <= Tos_Source_PC;
    else
    if (tOpcode(7 downto 7)=OpCode_Im) then
      if r.im='0' then
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
        elsif (tOpcode(5 downto 0)=OpCode_CallPCrel) then
          sop.decoded<=Decoded_Callpcrel;
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
        elsif (tOpcode(5 downto 0)=OpCode_StoreH) then
          sop.decoded<=Decoded_StoreH;
          sop.stackOper<=Stack_DualPop;
          sop.freeze<='1';
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
          sop.stackOper<=Stack_Push;
          sop.tosSource<=Tos_Source_FetchPC;

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

    pcnext <= r.fetchpc + 1;

    process(r, r.op, ja, jmp, syscon, sop, hold, ico, pcnext )
      variable w: decoderegs_type;
    begin

      w := r;
      ici.address(maxAddrBitBRAM downto 0) <= std_logic_vector(r.fetchpc(maxAddrBitBRAM downto 0));

      case r.state is

        when State_Run =>

          if (not hold) or (not r.valid) then
            if not r.valid then
              ici.strobe <= '1';
              ici.enable <= '1';
            else
              if hold then
                ici.strobe <= '0';
                ici.enable <= '0';
              else
                ici.strobe <= '1';
                ici.enable <= '1';
              end if;
            end if;

            if ico.stall='0' then
              w.fetchpc := pcnext;
            end if;

            if jmp then
              w.valid := false;
              w.im := '0';
              w.break := '0'; -- Invalidate eventual break after branch instruction
              ici.strobe <='0';
              w.fetchpc := ja;
              w.state := State_Jump;
            else
              if ico.valid='1' then
                w.im := sop.opcode(7);
                w.valid:=true; 
              else
                w.valid := false;
              end if;

              if ico.stall='0' then
                w.pcint := r.fetchpc;
                w.pc := r.pcint;
              end if;
            end if;

            w.op := sop;
            w.idim := r.im;
          else
            ici.strobe <= '0';
            ici.enable <= '0';

          end if;

        when State_Jump =>

          w.valid := false;
          ici.strobe <= '1';
          ici.enable <= '1';
          if ico.stall='0' then
            w.pcint := r.fetchpc;
            w.fetchpc := pcnext;
            w.state := State_Run;
          end if;

      end case;

    --
    -- Reset handling
    --
    if syscon.rst='1' then
      w.valid   := false;
      w.fetchpc := (others => '0');
      w.im      :='0';
      w.im_emu  :='0';
      w.state   := State_Run;
    end if;

    if rising_edge(syscon.clk) then
      r <= w;
    end if;

  end process;

end behave;

