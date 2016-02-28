LIBRARY IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
library work;
-- synopsys translate_off
use work.txt_util.all;
-- synopsys translate_on
use work.zpu_config.all;
use work.zpupkg.all;
use work.zpuino_config.all;
use work.zpuinopkg.all;


ENTITY usbctrl IS
  PORT (
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
    id:       out slot_id;

    -- Interface to transceiver
    softcon:  out std_logic;
    noe:      out std_logic;
    speed:    out std_logic;
    vpo:      out std_logic;
    vmo:      out std_logic;

    rcv:      in std_logic;
    vp:       in  std_logic;
    vm:       in  std_logic
  );
END entity usbctrl;

ARCHITECTURE rtl OF usbctrl is

  SIGNAL  Phy_DataIn     : STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL  Phy_DataOut    : STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL  Phy_Linestate  : STD_LOGIC_VECTOR(1 DOWNTO 0);
  SIGNAL  Phy_Opmode     : STD_LOGIC_VECTOR(1 DOWNTO 0);
  SIGNAL  Phy_RxActive   : STD_LOGIC;
  SIGNAL  Phy_RxError    : STD_LOGIC;
  SIGNAL  Phy_RxValid    : STD_LOGIC;
  SIGNAL  Phy_Termselect : STD_LOGIC := 'L';
  SIGNAL  Phy_TxReady    : STD_LOGIC;
  SIGNAL  Phy_TxValid    : STD_LOGIC;
  SIGNAL  Phy_XcvrSelect : STD_LOGIC := 'L';
  SIGNAL  usb_rst_phy    : STD_LOGIC;
  SIGNAL  usb_rst_slv    : STD_LOGIC;

  alias clk: std_logic is wb_clk_i;
  alias reset: std_logic is wb_rst_i;
  signal rstinv: std_logic;
  constant DriverMode: std_logic := '1';


BEGIN

  id <= x"08" & x"21";

  rstinv <= not reset;
  speed <= '1';
  
  usb_phy_1 : ENTITY work.usb_phy       --Open Cores USB Phy, designed by Rudolf Usselmanns
  GENERIC MAP (
    usb_rst_det      => TRUE,
    CLOCK => "96"
  )
  PORT MAP (
    clk              => clk,            -- i
    rst              => rstinv,         -- i
    phy_tx_mode      => DriverMode,     -- i
    usb_rst          => usb_rst_phy,    -- o
    txdp             => vpo,            -- o
    txdn             => vmo,            -- o
    txoe             => noe,            -- o
    rxd              => rcv,            -- i
    rxdp             => vp,             -- i
    rxdn             => vm,             -- i
    DataOut_i        => Phy_DataOut,    -- i (7 downto 0);
    TxValid_i        => Phy_TxValid,    -- i
    TxReady_o        => Phy_TxReady,    -- o
    DataIn_o         => Phy_DataIn,     -- o (7 downto 0);
    RxValid_o        => Phy_RxValid,    -- o
    RxActive_o       => Phy_RxActive,   -- o
    RxError_o        => Phy_RxError,    -- o
    LineState_o      => Phy_LineState   -- o (1 downto 0)
  );

  pe: block

	signal	pid_OUT:    std_logic;
  signal  pid_IN:     std_logic;
  signal  pid_SOF:    std_logic;
  signal  pid_SETUP:  std_logic;
	signal	pid_DATA0:  std_logic;
  signal  pid_DATA1:  std_logic;
  signal  pid_DATA2:  std_logic;
  signal  pid_MDATA:  std_logic;
	signal	pid_ACK:    std_logic;
  signal  pid_NACK:   std_logic;
  signal  pid_STALL:  std_logic;
  signal  pid_NYET:   std_logic;
	signal	pid_PRE:    std_logic;
  signal  pid_ERR:    std_logic;
  signal  pid_SPLIT:  std_logic;
  signal  pid_PING:   std_logic;
	signal	pid_cks_err:std_logic;

		-- Token Information
	signal	token_fadr: std_logic_vector(6 downto 0);
  signal  token_endp: std_logic_vector(3 downto 0);
  signal  token_valid:std_logic;
  signal  crc5_err:   std_logic;
	signal	frame_no:   std_logic_vector(10 downto 0);

		-- Receive Data Output
	signal	rx_data_st:    std_logic_vector(7 downto 0);
  signal  rx_data_valid:    std_logic;
  signal  rx_data_done:    std_logic;
  signal  crc16_err:     std_logic;

		-- Misc.
	signal	seq_err:    std_logic;
  signal  rx_busy:    std_logic;


  type pstatetype is (IDLE, READ, READ2, CRC1, CRC2, ACK, NACK, STALL, WRITE);

  type headertype is array(0 to 7) of std_logic_vector(7 downto 0);

  constant MAX_ENDPOINTS: natural := 4;

  --constant EPTYPE_CONTROL:    std_logic_vector(1 downto 0) := "00";
  --constant EPTYPE_BULK:       std_logic_vector(1 downto 0) := "01";
  --constant EPTYPE_INTERRUPT:  std_logic_vector(1 downto 0) := "10";
  --constant EPTYPE_ISOCHRONOUS:std_logic_vector(1 downto 0) := "11";

  constant EPTYPE_BULK_IN:        std_logic_vector(1 downto 0) := "00";
  constant EPTYPE_BULK_OUT:       std_logic_vector(1 downto 0) := "01";
  constant EPTYPE_INTERRUPT_IN:   std_logic_vector(1 downto 0) := "10";
  constant EPTYPE_INTERRUPT_OUT:  std_logic_vector(1 downto 0) := "11";

  
  type epc_type is record
    valid:  std_logic;
    eptype: std_logic_vector(1 downto 0);
    mbase:  std_logic_vector(10 downto 0);
    msize:  std_logic_vector(9 downto 0); -- Max endpoint size
    dsize:  std_logic_vector(9 downto 0); -- Current data size
    --dready: std_logic;
    hwcontrol:  std_logic;
    int_in:  std_logic;
    int_out: std_logic;
    seq:    std_logic;
  end record;

  type epc_list_type is array( 0 to MAX_ENDPOINTS-1) of epc_type;

  type epc_interrupt_flags is record
    int_in:   std_logic;
    int_out:  std_logic;
  end record;

  type epc_interrupts is array (0 to MAX_ENDPOINTS-1) of epc_interrupt_flags;

  type epc_array_stdlogic is array( 0 to MAX_ENDPOINTS-1) of std_logic;


  type pregstype is record
    state:  pstatetype;
    adr:    std_logic_vector(6 downto 0);
    endp:   std_logic_vector(3 downto 0);
    --hdr:    headertype;
    hcnt:   unsigned(2 downto 0);
    epc:    epc_list_type;
    epmem_addr:   std_logic_vector(10 downto 0);
    epmem_size:   unsigned(9 downto 0);
    dready: std_logic;
    validseq: std_logic;
    validwrite:std_logic;
    -- Interrupt registers
    int_ep: epc_interrupts;
    int_en: std_logic; -- Global interrupt enable
    ack: std_logic;
    softcon: std_logic;
    dato: std_logic_vector(31 downto 0);
  end record;

  signal r: pregstype;

  -- Interrupts
  signal ireadrequest: std_logic;

  type transaction_type is ( TSETUP, TIN, TOUT );

  signal epmem_en:    std_logic;
  signal epmem_we:    std_logic;
  signal epmem_addr:  std_logic_vector(10 downto 0);
  signal epmem_di:    std_logic_vector(7 downto 0);
  signal epmem_do:    std_logic_vector(7 downto 0);

  signal cpu_epmem_en:    std_logic;
  signal cpu_epmem_we:    std_logic;
  signal cpu_epmem_addr:  std_logic_vector(8 downto 0);
  signal cpu_epmem_di:    std_logic_vector(31 downto 0);
  signal cpu_epmem_do:    std_logic_vector(31 downto 0);

  signal cpu_clk:         std_ulogic;
  signal interrupt:       std_logic;

  function bswap(value: in std_logic_vector(31 downto 0)) return std_logic_vector is
    variable ret: std_logic_vector(31 downto 0);
  begin
    ret(7 downto 0)  := value(31 downto 24);
    ret(15 downto 8) := value(23 downto 16);
    ret(23 downto 16):= value(15 downto 8);
    ret(31 downto 24):= value(7 downto 0);
    return ret;
  end function;

  function inv(value: in std_logic_vector(7 downto 0)) return std_logic_vector is
    variable ret: std_logic_vector(7 downto 0);
  begin
    ret := value xor x"FF";
    return ret;
  end function;

  function reverse(value: in std_logic_vector) return std_logic_vector is
    variable ret: std_logic_vector(value'HIGH downto value'LOW);
  begin
    for i in value'LOW to value'HIGH loop
      ret(i) := value(value'HIGH-i);
    end loop;
    return ret;
  end function;

  signal crc_stb, crc_clr:  std_logic;
  signal txcrc, crc_out:  std_logic_vector(15 downto 0);

  begin

  softcon <= r.softcon;
  cpu_clk <= wb_clk_i;

  crcinst: entity work.usb1_crc16
    port map (
      crc_in  => txcrc,
      din     => reverse(epmem_do),
      crc_out => crc_out
  );
  process(clk)
  begin
    if rising_edge(clk) then
      if crc_clr='1' then
        txcrc <= x"FFFF";
      elsif crc_stb='1' then
        txcrc <= crc_out;
      end if;
    end if;
  end process;


  epmem: entity work.dp_ram_2k_8_32
  port map (
    clka    => clk,
    ena     => epmem_en,
    wea     => epmem_we,
    addra   => epmem_addr,
    dia     => epmem_di,
    doa     => epmem_do,

    clkb    => cpu_clk,
    enb     => cpu_epmem_en,
    web     => cpu_epmem_we,
    addrb   => cpu_epmem_addr,
    dib     => cpu_epmem_di,
    dob     => cpu_epmem_do
  );

  -- synopsys translate_off
  process(clk)
  begin
  if rising_edge(clk) then
    if epmem_we='1' and epmem_en='1' then
      report "Write 0x"&hstr(epmem_addr)&" value 0x"&hstr(epmem_di);
    end if;
  end if;
  end process;
  -- synopsys translate_on

  epmem_di <= rx_data_st;--Phy_DataIn;

  process(clk,r,token_endp,token_fadr,pid_SETUP,pid_IN,pid_OUT,Phy_TxReady,
    wb_stb_i, wb_we_i, wb_cyc_i, wb_dat_i, wb_adr_i, rx_data_valid, reset,
    cpu_epmem_do, token_valid,pid_ack,pid_data0,pid_data1,rx_data_done,epmem_do,
    txcrc)
    variable w: pregstype;

    function is_endpoint_valid( regs:   in pregstype;
                                ep:     in std_logic_vector(3 downto 0);
                                trans:  in transaction_type
                                ) return boolean is
      variable epindex: natural;
    begin
      epindex := conv_integer( unsigned(ep) );
      if epindex=0 then
        return true;
      end if;

      if (epindex<MAX_ENDPOINTS) then
        if (regs.epc( epindex ).valid='1') then
          case regs.epc( epindex ).eptype is
            when EPTYPE_BULK_IN | EPTYPE_INTERRUPT_IN =>
              return trans = TIN;
            when EPTYPE_BULK_OUT | EPTYPE_INTERRUPT_OUT =>
              return trans = TOUT;
            when others =>
              return false;
          end case;
        else
          return false;
        end if;
      else
        return false;
      end if;
    end function;

    variable epi: natural; -- Helper
    variable adr: std_logic_vector(8 downto 0);
  begin
    w:=r;

    ireadrequest<='0';
    Phy_DataOut <= (others => 'X');
    Phy_TxValid <= '0';

    epmem_en <= '0';
    epmem_we <= 'X';
    epmem_addr <= r.epmem_addr;
    crc_clr<='0';
    crc_stb<='0';

    case r.state is
      when IDLE =>
        if token_valid='1' then
          if pid_SETUP='1' or pid_IN='1' or pid_OUT='1' then
            w.adr := token_fadr;
            w.endp:= token_endp;
          end if;

          w.hcnt := (others => '0');

          if pid_SETUP='1' then
            -- TODO: skip non-control endpoints
            --w.state := SETUP;
            epi := conv_integer( unsigned(token_endp) );
            w.epc(epi).seq := '0';
            w.epmem_addr := r.epc(epi).mbase;
            w.epc(epi).dsize := (others => '0');
            w.state := WRITE;
            w.validwrite := '1'; -- Proper validation here please
            --w.setup := '1';

          elsif pid_IN='1' then
            if is_endpoint_valid( r, token_endp, TIN) then
              w.state := READ;
              crc_clr <= '1';
              w.dready :='0';
              epi := conv_integer( unsigned(token_endp) );

              w.epmem_addr := r.epc(epi).mbase;
              w.epmem_size := unsigned(r.epc(epi).dsize);


              if r.epc(epi).hwcontrol = '0' then
                w.state := NACK;
                -- Check interrupt control for this EP.
                --if r.epc(epi).int_in='1' and r.int_en='1' then
                --w.int_ep(epi).int_in:='1';
               -- if rising_edge(clk) then
               --   report "Interrupting ep " & str(epi);
               -- end if;
                --end if;
              end if;
            else
              w.epmem_addr := (others => 'X');
              w.epmem_size := (others => 'X');
              w.state := STALL; -- Invalid transfer
            end if;

          elsif pid_ACK='1' then
            epi := conv_integer( unsigned(r.endp) );
            w.epc(epi).seq := not r.epc(epi).seq;

          elsif pid_OUT='1' then

            if is_endpoint_valid( r, token_endp, TOUT) then
              w.validwrite := '1';
            else
              w.validwrite := '0';
            end if;

            epi := conv_integer( unsigned(token_endp) );
                
            w.epmem_addr := r.epc(epi).mbase;
            w.epc(epi).dsize := (others => '0');
            w.state := WRITE;
          end if;
        end if;

--      when SETUP =>
--        if rx_data_valid='1' then
--          w.hdr( conv_integer(r.hcnt) ) := rx_data_st;
--          w.hcnt := r.hcnt + 1;
--        end if;
--        if rx_data_done='1' then
--
--          if is_endpoint_valid( r, r.endp, TSETUP ) then
--            if r.hdr(0)(7)='1' then
--              ireadrequest<='1';
--            end if;
--            w.state := ACK;
--          else
--            w.state := IDLE; -- Ignore. USB20-8.4.6.4
--          end if;

--        end if;

      when WRITE =>
        epmem_en<='0';
        epmem_we<='1';
        epi := conv_integer( unsigned(r.endp) );
        w.validseq := '1';
        if rx_data_valid='1' then
          -- Check validity of request.
          if pid_DATA0='1' then
            epmem_en <=   not r.epc(epi).seq;
            w.validseq := not r.epc(epi).seq;
          elsif pid_DATA1='1' then
            epmem_en <=   r.epc(epi).seq;
            w.validseq := r.epc(epi).seq;
          else
            epmem_en <= '0';
          end if;

          w.epc(epi).dsize := r.epc(epi).dsize + 1;
          w.epmem_addr := r.epmem_addr + 1;

          --w.hdr( conv_integer(r.hcnt) ) := rx_data_st;
          --w.hcnt := r.hcnt + 1;
        end if;

        epmem_addr<=r.epmem_addr;

        if r.validwrite='0' then
          epmem_en<='0';
        end if;

        if r.epc(epi).hwcontrol='0' then
          epmem_en<='0';
        end if;

        if rx_data_done='1' then
          if r.validwrite='0' then
            w.state := STALL;
          else
          if r.epc(epi).dsize=0 then
            w.state:= ACK;
            w.epc(epi).seq := not r.epc(epi).seq;
          else
            if r.validseq='0' then
              w.state := ACK;
            else
              if r.epc(epi).hwcontrol='0' then
                w.state := NACK;
              else
                w.int_ep(epi).int_out:='1';
                w.epc(epi).hwcontrol:='0'; -- Set to SW control
                -- synopsys translate_off
                if rising_edge(clk) then report "Setting buffer control to SW after WRITE, ep "&str(epi); end if;
                -- synopsys translate_on
                w.epc(epi).seq := not r.epc(epi).seq;
                w.state := ACK;
              end if;
            end if;
            end if;
          end if;
        end if;

      when ACK =>
        Phy_TxValid <= '1';
        Phy_DataOut <= x"D2";
        if Phy_TxReady='1' then
          w.state := IDLE;
        end if;

      when STALL =>
        Phy_TxValid <= '1';
        Phy_DataOut <= "00011110";
        if Phy_TxReady='1' then
          w.state := IDLE;
        end if;

      when NACK =>
        Phy_TxValid <= '1';
        Phy_DataOut <= x"5A";
        if Phy_TxReady='1' then
          w.state := IDLE;
        end if;

      when READ =>
        epi := conv_integer( unsigned(r.endp) );
        Phy_TxValid <= r.dready;
        w.dready := '1';
        if r.epc(epi).seq='0' then
          Phy_DataOut<="11000011";
        else
          Phy_DataOut<="01001011";
        end if;
        epmem_en<=Phy_TxReady;
        epmem_we<='0';
        epmem_addr<=r.epmem_addr;

        if Phy_TxReady='1' then
          w.dready:='0';
          w.epmem_addr := r.epmem_addr + 1;
          w.epmem_size := r.epmem_size - 1;

          if r.epmem_size = 0 then
            w.state := CRC1;
            epi := conv_integer( unsigned(r.endp) );
            -- Release to software, we're done
            w.epc(epi).hwcontrol := '0';
            -- synopsys translate_off
            if rising_edge(clk) then report "Setting buffer control to SW after NULL READ, ep "&str(epi); end if;
            -- synopsys translate_on
            w.int_ep(epi).int_in:='1'; -- Notify SW

          else
            w.state := READ2;
          end if;

        end if;

      when READ2 =>
        epmem_we<='0';
        epmem_en<=Phy_TxReady;
        w.dready:='1';
        Phy_DataOut <= epmem_do;
        Phy_TxValid<='1';

        if Phy_TxReady='1' then
          crc_stb<='1';
          w.epmem_addr := r.epmem_addr + 1;
          w.epmem_size := r.epmem_size - 1;
          if r.epmem_size=0 then
            epi := conv_integer( unsigned(r.endp) );
            w.epc(epi).hwcontrol := '0';
            -- synopsys translate_off
            if rising_edge(clk) then report "Setting buffer control to SW after READ, ep "&str(epi); end if;
            -- synopsys translate_on
            w.int_ep(epi).int_in:='1'; -- Notify SW

            w.state := CRC1;
          end if;
        end if;

      when CRC1 =>
        Phy_DataOut <= reverse(inv(txcrc(15 downto 8)));
        Phy_TxValid<='1';
        if Phy_TxReady='1' then
          w.state := CRC2;
        end if;

      when CRC2 =>
        Phy_DataOut <= reverse(inv(txcrc(7 downto 0)));
        Phy_TxValid<='1';
        if Phy_TxReady='1' then
          w.state := IDLE;
        end if;

    end case;


    -- Wishbone access
    w.ack := '0';
    cpu_epmem_we <= wb_we_i;
    cpu_epmem_en <= '0';
    cpu_epmem_addr <= wb_adr_i(10 downto 2);
    cpu_epmem_di <= bswap(wb_dat_i);
    wb_dat_o <= (others => 'X');

    if wb_adr_i(11)='1' then
      wb_dat_o <= bswap(cpu_epmem_do);
    else
      wb_dat_o <= r.dato;
    end if;

    --w.dato :=(others => 'X');

    if wb_stb_i='1' and wb_cyc_i='1' and r.ack='0' then
      w.ack := '1';
      if wb_adr_i(11)='1' then
        cpu_epmem_en<='1';
        --wb_dat_o <= cpu_epmem_do;
      else
        --wb_dat_o <= r.dato;
        -- Register access
        if wb_we_i='1' then

          -- synopsys translate_off
          adr:= wb_adr_i(10 downto 2);
          if rising_edge(clk) then report "WB write address 0x"&hstr(adr)&" value "&hstr(wb_dat_i); end if;
          -- synopsys translate_on

          if wb_adr_i(7)='0' then
            case wb_adr_i(4 downto 2) is
              when "000" =>
                -- Config.
                w.softcon := wb_dat_i(0);
                w.int_en  := wb_dat_i(1);
              when "100" =>
                -- Interrupt status clear
                for i in 0 to MAX_ENDPOINTS-1 loop
                  if wb_dat_i((i*2))='1' then w.int_ep(i).int_in:='0'; end if;
                  if wb_dat_i((i*2)+1)='1' then w.int_ep(i).int_out:='0'; end if;
                end loop;
                -- synopsys translate_off
                if rising_edge(clk) then report "CPU clearing interrupts: "&str(wb_dat_i); end if;
                -- synopsys translate_on
              when others =>
            end case;
          else
            -- Endpoint configuration access
            epi := conv_integer( unsigned( wb_adr_i(6 downto 4) ) );
            case wb_adr_i(3 downto 2) is
              when "00" =>
                w.epc(epi).valid  :=  wb_dat_i(0);
                w.epc(epi).eptype := wb_dat_i(2 downto 1);
                -- One bit reserved for expansion
                w.epc(epi).hwcontrol := wb_dat_i(4);

                -- synopsys translate_off
                adr:= wb_adr_i(10 downto 2);
                if rising_edge(clk) then report "SW set "&str(wb_we_i)&"0x"&hstr(adr)&" buffer control to "&str(wb_dat_i(4)) &", ep "&str(epi); end if;
                -- synopsys translate_on
  
                w.epc(epi).int_in := wb_dat_i(5);
                w.epc(epi).int_out:= wb_dat_i(6);
                --w.epc(epi).seq    := wb_dat_i(7);
              when "01" =>
                w.epc(epi).mbase := wb_dat_i(10 downto 0);
              when "10" =>
                w.epc(epi).msize := wb_dat_i(9 downto 0);
              when "11" =>
                w.epc(epi).dsize := wb_dat_i(9 downto 0);
              when others =>
            end case;
          end if;
        end if; -- Writes

        -- synopsys translate_off
        adr:= wb_adr_i(10 downto 2);
        if rising_edge(clk) then report "WB read address 0x"&hstr(adr); end if;
        -- synopsys translate_on


        if wb_adr_i(7)='0' then
          case wb_adr_i(4 downto 2) is
            when "000" =>
              w.dato := (others => '0');
              w.dato(0) := r.softcon;
              w.dato(1) := r.int_en;
            when "001" =>
              -- Status register 1
              w.dato := (others => '0');
              w.dato(6 downto 0)  := r.adr;
              w.dato(10 downto 7) := r.endp;
              w.dato(13 downto 11) := std_logic_vector(r.hcnt);
            when "010" =>
              -- Status register 2
              w.dato := (others => '0');
  
            when "011" =>
              w.dato := (others => '0');
              -- Status register 3
            when "100" =>
              -- Interrupt status register
              w.dato := (others => '0');
              for i in 0 to MAX_ENDPOINTS-1 loop
                w.dato(i*2) :=  r.int_ep(i).int_in;
                w.dato((i*2)+1) := r.int_ep(i).int_out;
              end loop;
            when others =>
          end case;
        else
          -- Endpoint configuration.
          w.dato := (others => '0');
          epi := conv_integer( unsigned( wb_adr_i(6 downto 4) ) );
          case wb_adr_i(3 downto 2) is
            when "00" =>
              w.dato(0) := r.epc(epi).valid;
              w.dato(2 downto 1) := r.epc(epi).eptype;
              -- One bit reserved for expansion
              w.dato(4) := r.epc(epi).hwcontrol;
              w.dato(5) := r.epc(epi).int_in;
              w.dato(6) := r.epc(epi).int_out;
            when "01" =>
              w.dato(10 downto 0) := r.epc(epi).mbase;
            when "10" =>
              w.dato(9 downto 0) := r.epc(epi).msize;
            when "11" =>
              w.dato(9 downto 0) := r.epc(epi).dsize;
            when others =>
          end case;
        end if; -- EP/Conf select
      end if; -- Internal/Memory select
    end if; -- Wishbone access



    if reset='1' then
      w.state := IDLE;
      w.int_en:='0';
      w.ack := '0';
      w.softcon := '0';
      clearep: for i in 0 to MAX_ENDPOINTS-1 loop
        w.epc(i).valid:='0';
        w.epc(i).hwcontrol:='0';
        w.epc(i).seq:='0';
        w.int_ep(i).int_in:='0';
        w.int_ep(i).int_out:='0';
      end loop;
    end if;  -- Reset

    if rising_edge(clk) then
      r<=w;
    end if;
  end process;

  wb_ack_o<=r.ack;

  process(r)
    variable is_int: std_logic;
  begin
    -- Interrupts
    is_int := '0';
    for epi in 0 to MAX_ENDPOINTS-1 loop
      if r.epc(epi).int_in='1' and r.int_ep(epi).int_in='1' then
        is_int := '1';
      end if;
      if r.epc(epi).int_out='1' and r.int_ep(epi).int_out='1' then
        is_int := '1';
      end if;
    end loop;
    if r.int_en='0' then
      is_int := '0';
    end if;
    interrupt <= is_int;
  end process;

  wb_inta_o <= interrupt;
  -- synopsys translate_off
  d: block
    signal intq: std_logic;
  begin
    process(clk)
    begin
  if rising_edge(clk) then
      intq<=interrupt;
      if interrupt/=intq then
        report "Setting int line to "&str(interrupt);
      end if;
    end if;
   end process;
  end block;
  -- synopsys translate_on



  pd: entity work.usb1_pd
  port map (
    clk => clk,
    rst => rstinv,
    rx_data   => Phy_DataIn,
    rx_valid  => Phy_RxValid,
    rx_active => Phy_RxActive,
    rx_err    => Phy_RxError,

  		-- PID Information
		pid_OUT   => pid_OUT,
    pid_IN    => pid_IN,
    pid_SOF   => pid_SOF,
    pid_SETUP => pid_SETUP,
		pid_DATA0 => pid_DATA0,
    pid_DATA1 => pid_DATA1,
    pid_DATA2 => pid_DATA2,
    pid_MDATA => pid_MDATA,
		pid_ACK   => pid_ACK,
    pid_NACK  => pid_NACK,
    pid_STALL => pid_STALL,
    pid_NYET  => pid_NYET,
		pid_PRE   => pid_PRE,
    pid_ERR   => pid_ERR,
    pid_SPLIT => pid_SPLIT,
    pid_PING  => pid_PING,
		pid_cks_err => pid_cks_err,

		-- Token Information
		token_fadr  => token_fadr,
    token_endp  => token_endp,
    token_valid => token_valid,
    crc5_err    => crc5_err,
		frame_no    => frame_no,

		-- Receive Data Output
		rx_data_st  => rx_data_st,
    rx_data_valid => rx_data_valid,
    rx_data_done  => rx_data_done,
    crc16_err     => crc16_err,

		-- Misc.
		seq_err       => seq_err,
    rx_busy       => rx_busy
  );

  end block;

END rtl;

