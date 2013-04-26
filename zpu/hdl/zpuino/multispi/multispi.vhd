--
--  Multi SPI interface for ZPUINO
-- 
--  Copyright 2010 Alvaro Lopes <alvieboy@alvie.com>
-- 
--  Version: 1.1
-- 
--  The FreeBSD license
--  
--  Redistribution and use in source and binary forms, with or without
--  modification, are permitted provided that the following conditions
--  are met:
--  
--  1. Redistributions of source code must retain the above copyright
--     notice, this list of conditions and the following disclaimer.
--  2. Redistributions in binary form must reproduce the above
--     copyright notice, this list of conditions and the following
--     disclaimer in the documentation and/or other materials
--     provided with the distribution.
--  
--  THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY
--  EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
--  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
--  PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
--  ZPU PROJECT OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
--  INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
--  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
--  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
--  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
--  STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
--  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
--  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--  
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.zpu_config.all;
use work.zpuino_config.all;
use work.zpupkg.all;
use work.zpuinopkg.all;
-- synopsys translate_off
library work;
use work.txt_util.all;
-- synopsys translate_on

entity multispi is
  generic (
    spicount: integer := 10;
    memorymapping: boolean := true
  );
  port (
    wb_clk_i: in std_logic;
	 	wb_rst_i: in std_logic;
    wb_dat_o: out std_logic_vector(wordSize-1 downto 0);
    wb_dat_i: in std_logic_vector(wordSize-1 downto 0);
    wb_adr_i: in std_logic_vector(maxIObit downto minIObit);
    wb_we_i:  in std_logic;
    wb_cyc_i: in std_logic;
    wb_stb_i: in std_logic;
    wb_ack_o: out std_logic;
    wb_inta_o:out std_logic;

    -- Master interface (for DMA)

    mi_wb_dat_i: in std_logic_vector(wordSize-1 downto 0);
    mi_wb_dat_o: out std_logic_vector(wordSize-1 downto 0);
    mi_wb_adr_o: out std_logic_vector(maxAddrBitIncIO downto 0);
    mi_wb_sel_o: out std_logic_vector(3 downto 0);
    mi_wb_cti_o: out std_logic_vector(2 downto 0);
    mi_wb_we_o:  out std_logic;
    mi_wb_cyc_o: out std_logic;
    mi_wb_stb_o: out std_logic;
    mi_wb_ack_i: in std_logic;

    -- LED array interface (6 controllers)
    lmosi:     out std_logic_vector(spicount-1 downto 0);
    lsck:      out std_logic_vector(spicount-1 downto 0);

    -- SPI flash -- not used if memory mapping
    fmosi:      out std_logic;
    fmiso:      in std_logic;
    fsck:       out std_logic;
    fnsel:      out std_logic
  );
end entity multispi;







architecture behave of multispi is

  component spi is
    port (
      clk:  in std_logic;
      rst:  in std_logic;
      din:  in std_logic_vector(31 downto 0);
      dout:  out std_logic_vector(31 downto 0);
      en:   in std_logic;
      ready: out std_logic;
      transfersize: in std_logic_vector(1 downto 0);
      miso: in std_logic;
      mosi: out std_logic;
      clk_en:    out std_logic;
      clkrise: in std_logic;
      clkfall: in std_logic;
      samprise:in std_logic
    );
  end component spi;

  component spiclkgen is
    port (
      clk:   in std_logic;
      rst:   in std_logic;
      en:    in std_logic;
      cpol:  in std_logic;
      pres:  in std_logic_vector(2 downto 0);
    
      clkrise: out std_logic;
      clkfall: out std_logic;
      spiclk:  out std_logic
  );
  end component spiclkgen;


  type statetype is (
    idle,
    waitsel,
    seek,
    load,
    waitload,
    waitload2,
    waitload3,
    memory,
    processrgb,
    leave,
    flush
  );

  type regstype is record
    state: statetype;
    spibaseaddr: unsigned(23 downto 0);
    membaseaddr: unsigned(31 downto 0);
    mindex: unsigned(31 downto 0);
    mem2baseaddr: unsigned(31 downto 0); -- for mapping

    nsel: std_logic; -- Flash nsel

    -- flash controller signals (registered)
    fdin: std_logic_vector(31 downto 0);
    fdout: std_logic_vector(31 downto 0);
    ftsize: std_logic_vector(1 downto 0);
    fen: std_logic;
    seldly: unsigned(1 downto 0);
    ctrln: std_logic_vector(3 downto 0); -- Controller number for this led
    rgb: std_logic_vector(23 downto 0);
    rgbseq: unsigned(1 downto 0);
    ctrlen: std_logic;

    nleds:  unsigned(12 downto 0);
    ledcnt: unsigned(12 downto 0);

    ack: std_logic;
    directspi: std_logic; -- Direct access to SPI flash
    lpres: std_logic_vector(2 downto 0);
    fpres: std_logic_vector(2 downto 0);

    testcounter: unsigned(31 downto 0);

    -- Registered WB output/master
    wb_addr: std_logic_vector(31 downto 0);
    wb_cyc: std_logic;
    wb_stb: std_logic;

  end record;

  signal r: regstype;
  signal fready: std_logic;
  signal fdout: std_logic_vector(31 downto 0);
  signal fspi_clken: std_logic;
  signal fspi_clkrise: std_logic;
  signal fspi_clkfall: std_logic;
  signal ctrlready: std_logic;


  signal ispi_clken:    std_logic_vector(spicount-1 downto 0);
  signal ispi_clkrise:  std_logic_vector(spicount-1 downto 0);
  signal ispi_clkfall:  std_logic_vector(spicount-1 downto 0);
  signal ictrlen:  std_logic_vector(spicount-1 downto 0);
  signal ictrlsel:  std_logic_vector(spicount-1 downto 0);
  signal ictrlready:  std_logic_vector(spicount-1 downto 0);
  signal ictrldata: std_logic_vector(31 downto 0);

  signal flash_din, df_din: std_logic_vector(31 downto 0);
  signal flash_tsize, df_tsize: std_logic_vector(1 downto 0);
  signal flash_en, df_en: std_logic;

begin

  process( r.ctrln, ictrlready )
    variable ri: integer range 0 to spicount-1;
  begin
    ictrlsel <= (others => '0');
    ri := to_integer( unsigned(r.ctrln) );

    ictrlsel(ri) <= '1';
    ctrlready <= ictrlready(ri);

  end process;  

  fnsel <= r.nsel;

  mi_wb_adr_o(maxAddrBitIncIO downto 0) <= r.wb_addr(maxAddrBitIncIO downto 0);
  mi_wb_sel_o <= (others =>'1');
  mi_wb_dat_o <= (others =>DontCareValue);
  mi_wb_we_o <= '0';
  mi_wb_cyc_o <= r.wb_cyc;
  mi_wb_stb_o <= r.wb_stb;

  wb_ack_o <= r.ack;

  process (wb_adr_i,r,fdout)
  begin
    case wb_adr_i(4) is
      when '0' =>
        if r.state=idle then
          wb_dat_o(0) <= '0';
        else
          wb_dat_o(0) <= '1';
        end if;
        wb_dat_o(31 downto 1) <= (others => '0');
      when '1' =>
        wb_dat_o <= fdout;
      when others =>
    end case;
  end process;

  process(wb_clk_i,wb_rst_i,r,fready,fdout,mi_wb_ack_i,mi_wb_dat_i,ctrlready, wb_stb_i,wb_cyc_i, wb_dat_i,wb_adr_i,wb_we_i)
    variable w: regstype;
    variable moff: std_logic_vector(31 downto 0);
    variable color: std_logic_vector(6 downto 0);
    variable do_start: std_logic;
  begin
    w:=r;

    w.fen :='0';
    w.wb_cyc := '0';

    ictrldata(31 downto 24) <= (others =>'0');
    ictrldata(23 downto 0) <= r.rgb;

    do_start := '0';

    --mi_wb_adr_o(maxAddrBitIncIO downto 0) <= (others => DontCareValue);

    --mi_wb_adr_o(maxAddrBitIncIO downto 0) <= r.maddr(maxAddrBitIncIO downto 0);
    -- Wishbone access
    w.ack := '0';



    if wb_cyc_i='1' and wb_stb_i='1' then

      if wb_adr_i(5)='0' then
          w.ack :='1';
          if wb_we_i='1' then
            case wb_adr_i(4 downto 2) is
            when "000" =>
              do_start := wb_dat_i(0);
            when "001" =>
              w.spibaseaddr := unsigned(wb_dat_i(23 downto 0));
              w.mem2baseaddr := unsigned(wb_dat_i); 
            when "010" =>
              w.membaseaddr := unsigned(wb_dat_i);
            when "011" =>
              w.nleds := unsigned(wb_dat_i(12 downto 0));

            when "100" =>

              w.lpres := wb_dat_i(4 downto 2);
              w.fpres := wb_dat_i(7 downto 5);

            when others =>
            end case;
          end if;
      else

          -- Direct SPI access

      end if;
    end if;




    case r.state is
      when idle =>

      if memorymapping then
        w.wb_addr := std_logic_vector(r.mem2baseaddr);
        w.mindex := (others => '0');
        if do_start='1' then
          w.wb_cyc := '1';
          w.wb_stb := '1';
          w.ledcnt := r.nleds;
          w.testcounter:=(others =>'0');
          w.state := waitload3;
        end if;
      else
        if do_start='1' then
            w.state := waitsel;
            w.nsel := '0';
            w.seldly := "11";
            w.ledcnt := r.nleds;
            w.testcounter:=(others =>'0');
        end if;
      end if;

      when waitsel =>

        if r.seldly="00" then
          w.state := seek;
        else
          w.seldly:=r.seldly-1;
        end if;
      when seek =>
        --
        w.fdin(31 downto 24) := x"0b";
        w.fdin(23 downto 0) := std_logic_vector(r.spibaseaddr);
        w.ftsize := "11"; -- 32-bit
        w.fen :='1';
        w.state := load;

      when load =>
        w.fen := '0';
        w.state := waitload;

      when waitload =>

        if fready='1' then
          -- Write out data. One dummy byte, 3 data bytes (or only 24 bit, if not first time)
          w.fen:='1';
          w.state := waitload2;
        else

        end if;

      when waitload2 =>
        w.fen := '0';
        w.state := waitload3;

      when waitload3 =>
        w.fdout := fdout;

        -- 15 downto 0 -> offset into memory table
        if memorymapping then
          moff(15 downto 0) := mi_wb_dat_i(15 downto 0);
          moff(31 downto 16) := (others => '0');
        else
          moff(15 downto 0) := fdout(15 downto 0);
          moff(31 downto 16) := (others => '0');
        end if;

        if mi_wb_ack_i='1' then
          w.wb_addr := std_logic_vector(unsigned(moff) + unsigned(r.membaseaddr));
        else
          w.wb_cyc := '1';
        end if;

        if memorymapping then
          w.ctrln := mi_wb_dat_i(19 downto 16);
        else
          w.ctrln := fdout(19 downto 16); -- Save controller number
        end if;

        if memorymapping then
          if (memorymapping and mi_wb_ack_i='1') then
            w.state := memory;
          end if;
        else
        if fready='1' then
          w.state := memory;
          w.ftsize := "10";
          w.testcounter := r.testcounter + 4;
        end if;
        end if;

      when memory =>
        w.wb_cyc := '1';
        w.wb_stb := '1';

        if mi_wb_ack_i='1' then
          w.rgb := mi_wb_dat_i(31 downto 8);
          w.wb_cyc := '0';
          --w.rgb := "100000010011110010101010";
          w.state := processrgb;
        end if;

      when processrgb =>
        -- At this point we have controller number and
        -- all data we need.
        if ctrlready='1' then
          w.ctrlen := '1';
          w.state := leave;
          w.mindex := r.mindex + 4; -- Next mem position
        end if;

      when leave =>
        w.ctrlen := '0';
        if (r.ledcnt="0000000000000") then
          w.nsel := '1';
          w.state := flush;
        else
          w.ledcnt := r.ledcnt - 1;
          if memorymapping then
            w.wb_addr := std_logic_vector(r.mem2baseaddr + r.mindex);
            w.state := waitload3;
          else
            w.state := waitload;
          end if;
        end if;

      when flush =>
        --report "Not implemented" severity failure;
        w.state := idle;

      when others =>

    end case;

    if wb_rst_i='1' then
      w.state := idle;
      w.nsel := '1';
      w.spibaseaddr := (others => '0');
      w.membaseaddr := (others => '0');
      w.nleds := "0000000001000";
      w.directspi := '0';
      w.lpres := "101";
      w.fpres := "100";
    end if;

    if rising_edge(wb_clk_i) then
    -- synopsys translate_off
      if r.state=leave then
        report "LED " & hstr(std_logic_vector(r.ledcnt)) & " ctrl " & hstr(r.ctrln) & " address 0x" & hstr(r.wb_addr) & " offset 0x" & hstr(fdout(15 downto 0)) & " data 0x" & hstr(r.rgb);
      end if;
    -- synopsys translate_on
      r <= w;
    end if;

  end process;

  fl1: if memorymapping generate
    flash_en <= '0';
  end generate;

  fl2: if not memorymapping generate
    flash_din <= r.fdin;-- when r.directspi='0' else df_din;
    flash_tsize <= r.ftsize;-- when r.directspi='0' else df_tsize;
    flash_en <= r.fen;--   when r.directspi='0' else df_en;
  end generate;

  -- Flash controller
  fspi: spi
    port map (
      clk   => wb_clk_i,
      rst   => wb_rst_i,
      din   => flash_din,
      dout  => fdout,
      en    => flash_en,
      ready => fready,
      transfersize  => flash_tsize,
      miso  => fmiso,
      mosi  => fmosi,
      clk_en  => fspi_clken,
      clkrise => fspi_clkrise,
      clkfall => fspi_clkfall,
      samprise  => '1'
    );

  fspiclk: spiclkgen
    port map (
      clk   => wb_clk_i,
      rst   => wb_rst_i,
      en    => fspi_clken,
      cpol  => '1',
      pres  => r.fpres,--"011",
    
      clkrise => fspi_clkrise,
      clkfall => fspi_clkfall,
      spiclk  => fsck
  );


  -- Individual SPI controllers for each strip



  ictrl: for i in 0 to spicount-1 generate

    ictrlen(i) <= ictrlsel(i) and r.ctrlen;

    ledspi: spi
      port map (
        clk   => wb_clk_i,
        rst   => wb_rst_i,
        din   => ictrldata,
        dout  => open,
        en    => ictrlen(i),
        ready => ictrlready(i),
        transfersize  => "10", -- 24-bit
        miso  => DontCareValue,
        mosi  => lmosi(i),
        clk_en  => ispi_clken(i),
        clkrise => ispi_clkrise(i),
        clkfall => ispi_clkfall(i),
        samprise  => '1'
    );

    ledspiclk: spiclkgen
    port map (
      clk   => wb_clk_i,
      rst   => wb_rst_i,
      en    => ispi_clken(i),
      cpol  => '1',
      pres  => r.lpres, -- "100"
    
      clkrise => ispi_clkrise(i),
      clkfall => ispi_clkfall(i),
      spiclk  => lsck(i)
    );
  end generate;


end behave;



