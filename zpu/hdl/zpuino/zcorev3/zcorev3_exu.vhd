library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library work;
use work.zpu_config.all;
use work.zpupkg.all;
use work.zpuinopkg.all;
use work.zcorev3pkg.all;
use work.wishbonepkg.all;

entity zcorev3_exu is
  port (
    syscon:       in  wb_syscon_type;
    -- Signals from delay slot
    dri:          in  evalregs_type;
    -- Data registers output
    dr:           out exuregs_type;
    valid:        in boolean;
    -- SP Load
    newsp:        out unsigned(maxAddrBitBRAM downto 2);
    loadsp:       out boolean;
    -- Jump request and address
    jmp:          out boolean;
    ja:           out unsigned(maxAddrBitBRAM downto 0);
    poppc_inst:   out std_logic;
    -- Pipeline control
    hold:         in  boolean;
    busy:         out boolean;
    -- Data access
    dci:          out dcache_in_type;
    dco:          in dcache_out_type;
    -- IO Access
    iowbi:           in wb_miso_type;
    iowbo:           out wb_mosi_type
  );
end entity zcorev3_exu;

architecture behave of zcorev3_exu is

  signal r: exuregs_type;
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

  signal dbuf_we:     std_logic;
  signal dbuf_waddr:  std_logic_vector(maxAddrBitBRAM downto 2);
  signal dbuf_wdat:   std_logic_vector(31 downto 0);
  signal dbuf_raddr:  std_logic_vector(maxAddrBitBRAM downto 2);
  signal dbuf_re:     std_logic;
  signal dbuf_present: std_logic;
  signal dbuf_rdat:    std_logic_vector(31 downto 0);

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

  -- Dirty buffer

  dbuf: zcorev3_dbuf
  port map (
    syscon  => syscon,
    we      => dbuf_we,
    waddr   => dbuf_waddr,
    wdat    => dbuf_wdat,
    raddr   => dbuf_raddr,
    re      => dbuf_re,
    present => dbuf_present,
    rdat    => dbuf_rdat
  );

  newsp <= r.tos(maxAddrBitBRAM downto 2);

  process(dri,r)
  begin
        trace_pc <= (others => '0');
        trace_pc(maxAddrBit downto 0) <= std_logic_vector(dri.pc);
        trace_opcode <= dri.op.opcode;
        trace_sp <= (others => '0');
        trace_sp(maxAddrBitBRAM downto 2) <= std_logic_vector(dri.sp);
        trace_topOfStack <= std_logic_vector( r.tos );
        trace_topOfStackB <= std_logic_vector( r.nos );
  end process;


  begin_inst <= '1' when valid and r.state=State_Execute else '0';--and not busy;
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

  -- IO/Memory Accesses
  iowbo.cyc <= r.wb_cyc;
  iowbo.stb <= r.wb_stb;
  iowbo.we <= r.wb_we;

  process(r.wb_adr)
  begin
    iowbo.adr <= (others => '0');
    iowbo.adr(maxAddrBitIncIO downto 2) <= r.wb_adr;
  end process;
  iowbo.dat <= r.wb_dat;

  process(r, syscon, dco,
          r, dri, dri.op,
          iowbi,
          lshifter_done,
          lshifter_output,
          dbuf_present,
          dbuf_rdat
          )

    variable w: exuregs_type;
    variable instruction_executed: std_logic;
    variable wroteback: std_logic;
    variable datawrite: std_logic_vector(wordSize-1 downto 0);
    variable sel: std_logic_vector(3 downto 0);
    variable b_strobe: std_logic;
    variable b_enable: std_logic;
    variable b_we: std_logic;
    variable wmask: std_logic_vector(3 downto 0);
    variable b_address: std_logic_vector(31 downto 0);

    variable b_din: std_logic_vector(31 downto 0);
    variable b_data_out: std_logic_vector(31 downto 0);
    variable read: std_logic_vector(31 downto 0);
  begin

    w := r;

    instruction_executed := '0';

    w.wb_stb := DontCareValue;
    w.wb_cyc := '0';
    w.wb_we := DontCareValue;
    w.wb_adr := (others => DontCareValue);
    w.wb_dat := (others => DontCareValue);

    b_enable :='1';
    b_strobe :='0';

    if dbuf_present='1' then
      read := dbuf_rdat;
    else
      read := dri.read;
    end if;
    --else
    b_data_out := dco.b_data_out;
    --end if;

    b_we := '0';
    wmask := "0000";

    busy <= false;

    jmp <= false;

    ja <= (others => DontCareValue);

    lshifter_enable <= '0';
    lshifter_amount <= std_logic_vector(r.tos_save);
    lshifter_input <= std_logic_vector(r.nos_save);
    lshifter_multorshift <= '0';

    poppc_inst <= '0';

    b_address := (others => '0');
    b_address(maxAddrBitBRAM downto 2) := std_logic_vector( dri.sp );

    b_din := std_logic_vector( r.tos );

    if iowbi.int='0' then
      w.inInterrupt := '0';
    end if;


    loadsp <= false;

    case r.state is

      when State_ResyncFromStoreStack =>
        busy <= true;
        if dco.b_stall='0' then
          w.state := State_ResyncNos;
        end if;
        b_address(maxAddrBitBRAM downto 2) := std_logic_vector(dri.spnext+1);
        b_din := (others => DontCareValue);
        b_enable := '1';
        b_strobe := '1';
        wroteback := '0';

      when State_ResyncNos =>

        w.nos := unsigned( b_data_out );
        b_address(maxAddrBitBRAM downto 2)  := std_logic_vector(dri.spnext);
        b_din := (others => DontCareValue);
        b_enable := '1';
        b_strobe := '1';
        busy <= true;
        wroteback := '0';
        if dco.b_valid='1' and dco.b_stall='0' then
          w.state := State_Resync2;
        end if;

      when State_Resync2 =>
        b_din := (others => DontCareValue);
        b_address := (others => DontCareValue);
        w.tos := unsigned( b_data_out );
        instruction_executed := '1';
        wroteback := '0';
        busy<=true;
        if dco.b_valid='1' then
          w.state := State_Execute;
          busy <= false;
        end if;

      when State_Execute =>

       instruction_executed:='0';

       if valid then

        busy <= dri.op_freeze;



        wroteback := '0';
        w.nos_save := r.nos;
        w.tos_save := r.tos;
        w.idim := dri.idim;

        instruction_executed := '1';

        -- NOS computation
        if dri.writeback='1' then
          w.nos := r.tos;
          b_enable := '1';
          b_strobe := '1';
        end if;

        if dri.readback='1' then
          w.nos := unsigned(read);--dco.a_data_out);
        end if;

        -- TOS big muxer

        case dri.op.tosSource is
          when Tos_Source_PC =>
            w.tos := (others => '0');
            w.tos(maxAddrBit downto 0) := dri.pc;

          when Tos_Source_FetchPC =>
            w.tos := (others => '0');
            w.tos(maxAddrBit downto 0) := dri.fetchpc;

          when Tos_Source_Idim0 =>
            for i in wordSize-1 downto 7 loop
              w.tos(i) := dri.op.opcode(6);
            end loop;
            w.tos(6 downto 0) := unsigned(dri.op.opcode(6 downto 0));

          when Tos_Source_IdimN =>
            w.tos(wordSize-1 downto 7) := r.tos(wordSize-8 downto 0);
            w.tos(6 downto 0) := unsigned(dri.op.opcode(6 downto 0));

          when Tos_Source_StackB =>
            w.tos := r.nos;

          when Tos_Source_SP =>
            w.tos := (others => '0');
            w.tos(maxAddrBitBRAM downto 2) := dri.sp;

          when Tos_Source_Add =>
            w.tos := r.tos + r.nos;

          when Tos_Source_And =>
            w.tos := r.tos and r.nos;

          when Tos_Source_Or =>
            w.tos := r.tos or r.nos;

          when Tos_Source_Eq =>
            w.tos := (others => '0');
            if r.nos = r.tos then
              w.tos(0) := '1';
            end if;

          when Tos_Source_Ulessthan =>
            w.tos := (others => '0');
            if r.tos < r.nos then
              w.tos(0) := '1';
            end if;

          when Tos_Source_Lessthan =>
            w.tos := (others => '0');
            if signed(r.tos) < signed(r.nos) then
              w.tos(0) := '1';
            end if;

          when Tos_Source_Not =>
            w.tos := not r.tos;

          when Tos_Source_Flip =>
            for i in 0 to wordSize-1 loop
              w.tos(i) := r.tos(wordSize-1-i);
            end loop;

          when Tos_Source_LoadSP =>
            w.tos := unsigned( read );--dco.a_data_out );

          when Tos_Source_AddSP =>
            w.tos := w.tos + unsigned(read);--dco.a_data_out );

          when Tos_Source_AddStackB =>
            w.tos := w.tos + r.nos;

          when Tos_Source_Shift =>
            w.tos := r.tos + r.tos;

          when others =>

        end case;

        case dri.op.decoded is

          when Decoded_Interrupt =>

           w.inInterrupt := '1';
           ja <= to_unsigned(32, maxAddrBit+1);
           if dco.b_stall='1' then
            jmp<=false;
           else
            jmp<=true;
           end if;

           b_we :='1';
           wmask :="1111";

           wroteback:='1';
           instruction_executed := '0';

          when Decoded_Im0 =>

           b_we :='1';
           wmask :="1111";
           wroteback:='1';

          when Decoded_ImN =>

          when Decoded_Nop =>

          when Decoded_PopPC =>

             if dco.b_stall='1' then
            jmp<=false;
           else
            jmp<=true;
           end if;

            ja <= r.tos(maxAddrBit downto 0);
            poppc_inst <= not dco.b_stall;
            instruction_executed := '0';

          when Decoded_Call =>

            jmp <= true;
            ja <= r.tos(maxAddrBit downto 0);
            instruction_executed := '0';

          when Decoded_CallPCRel =>

            jmp <= true;
            ja <= r.tos(maxAddrBit downto 0) + dri.pc;
            instruction_executed := '0';

          when Decoded_Emulate =>
            if dco.b_stall='1' then
              jmp<=false;
            else
              jmp<=true;
            end if;
            ja <= (others => '0');
            ja(9 downto 5) <= unsigned(dri.op.opcode(4 downto 0));

            b_we :='1';
            wmask :="1111";

            wroteback:='1';

          when Decoded_PushSP =>
            b_we :='1';
            wmask :="1111";
            wroteback:='1';

          when Decoded_LoadSP =>
            b_we :='1';
            wmask :="1111";
            wroteback:='1';

          when Decoded_DupStackB =>
            b_we :='1';
            wmask :="1111";
            wroteback:='1';

          when Decoded_Dup =>
            b_we :='1';
            wmask :="1111";
            wroteback:='1';

          when Decoded_AddSP =>

          when Decoded_StoreSP =>
            b_we :='1';
            wmask :="1111";
            b_strobe := '1';
            wroteback:='1';
            b_address(maxAddrBitBRAM downto 2) := std_logic_vector(dri.sp + dri.op.spOffset);
            instruction_executed := '0';

          when Decoded_PopDown =>

          when Decoded_PopDownDown =>
            b_we :='1';
            wmask :="1111";
            w.nos := r.tos;
            b_strobe := '1';
            wroteback:='1';
            b_address(maxAddrBitBRAM downto 2) := std_logic_vector(dri.sp + dri.op.spOffset);

          when Decoded_Pop =>

          when Decoded_Ashiftleft =>
            --busy<='1';
            w.state := State_Ashiftleft;

          when Decoded_Mult  =>
            --busy<='1';
            w.state := State_Mult;

          when Decoded_MultF16  =>
            --busy<='1';
            w.state := State_MultF16;

          when Decoded_Store | Decoded_StoreB | Decoded_StoreH =>

              if dri.op.decoded=Decoded_Store then
                datawrite := std_logic_vector(r.nos);
                sel := "1111";

              elsif dri.op.decoded=Decoded_StoreH then
                datawrite := (others => DontCareValue);
                if r.tos(1)='1' then
                  datawrite(15 downto 0) := std_logic_vector(r.nos(15 downto 0))  ;
                  sel := "0011";
                else
                  datawrite(31 downto 16) := std_logic_vector(r.nos(15 downto 0))  ;
                  sel := "1100";
                end if;
              else
                datawrite := (others => DontCareValue);
                case r.tos(1 downto 0) is
                  when "11" =>
                    datawrite(7 downto 0) := std_logic_vector(r.nos(7 downto 0))  ;
                    sel := "0001";
                  when "10" =>
                    datawrite(15 downto 8) := std_logic_vector(r.nos(7 downto 0))  ;
                    sel := "0010";
                  when "01" =>
                    datawrite(23 downto 16) := std_logic_vector(r.nos(7 downto 0))  ;
                    sel := "0100";
                  when "00" =>
                    datawrite(31 downto 24) := std_logic_vector(r.nos(7 downto 0))  ;
                    sel := "1000";

                  when others => null;

                end case;
              end if;

            w.nos := r.nos;

            instruction_executed:='0';

            if r.tos(maxAddrBitIncIO)='0' then

              b_enable := '1';
              b_strobe := '1';
              b_we :='1';
              wmask := sel;

              if dco.b_stall='0' then
                w.state := State_ResyncFromStoreStack;
                instruction_executed:='1';
              end if;

            else
              --b_enable :='0';
              b_strobe :='0';
              b_we :='0';
              wmask := (others => '0');
              w.wb_cyc := '1';
              w.wb_stb := '1';
              w.wb_we := '1';
              w.wb_adr := std_logic_vector(r.tos(r.wb_adr'RANGE));
              w.wb_dat := std_logic_vector(r.nos);

              if iowbi.ack='1' then
                instruction_executed:='1';
                w.wb_cyc := '0';
                w.state := State_ResyncFromStoreStack;
              end if;

            end if;

            b_address(maxAddrBitBRAM downto 2)  := std_logic_vector(r.tos(maxAddrBitBRAM downto 2));
            b_din := datawrite;

          when Decoded_Load | Decoded_Loadb | Decoded_Loadh =>

            instruction_executed := '0';

            b_address(maxAddrBitBRAM downto 2) := std_logic_vector(r.tos(maxAddrBitBRAM downto 2));

            if r.tos(maxAddrBitIncIO)='0' then
              b_enable := '1';
              b_strobe := '1';
              --if dco.b_stall='0' then
                w.state := State_LoadStack;
              --end if;
            else
              --b_enable := '0';
              b_strobe := '0';

              w.wb_cyc:='1';
              w.wb_stb:='1';
              w.wb_we:='0';
              w.wb_adr := std_logic_vector(r.tos(r.wb_adr'RANGE));
              if iowbi.ack='1' then
                w.tos := unsigned(iowbi.dat);

                if dri.op.decoded=Decoded_Loadb then
                  w.state:=State_Loadb;
                elsif dri.op.decoded=Decoded_Loadh then
                  w.state:=State_Loadh;
                else
                  instruction_executed:='1';
                  wroteback := '0';
                  busy <= false;
                end if;

              end if;

            end if;


          when Decoded_PopSP =>

            b_we :='1';
            wmask :="1111";
            instruction_executed := '0';
            w.state := State_PopSP;
            

          when Decoded_Break =>


            b_we :='1';
            wmask :="1111";
            wroteback:='1';
            if dco.b_stall='1' then
              jmp<=false;
            else
              jmp<=true;
            end if;
            ja <= (others => '0');
            instruction_executed := '0';

          when Decoded_Neqbranch =>
            instruction_executed := '0';
            w.state := State_NeqBranch;

          when others =>

        end case;

      else
        -- not valid
        b_address := (others => DontCareValue);
        b_din := (others => DontCareValue);

      end if; -- valid
      when State_PopSP => -- Note, this should be optimized.
        loadsp <= true;
        busy<=true;
        w.state := State_ResyncFromStoreStack;

      when State_Ashiftleft =>
        busy <= true;
        lshifter_enable <= '1';
        w.tos := unsigned(lshifter_output(31 downto 0));

        if lshifter_done='1' then
          busy<=true;
          w.state := State_Execute;
        end if;

      when State_Mult =>
        busy <= true;
        lshifter_enable <= '1';
        lshifter_multorshift <='1';
        w.tos := unsigned(lshifter_output(31 downto 0));

        if lshifter_done='1' then
          busy<=false;
          w.state := State_Execute;
        end if;

      when State_MultF16 =>
        busy <= true;
        lshifter_enable <= '1';
        lshifter_multorshift <='1';
        w.tos := unsigned(lshifter_output(47 downto 16));

        if lshifter_done='1' then
          busy<=false;
          w.state := State_Execute;
        end if;

      when State_WaitSPB =>

        instruction_executed:='1';
        wroteback := '0';
        w.state := State_Execute;
  
      when State_Loadb =>
        w.tos(wordSize-1 downto 8) := (others => '0');
        case r.tos_save(1 downto 0) is
          when "11" =>
            w.tos(7 downto 0) := unsigned(r.tos(7 downto 0));
          when "10" =>
            w.tos(7 downto 0) := unsigned(r.tos(15 downto 8));
          when "01" =>
            w.tos(7 downto 0) := unsigned(r.tos(23 downto 16));
          when "00" =>
            w.tos(7 downto 0) := unsigned(r.tos(31 downto 24));
          when others =>
            null;
        end case;
        instruction_executed:='1';
        wroteback := '0';
        w.state := State_Execute;

      when State_Loadh =>
        w.tos(wordSize-1 downto 8) := (others => '0');

        case r.tos_save(1) is
          when '1' =>
            w.tos(15 downto 0) := unsigned(r.tos(15 downto 0));
          when '0' =>
            w.tos(15 downto 0) := unsigned(r.tos(31 downto 16));
          when others =>
            null;
        end case;
        instruction_executed:='1';
        wroteback := '0';
        w.state := State_Execute;

      when State_LoadStack =>
        w.tos := unsigned( b_data_out );

        if dco.b_valid='1' then
          if dri.op.decoded=Decoded_Loadb then
            busy<=true;
            w.state:=State_Loadb;
          elsif dri.op.decoded=Decoded_Loadh then
            busy<=true;
            w.state:=State_Loadh;
          else
            instruction_executed:='1';
            wroteback := '0';
            w.state := State_Execute;
          end if;
        else
          busy<=true;
        end if;

      when State_NeqBranch =>
        if r.nos_save/=0 then
          jmp <= true;
          ja <= r.tos(maxAddrBit downto 0) + dri.pc;
          poppc_inst <= '1';
        end if;

        busy <= true;

        instruction_executed := '0';

        w.state := State_ResyncNos;
        b_address(maxAddrBitBRAM downto 2) := std_logic_vector(dri.spnext+1);
        --b_enable := '1';
        b_strobe := '1';

      when others =>
         null;

    end case;

    if b_strobe='1' and dco.b_stall='1' then
      busy<=true;
      w := r; -- Hold everything
    end if;
  

    if w.state = State_Execute and dri.valid then
      w.wroteback := dri.writeback;
    end if;

    dci.b_enable <= b_enable;
    dci.b_strobe <= b_strobe;
    dci.b_wmask  <= wmask;
    dci.b_we <= b_we;


    -- Only perform writes to dirty buffer if wmask is all ones.
    dbuf_waddr <= b_address(dbuf_waddr'RANGE);
    dbuf_raddr <= dri.raddr;
    dci.b_address <= b_address;
    dci.b_data_in <= b_din;
    dbuf_wdat <= b_din;

    dbuf_re <= '0';
    dbuf_we <= '0';
    if valid then
      dbuf_re    <= dri.request;
      if wmask="1111" and b_we='1' then
        dbuf_we    <= not dco.b_stall;
      else
        dbuf_we    <= '0';
      end if;
    end if;

    --if b_enable='0' then
    --  dci.b_address <= (others => DontCareValue);
    --  dci.b_data_in <= (others => DontCareValue);
    --end if;

    --if wmask="0000" then
    --  dci.b_data_in <= (others => DontCareValue);
    --end if;

    if rising_edge(syscon.clk) then
      if syscon.rst='1' then
        r.state <= State_Execute;
        r.idim <= DontCareValue;
        r.inInterrupt <= '0';
        r.break <= '0';
        r.wb_cyc <= '0';
        -- synopsys translate_off
        r.tos <= x"deadbeef";
        r.nos <= x"cafecafe";
        -- synopsys translate_on
        

        r.wroteback <= '0';
      else
        r <= w;

        if r.break='1' then
          report "BREAK" severity failure;
        end if;

        -- Some sanity checks, to be caught in simulation
        if dri.valid then
          if dri.op.tosSource=Tos_Source_Idim0 and dri.idim='1' then
            report "Invalid IDIM flag 0" severity error;
          end if;
  
          if dri.op.tosSource=Tos_Source_IdimN and dri.idim='0' then
            report "Invalid IDIM flag 1" severity error;
          end if;
        end if;

      end if;
    end if;

  end process;

end behave;
