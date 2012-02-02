library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library work;
use work.zpu_config.all;
use work.zpuino_config.all;
use work.zpupkg.all;
use work.zpuinopkg.all;

entity vga_text is
  port(
    wb_clk_i: in std_logic;
	 	wb_rst_i: in std_logic;
    wb_dat_o: out std_logic_vector(wordSize-1 downto 0);
    wb_dat_i: in std_logic_vector(wordSize-1 downto 0);
    wb_adr_i: in std_logic_vector(maxIObit downto minIObit);
    wb_we_i:  in std_logic;
    wb_cyc_i: in std_logic;
    wb_stb_i: in std_logic;
    wb_ack_o: out std_logic;

    -- Wishbone MASTER interface
    mi_wb_dat_i: in std_logic_vector(wordSize-1 downto 0);
    mi_wb_dat_o: out std_logic_vector(wordSize-1 downto 0);
    mi_wb_adr_o: out std_logic_vector(maxAddrBit downto 0);
    mi_wb_sel_o: out std_logic_vector(3 downto 0);
    mi_wb_cti_o: out std_logic_vector(2 downto 0);
    mi_wb_we_o:  out std_logic;
    mi_wb_cyc_o: out std_logic;
    mi_wb_stb_o: out std_logic;
    mi_wb_ack_i: in std_logic;

    -- Char RAM interface
    wb_char_ram_dat_i: in std_logic_vector(7 downto 0);
    wb_char_ram_adr_o: out std_logic_vector(7 downto 0);
    wb_char_ram_cyc_o: out std_logic;
    wb_char_ram_stb_o: out std_logic;
    wb_char_ram_ack_i: in std_logic
  );
end entity;

architecture behave of vga_text is

  component gh_fifo_async_rrd_sr_wf is
	GENERIC (add_width: INTEGER :=8; -- min value is 2 (4 memory locations)
	         data_width: INTEGER :=8 ); -- size of data bus
	port (					
		clk_WR  : in STD_LOGIC; -- write clock
		clk_RD  : in STD_LOGIC; -- read clock
		rst     : in STD_LOGIC; -- resets counters
		srst    : in STD_LOGIC:='0'; -- resets counters (sync with clk_WR)
		WR      : in STD_LOGIC; -- write control 
		RD      : in STD_LOGIC; -- read control
		D       : in STD_LOGIC_VECTOR (data_width-1 downto 0);
		Q       : out STD_LOGIC_VECTOR (data_width-1 downto 0);
		empty   : out STD_LOGIC;
		qfull   : out STD_LOGIC;
		hfull   : out STD_LOGIC;
		qqqfull : out STD_LOGIC;
    afull   : out STD_LOGIC;
		full    : out STD_LOGIC);
  end component;

  component wb_char_ram_8x8 is
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
    wb_inta_o:out std_logic
  );
  end component wb_char_ram_8x8;

  signal fifo_full: std_logic;
  signal fifo_almost_full: std_logic;
  signal fifo_write_enable: std_logic;
  signal fifo_quad_full: std_logic;
  signal fifo_half_full: std_logic;

  signal readclk: std_logic:='0';
  signal fifo_clear: std_logic:='0';
  signal read_enable: std_logic:='0';
  signal fifo_write, read: std_logic_vector(2 downto 0);
  signal fifo_empty: std_logic;


  signal char_wb_dat_o: std_logic_vector(wordSize-1 downto 0);
  signal char_wb_dat_i: std_logic_vector(wordSize-1 downto 0);
  signal char_wb_adr_i: std_logic_vector(maxIObit downto minIObit);
  signal char_wb_cyc_i: std_logic;
  signal char_wb_stb_i: std_logic;
  signal char_wb_ack_o: std_logic;


  signal membase:       std_logic_vector(wordSize-1 downto 0) := (others => '0');
  signal palletebase:   std_logic_vector(wordSize-1 downto 0) := (others => '0');

  signal memptr:        std_logic_vector(wordSize-1 downto 0);
  signal palleteptr:    std_logic_vector(wordSize-1 downto 0);

  type state_type is (
    fetch_char,
    fetch_pallete,
    load_char,
    fill,
    sleep
  );

  type vgaregs_type is record

    state:    state_type;
    chars:    std_logic_vector(wordSize-1 downto 0);
    pallete:  std_logic_vector(wordSize-1 downto 0);

    charline: std_logic_vector(7 downto 0); -- The 8 pixels of a char row
    charpal:  std_logic_vector(7 downto 0); -- Pallete for this char

    charoff:  unsigned(1 downto 0);
    palloff:  unsigned(1 downto 0);
    hptr:     integer range 0 to 79;
  
    hoff:     unsigned(2 downto 0); -- Offset (column) of current char

  end record;

  signal r: vgaregs_type;

begin

  process(wb_clk_i, wb_rst_i, r, mi_wb_ack_i, mi_wb_dat_i, memptr,palleteptr)
    variable w: vgaregs_type;

    variable current_char: std_logic_vector(7 downto 0);
    variable current_pallete: std_logic_vector(7 downto 0);

    variable vdisp_char:  std_logic_vector(2 downto 0); -- Vertical offset in char (0 to 7)

    variable pixel: std_logic_vector(2 downto 0);

  begin
    mi_wb_stb_o <= '0';
    mi_wb_cyc_o <= '0';
    mi_wb_we_o <= '0';
    mi_wb_adr_o <= (others => '0');
    fifo_write_enable<='0';
    
    if wb_rst_i='1' then
      w.state := sleep;
      w.palloff := (others => '0');
      fifo_clear <='1';
      w.hptr := 0;
      w.hoff := (others =>'0');
    else
      fifo_clear<='0';
      case r.state is
        when fetch_char =>

          mi_wb_stb_o <= '1';
          mi_wb_cyc_o <= '1';
          mi_wb_adr_o <= memptr(maxAddrBit+2 downto 2);

          w.charoff := (others => '0');
          w.chars := mi_wb_dat_i;

          if mi_wb_ack_i='1' then
            w.state := load_char;
          end if;

        when fetch_pallete =>

          mi_wb_stb_o <= '1';
          mi_wb_cyc_o <= '1';
          mi_wb_adr_o <= palleteptr(maxAddrBit+2 downto 2);
          w.pallete := mi_wb_dat_i;

          if mi_wb_ack_i='1' then
            w.state := fetch_char;

          end if;

        when load_char =>

          case r.charoff is
            when "00" => current_char := r.chars(7 downto 0);
            when "01" => current_char := r.chars(15 downto 8);
            when "10" => current_char := r.chars(23 downto 16);
            when "11" => current_char := r.chars(31 downto 24);
            when others =>
          end case;

          case r.palloff is
            when "00" => current_pallete := r.pallete(7 downto 0);
            when "01" => current_pallete := r.pallete(15 downto 8);
            when "10" => current_pallete := r.pallete(23 downto 16);
            when "11" => current_pallete := r.pallete(31 downto 24);
            when others =>
          end case;

          char_wb_cyc_i<='1';
          char_wb_stb_i<='1';
          char_wb_adr_i(12 downto 5) <= current_char;
          char_wb_adr_i(4 downto 2) <= vdisp_char;

          w.charpal := current_pallete;
          w.charline := char_wb_dat_o(7 downto 0); -- No need for ack_i
          w.hoff := (others => '0');

          if char_wb_ack_o='1' then
            w.state := fill;
          end if;

        when fill =>

          -- Choose color

          case r.charline(to_integer(r.hoff)) is
            when '0' =>
              pixel := r.charpal(2 downto 0);
            when '1' =>
              pixel := r.charpal(6 downto 4);
            when others =>
          end case;


          if fifo_almost_full='0' then
            fifo_write_enable<='1';
            w.hoff := r.hoff + 1;
            if r.hoff="111" then
              -- Finished a single row.
              w.palloff := r.palloff + 1;
              w.charoff := r.charoff + 1;
              if r.charoff="11" then
                -- Increase pointer
                w.state := fetch_char;
              elsif r.palloff="11" then
                -- Increase pointer
                w.state := fetch_pallete;
              else
                w.state := load_char;
              end if;
            end if;
          end if;



        when sleep =>
          w.state := fetch_pallete;
        when others =>
      end case;

    end if;

    fifo_write <= pixel;



    if rising_edge(wb_clk_i) then
      r <= w;
    end if;
   end process;





  read_enable <='0';





  myfifo: gh_fifo_async_rrd_sr_wf
  generic map (
    data_width => 3,
    add_width => 6
  )
  port map (
		clk_WR  => wb_clk_i,
		clk_RD  => wb_clk_i,
		rst     => '0',
		srst    => fifo_clear,
		WR      => fifo_write_enable,
		RD      => read_enable,
		D       => fifo_write,
		Q       => read,
		empty   => fifo_empty,
		qfull   => fifo_quad_full,
		hfull   => fifo_half_full,
		qqqfull => fifo_almost_full,
		full    => fifo_full
  );


  charram: wb_char_ram_8x8
  port map (
    wb_clk_i    => wb_clk_i,
	 	wb_rst_i    => wb_rst_i,
    wb_dat_o    => char_wb_dat_o,
    wb_dat_i    => char_wb_dat_i,
    wb_adr_i    => char_wb_adr_i,
    wb_we_i     => '0',
    wb_cyc_i    => char_wb_cyc_i,
    wb_stb_i    => char_wb_stb_i,
    wb_ack_o    => char_wb_ack_o,
    wb_inta_o   => open
  );


end behave;
