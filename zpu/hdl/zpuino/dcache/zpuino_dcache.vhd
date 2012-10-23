library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.all;

use ieee.numeric_std.all;

library work;
use work.zpu_config.all;
use work.zpupkg.all;
use work.zpuinopkg.all;
use work.wishbonepkg.all;
use work.txt_util.all;

entity zpuino_dcache is
  generic (
      ADDRESS_HIGH: integer := 26;
      CACHE_MAX_BITS: integer := 13; -- 8 Kb
      CACHE_LINE_SIZE_BITS: integer := 6 -- 64 bytes
  );
  port (
    wb_clk_i:       in std_logic;
    wb_rst_i:       in std_logic;
    -- Port A (read-only)
    a_valid:          out std_logic;
    a_data_out:       out std_logic_vector(wordSize-1 downto 0);
    a_address:        in std_logic_vector(ADDRESS_HIGH-1 downto 2);
    a_strobe:         in std_logic;
    a_enable:         in std_logic;
    a_stall:          out std_logic;

    -- Port B (read-write)
    b_valid:          out std_logic;
    b_data_out:       out std_logic_vector(wordSize-1 downto 0);
    b_data_in:        in std_logic_vector(wordSize-1 downto 0);
    b_address:        in std_logic_vector(ADDRESS_HIGH-1 downto 2);
    b_strobe:         in std_logic;
    b_we:             in std_logic;
    b_wmask:          in std_logic_vector(3 downto 0);
    b_enable:         in std_logic;
    b_stall:          out std_logic;

    flush:          in std_logic;
    -- Master wishbone interface

    m_wb_ack_i:       in std_logic;
    m_wb_dat_i:       in std_logic_vector(wordSize-1 downto 0);
    m_wb_dat_o:       out std_logic_vector(wordSize-1 downto 0);
    m_wb_adr_o:       out std_logic_vector(maxAddrBit downto 0);
    m_wb_cyc_o:       out std_logic;
    m_wb_stb_o:       out std_logic;
    m_wb_stall_i:     in std_logic;
    m_wb_we_o:        out std_logic
  );
end zpuino_dcache;

architecture behave of zpuino_dcache is
  
  constant CACHE_LINE_ID_BITS: integer := CACHE_MAX_BITS-CACHE_LINE_SIZE_BITS;

  subtype address_type is std_logic_vector(ADDRESS_HIGH-1 downto 2);
  -- A line descriptor
  subtype line_number_type is std_logic_vector(CACHE_LINE_ID_BITS-1 downto 0);
  -- Offset within a line
  subtype line_offset_type is std_logic_vector(CACHE_LINE_SIZE_BITS-1-2 downto 0);
  -- A tag descriptor
  subtype tag_type is std_logic_vector((ADDRESS_HIGH-CACHE_MAX_BITS)-1 downto 0);
  -- A full tag memory descriptor. Includes valid bit and dirty bit
  subtype full_tag_type is std_logic_vector(ADDRESS_HIGH-CACHE_MAX_BITS+1 downto 0);

  constant VALID: integer := ADDRESS_HIGH-CACHE_MAX_BITS;
  constant DIRTY: integer := ADDRESS_HIGH-CACHE_MAX_BITS+1;
  ------------------------------------------------------------------------------

  type state_type is (
    idle,
    readline,
    writeback,
    write_after_fill,
    settle
  );

  type regs_type is record
    a_req:      std_logic;
    b_req:      std_logic;
    a_req_addr: address_type;
    b_req_addr: address_type;
    b_req_we:   std_logic;
    b_req_data:   std_logic_vector(wordSize-1 downto 0);
    fill_offset_r:    line_offset_type;
    fill_offset_w:    line_offset_type;
    fill_tag:         tag_type;
    fill_line_number: line_number_type;
    fill_r_done:      std_logic;
    fill_is_b:        std_logic;
    ack_b_write:      std_logic;
    state:      state_type;
  end record;

  function address_to_tag(a: in address_type) return tag_type is
  begin
    return a(ADDRESS_HIGH-1 downto CACHE_MAX_BITS);
  end address_to_tag;

  function address_to_line_number(a: in address_type) return line_number_type is
  begin
    return a(CACHE_MAX_BITS-1 downto CACHE_LINE_SIZE_BITS);
  end address_to_line_number;

  function address_to_line_offset(a: in address_type) return line_offset_type is
  begin
    return a(CACHE_LINE_SIZE_BITS-1 downto 2);
  end address_to_line_offset;

  ------------------------------------------------------------------------------


  -- extracted values from port A
  signal a_line_number:   line_number_type;
  signal a_line_offset:   line_offset_type;
  signal a_tag:           tag_type;

  -- extracted values from port B
  signal b_line_number:   line_number_type;
  signal b_line_offset:   line_offset_type;
  signal b_tag:           tag_type;

  -- Some helpers
  signal a_hit: std_logic;
  signal a_miss: std_logic;
  signal b_hit: std_logic;
  signal b_miss: std_logic;
  signal a_b_conflict: std_logic;
  
  -- Connection to tag memory

  signal tmem_ena:    std_logic;
  signal tmem_wea:    std_logic;
  signal tmem_addra:  line_number_type;
  signal tmem_dia:    full_tag_type;
  signal tmem_doa:    full_tag_type;
  signal tmem_enb:    std_logic;
  signal tmem_web:    std_logic;
  signal tmem_addrb:  line_number_type;
  signal tmem_dib:    full_tag_type;
  signal tmem_dob:    full_tag_type;

  signal cmem_ena:    std_logic;
  signal cmem_wea:    std_logic;
  signal cmem_dia:    std_logic_vector(wordSize-1 downto 0);
  signal cmem_doa:    std_logic_vector(wordSize-1 downto 0);
  signal cmem_addra:  std_logic_vector(ADDRESS_HIGH-1 downto 2);

  signal cmem_enb:    std_logic;
  signal cmem_web:    std_logic;
  signal cmem_dib:    std_logic_vector(wordSize-1 downto 0);
  signal cmem_dob:    std_logic_vector(wordSize-1 downto 0);
  signal cmem_addrb:  std_logic_vector(ADDRESS_HIGH-1 downto 2);


  signal r: regs_type;
  signal a_will_busy, b_will_busy: std_logic;

  constant offset_all_ones: line_offset_type := (others => '1');

begin

  -- These are alias, but written as signals so we can inspect them

  a_tag         <= address_to_tag(a_address);
  a_line_number <= address_to_line_number(a_address);
  a_line_offset <= address_to_line_offset(a_address);

  b_tag         <= address_to_tag(b_address);
  b_line_number <= address_to_line_number(b_address);
  b_line_offset <= address_to_line_offset(b_address);

  -- TAG memory

  tagmem: generic_dp_ram
  generic map (
    address_bits  => CACHE_LINE_ID_BITS,
    data_bits     => ADDRESS_HIGH-CACHE_MAX_BITS+2
  )
  port map (
    clka      => wb_clk_i,
    ena       => tmem_ena,
    wea       => tmem_wea,
    addra     => tmem_addra,
    dia       => tmem_dia,
    doa       => tmem_doa,

    clkb      => wb_clk_i,
    enb       => tmem_enb,
    web       => tmem_web,
    addrb     => tmem_addrb,
    dib       => tmem_dib,
    dob       => tmem_dob
  );

  -- Cache memory

  cachemem: generic_dp_ram
  generic map (
    address_bits => cmem_addra'LENGTH,
    data_bits => 32
  )
  port map (
    clka      => wb_clk_i,
    ena       => cmem_ena,
    wea       => cmem_wea,
    addra     => cmem_addra,
    dia       => cmem_dia,
    doa       => cmem_doa,

    clkb      => wb_clk_i,
    enb       => cmem_enb,
    web       => cmem_web,
    addrb     => cmem_addrb,
    dib       => cmem_dib,
    dob       => cmem_dob
  );

  

  process(r,wb_clk_i,wb_rst_i, a_strobe, b_strobe, a_address, b_address, tmem_doa, m_wb_ack_i, m_wb_dat_i, m_wb_stall_i,a_miss,b_miss,
          tmem_doa, tmem_dob, a_line_number, b_line_number, a_tag, b_tag, a_will_busy,
          b_will_busy)
    variable w: regs_type;
  begin
    w := r;
    a_valid<='0';
    b_valid<='0';
    a_stall<='0';
    b_stall<='0';
    a_hit <='0';
    a_miss <='0';
    b_hit <='0';
    b_miss <='0';
    a_will_busy <= '0';
    b_will_busy <= '0';

    a_b_conflict <='0';
    m_wb_cyc_o <= '0';
    m_wb_stb_o <= DontCareValue;
    m_wb_adr_o <= (others => DontCareValue);
    m_wb_dat_o <= (others => DontCareValue);
    m_wb_we_o <= DontCareValue;

    tmem_addra <= a_line_number;
    tmem_addrb <= b_line_number;
    tmem_ena <= '1';
    tmem_wea <= '0';
    tmem_enb <= '1';
    tmem_web <= '0';


    cmem_addra <= a_address(ADDRESS_HIGH-1 downto 2);
    cmem_addrb <= b_address(ADDRESS_HIGH-1 downto 2);
    cmem_ena <= a_strobe;
    cmem_wea <= '0';
    cmem_web <= '0';
    cmem_enb <= b_strobe;
    cmem_dia <= (others => DontCareValue); -- No writes on port A
    cmem_dib <= (others => DontCareValue);

    a_data_out <= cmem_doa;
    b_data_out <= cmem_dob;

    w.ack_b_write := '0';

    case r.state is
      when idle =>

        if a_will_busy='0' then
          w.a_req := a_strobe;
          if a_strobe='1' then
            w.a_req_addr := a_address(address_type'RANGE);
          end if;
        end if;

        if b_will_busy='0' then
          w.b_req := b_strobe;
          if b_strobe='1' then
            w.b_req_addr := b_address(address_type'RANGE);
            w.b_req_we := b_we;
            w.b_req_data := b_data_in;
          end if;
        end if;

        -- Now, after reading from tag memory....
        if (r.a_req='1') then
          -- We had a request, check
          a_miss<='1';
          if tmem_doa(VALID)='1' then
            if tmem_doa(tag_type'RANGE) = address_to_tag(r.a_req_addr) then
              a_hit<='1';
              a_miss<='0';
            end if;
          end if;
        else
          a_miss<='0';
        end if;

        if (r.b_req='1') then
          -- We had a request, check
          b_miss<='1';
          if tmem_dob(VALID)='1' then
            if tmem_dob(tag_type'RANGE) = address_to_tag(r.b_req_addr) then
              b_hit<='1';
              b_miss<='0';
            end if;
          end if;
        else
          b_miss<='0';
        end if;

        -- Conflict
        if (r.a_req='1' and r.b_req='1') then
          -- We have a conflict if we're accessing the same line, but however
          -- the tags mismatch

          if address_to_line_number(r.a_req_addr) = address_to_line_number(r.b_req_addr) and
            --tmem_dob(tag_type'RANGE) /= tmem_doa(tag_type'RANGE) then
            address_to_tag(r.a_req_addr) /= address_to_tag(r.b_req_addr) then

            report "Conflict" & hstr(tmem_dob) severity failure;
          end if;                               
        end if;

        -- Miss handling
        if r.a_req='1' then
        if a_miss='1' then
          a_stall <= '1';
          --b_stall <= '1';
          a_valid <= '0';
          --b_valid <= '0';

          w.fill_tag := address_to_tag(r.a_req_addr);
          w.fill_line_number := address_to_line_number(r.a_req_addr);
          w.fill_offset_r := (others => '0');
          w.fill_offset_w := (others => '0');
          w.fill_r_done := '0';
          w.fill_is_b := '0';

          if tmem_doa(VALID)='1' then
            if tmem_doa(DIRTY)='1' then
              w.state := writeback;
              a_will_busy<='1';
            else
              w.state := readline;
              a_will_busy<='1';
            end if;
          else
            w.state := readline;
            a_will_busy<='1';
          end if;
        else
          a_valid <= '1';
        end if;
        end if;



        -- Miss handling (B)
        if r.b_req='1' then
        if b_miss='1' and a_miss='0' then
          b_stall <= '1';
          --a_stall <= '1';
          b_valid <= '0';
          b_will_busy<='1';
          --a_valid <= '0';

          w.fill_tag := address_to_tag(r.b_req_addr);
          w.fill_line_number := address_to_line_number(r.b_req_addr);
          w.fill_offset_r := (others => '0');
          w.fill_offset_w := (others => '0');
          w.fill_r_done := '0';
          w.fill_is_b := '1';

          if tmem_dob(VALID)='1' then
            if tmem_dob(DIRTY)='1' then
              w.state := writeback;
            else
              w.state := readline;
            end if;
          else
            w.state := readline;
          end if;
        else
          if a_miss='0' and b_miss='0' then


            -- Process writes, line is in cache
            if r.b_req_we='1' then
              b_stall <= '1'; -- Stall everything.
              --b_will_busy <= '1';

              -- Now, we need to re-write tag so to set dirty to '1'
              tmem_addrb <= address_to_line_number(r.b_req_addr);
              tmem_dib(tag_type'RANGE) <=address_to_tag(r.b_req_addr);
              tmem_dib(VALID)<='1';
              tmem_dib(DIRTY)<='1';
              tmem_web<='1';
              tmem_enb<='1';

              cmem_addrb <= r.b_req_addr;
              cmem_dib <= r.b_req_data;
              cmem_web <= '1';
              cmem_enb <= '1';

              w.ack_b_write:='1';
              w.state := settle;

            else
              b_valid <= '1';
            end if;
          else
            b_will_busy<='1';
            b_stall <= '1';
          end if;
        end if;
        end if;


      when readline =>
        a_stall <= '1';
        b_stall <= '1';

        m_wb_adr_o<=(others => '0');
        m_wb_adr_o(ADDRESS_HIGH-1 downto 2) <= r.fill_tag & r.fill_line_number & r.fill_offset_r;
        m_wb_cyc_o<='1';
        m_wb_stb_o<=not r.fill_r_done;
        m_wb_we_o<='0';

        if r.fill_is_b='1' then
          cmem_addrb <= r.fill_tag & r.fill_line_number & r.fill_offset_w;
          cmem_enb <= '1';
          cmem_ena <= '0';
          cmem_web <= m_wb_ack_i;
          cmem_dib <= m_wb_dat_i;
        else
          cmem_addra <= r.fill_tag & r.fill_line_number & r.fill_offset_w;
          cmem_ena <= '1';
          cmem_enb <= '0';
          cmem_wea <= m_wb_ack_i;
          cmem_dia <= m_wb_dat_i;
        end if;

        if m_wb_stall_i='0' and r.fill_r_done='0' then
          w.fill_offset_r := std_logic_vector(unsigned(r.fill_offset_r) + 1);
          if r.fill_offset_r = offset_all_ones then
            w.fill_r_done := '1';
          end if;
        end if;

        if m_wb_ack_i='1' then
          w.fill_offset_w := std_logic_vector(unsigned(r.fill_offset_w) + 1);
          if r.fill_offset_w=offset_all_ones then
            w.state := settle;
            if r.fill_is_b='1' then
              tmem_addrb <= r.fill_line_number;
              tmem_dib(tag_type'RANGE) <= r.fill_tag;
              tmem_dib(VALID)<='1';
              tmem_dib(DIRTY)<=r.b_req_we;
              tmem_web<='1';
              tmem_enb<='1';
              if r.b_req_we='1' then
                -- Perform write
                w.state := write_after_fill;
              end if;
            else
              tmem_addra <= r.fill_line_number;
              tmem_dia(tag_type'RANGE) <= r.fill_tag;
              tmem_dia(VALID)<='1';
              tmem_dia(DIRTY)<='0';
              tmem_wea<='1';
              tmem_ena<='1';
            end if;
          end if;
        end if;


      when writeback =>
        report "unimplemented" severity failure;

      when write_after_fill =>
        cmem_addra <= r.a_req_addr;
        cmem_addrb <= r.b_req_addr;
        cmem_dib <= r.b_req_data;
        cmem_web  <= r.b_req_we;
        cmem_enb <= '1';

        a_stall <= '1';
        b_stall <= '1';
        a_valid <= '0'; -- ERROR
        b_valid <= '0'; -- ERROR
        w.ack_b_write := '1';
        w.state := settle;

      when settle =>
        cmem_addra <= r.a_req_addr;--r.fill_tag & r.fill_line_number & r.fill_offset_w;
        cmem_addrb <= r.b_req_addr;--r.fill_tag & r.fill_line_number & r.fill_offset_w;
        tmem_addra <= address_to_line_number(r.a_req_addr);
        tmem_addrb <= address_to_line_number(r.b_req_addr);
        a_stall <= '1';
        b_stall <= not r.ack_b_write;--'1';
        a_valid <= '0'; -- ERROR
        b_valid <= r.ack_b_write; -- ERROR
        w.state := idle;

    end case;

    if rising_edge(wb_clk_i) then
      if wb_rst_i='1' then
        r.state <= idle;
        r.a_req <= '0';
        r.b_req <= '0';
      else
        r <= w;
      end if;
    end if;

  end process;


end behave;
