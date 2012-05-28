--
--  Multi SPI interface for ZPUINO
-- 
--  Copyright 2010 Alvaro Lopes <alvieboy@alvie.com>
-- 
--  Version: 1.0
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

entity multispi is
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
    lmosi:     out std_logic_vector(7 downto 0);
    lsck:      out std_logic_vector(7 downto 0);

    -- SPI flash
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
    nsel: std_logic; -- Flash nsel

    -- flash controller signals (registered)
    fdin: std_logic_vector(31 downto 0);
    fdout: std_logic_vector(31 downto 0);
    ftsize: std_logic_vector(1 downto 0);
    fen: std_logic;
    seldly: unsigned(1 downto 0);
    maddr: std_logic_vector(31 downto 0);
    ctrln: std_logic_vector(2 downto 0); -- Controller number for this led
    rgb: std_logic_vector(23 downto 0);
    rgbseq: unsigned(1 downto 0);
    ctrlen: std_logic;

    nleds:  unsigned(10 downto 0);
    ledcnt: unsigned(10 downto 0);

    ack: std_logic;

  end record;

  signal r: regstype;
  signal fready: std_logic;
  signal fdout: std_logic_vector(31 downto 0);
  signal fspi_clken: std_logic;
  signal fspi_clkrise: std_logic;
  signal fspi_clkfall: std_logic;
  signal ctrlready: std_logic;


  signal ispi_clken:    std_logic_vector(7 downto 0);
  signal ispi_clkrise:  std_logic_vector(7 downto 0);
  signal ispi_clkfall:  std_logic_vector(7 downto 0);
  signal ictrlen:  std_logic_vector(7 downto 0);
  signal ictrlsel:  std_logic_vector(7 downto 0);
  signal ictrlready:  std_logic_vector(7 downto 0);
  signal ictrldata: std_logic_vector(31 downto 0);

begin

  process( r.ctrln, ictrlready )
  begin
    case r.ctrln is
      when "000" =>
        ictrlsel <= "00000001";
        ctrlready <= ictrlready(0);
      when "001" =>
        ictrlsel <= "00000010";
        ctrlready <= ictrlready(1);
      when "010" =>
        ictrlsel <= "00000100";
        ctrlready <= ictrlready(2);
      when "011" =>
        ictrlsel <= "00001000";
        ctrlready <= ictrlready(3);
      when "100" =>
        ictrlsel <= "00010000";
        ctrlready <= ictrlready(4);
      when "101" =>
        ictrlsel <= "00100000";
        ctrlready <= ictrlready(5);
      when "110" =>
        ictrlsel <= "01000000";
        ctrlready <= ictrlready(6);
      when "111" =>
        ictrlsel <= "10000000";
        ctrlready <= ictrlready(7);
      when others =>
        ictrlsel <= (others => DontCareValue);
        ctrlready <='1';
    end case;
  end process;  

  fnsel <= r.nsel;

  mi_wb_adr_o(maxAddrBitIncIO downto 0) <= r.maddr(maxAddrBitIncIO downto 0);
  mi_wb_sel_o <= (others =>'1');
  mi_wb_dat_o <= (others =>DontCareValue);
  mi_wb_we_o <= '0';

  wb_dat_o(0) <= '0' when r.state=idle else '1';
  wb_dat_o(31 downto 1) <= (others => '0');
  wb_ack_o <= r.ack;

  process(wb_clk_i,wb_rst_i,r,fready,fdout,mi_wb_ack_i,mi_wb_dat_i,ctrlready, wb_stb_i,wb_cyc_i, wb_dat_i,wb_adr_i,wb_we_i)
    variable w: regstype;
    variable moff: std_logic_vector(31 downto 0);
    variable color: std_logic_vector(6 downto 0);
    variable do_start: std_logic;
  begin
    w:=r;

    w.fen :='0';
    mi_wb_cyc_o <= '0';
    mi_wb_stb_o <= DontCareValue;

    ictrldata(31 downto 24) <= (others =>'0');
    ictrldata(23 downto 0) <= r.rgb;

    do_start := '0';

    -- Wishbone access
    w.ack := '0';

    if wb_cyc_i='1' and wb_stb_i='1' then
      w.ack :='1';
     if wb_we_i='1' then
      case wb_adr_i(3 downto 2) is
        when "00" =>
          do_start := '1';
        when "01" =>
          w.spibaseaddr := unsigned(wb_dat_i(23 downto 0));
        when "10" =>
          w.membaseaddr := unsigned(wb_dat_i);
        when "11" =>
          w.nleds := unsigned(wb_dat_i(10 downto 0));
        when others =>
      end case;
    end if;
    end if;




    case r.state is
      when idle =>
        if do_start='1' then
        w.state := waitsel;
        w.nsel := '0';
        w.seldly := "11";
        w.ledcnt := r.nleds;
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
        moff(15 downto 0) := fdout(15 downto 0);
        moff(31 downto 8) := (others => '0');

        w.maddr := std_logic_vector(unsigned(moff) + unsigned(r.membaseaddr));
        w.ctrln := fdout(18 downto 16); -- Save controller number

        if fready='1' then
          w.state := memory;
          w.ftsize := "10";
        end if;

      when memory =>
        mi_wb_cyc_o <= '1';
        mi_wb_stb_o <= '1';
        w.rgb := mi_wb_dat_i(31 downto 8);

        if mi_wb_ack_i='1' then
          w.state := processrgb;
        end if;

      when processrgb =>
        -- At this point we have controller number and
        -- all data we need.
        if ctrlready='1' then
          w.ctrlen := '1';
          w.state := leave;
        end if;

      when leave =>
        w.ctrlen := '0';
        if (r.ledcnt="00000000000") then
          w.nsel := '1';
          w.state := flush;
        else
          w.ledcnt := r.ledcnt - 1;
          w.state := waitload;
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
      w.nleds := "00000001000";
    end if;

    if rising_edge(wb_clk_i) then
      r <= w;
    end if;

  end process;





  -- Flash controller
  fspi: spi
    port map (
      clk   => wb_clk_i,
      rst   => wb_rst_i,
      din   => r.fdin,
      dout  => fdout,
      en    => r.fen,
      ready => fready,
      transfersize  => r.ftsize,
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
      pres  => "011",
    
      clkrise => fspi_clkrise,
      clkfall => fspi_clkfall,
      spiclk  => fsck
  );


  -- Individual SPI controllers for each strip



  ictrl: for i in 0 to 7 generate

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
      pres  => "100",
    
      clkrise => ispi_clkrise(i),
      clkfall => ispi_clkfall(i),
      spiclk  => lsck(i)
    );
  end generate;


end behave;



