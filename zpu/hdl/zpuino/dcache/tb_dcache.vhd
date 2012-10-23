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

entity tb_dcache is
end entity;

architecture sim of tb_dcache is

  constant ADDRESS_HIGH: integer := 26;

  component sdram_ctrl is
  port (
    wb_clk_i: in std_logic;
	 	wb_rst_i: in std_logic;

    wb_dat_o: out std_logic_vector(31 downto 0);
    wb_dat_i: in std_logic_vector(31 downto 0);
    wb_adr_i: in std_logic_vector(maxIOBit downto minIOBit);
    wb_we_i:  in std_logic;
    wb_cyc_i: in std_logic;
    wb_stb_i: in std_logic;
    wb_sel_i: in std_logic_vector(3 downto 0);
    wb_ack_o: out std_logic;
    wb_stall_o: out std_logic;

    -- extra clocking
    clk_off_3ns: in std_logic;

    -- SDRAM signals
     DRAM_ADDR   : OUT   STD_LOGIC_VECTOR (11 downto 0);
     DRAM_BA      : OUT   STD_LOGIC_VECTOR (1 downto 0);
     DRAM_CAS_N   : OUT   STD_LOGIC;
     DRAM_CKE      : OUT   STD_LOGIC;
     DRAM_CLK      : OUT   STD_LOGIC;
     DRAM_CS_N   : OUT   STD_LOGIC;
     DRAM_DQ      : INOUT STD_LOGIC_VECTOR(15 downto 0);
     DRAM_DQM      : OUT   STD_LOGIC_VECTOR(1 downto 0);
     DRAM_RAS_N   : OUT   STD_LOGIC;
     DRAM_WE_N    : OUT   STD_LOGIC
  
  );
  end component;






  component  zpuino_dcache is
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
  end component;

    -- SDRAM signals
     signal DRAM_ADDR   :    STD_LOGIC_VECTOR (12 downto 0);
     signal DRAM_BA      :   STD_LOGIC_VECTOR (1 downto 0);
     signal DRAM_CAS_N   :    STD_LOGIC;
     signal DRAM_CKE      :    STD_LOGIC;
     signal DRAM_CLK      :   STD_LOGIC;
     signal DRAM_CS_N   :    STD_LOGIC;
     signal DRAM_DQ      :  STD_LOGIC_VECTOR(15 downto 0);
     signal DRAM_DQM      :   STD_LOGIC_VECTOR(1 downto 0);
     signal DRAM_RAS_N   :   STD_LOGIC;
     signal DRAM_WE_N    :   STD_LOGIC;

  component mt48lc16m16a2 IS
    GENERIC (
        -- Timing Parameters for -7E (PC133) and CAS Latency = 3
        tAC       : TIME    :=  5.4 ns;
        tHZ       : TIME    :=  7.0 ns;
        tOH       : TIME    :=  2.7 ns;
        tMRD      : INTEGER :=  2;          -- 2 Clk Cycles
        tRAS      : TIME    := 44.0 ns;
        tRC       : TIME    := 66.0 ns;
        tRCD      : TIME    := 20.0 ns;
        tRP       : TIME    := 20.0 ns;
        tRRD      : TIME    := 15.0 ns;
        tWRa      : TIME    :=  7.5 ns;     -- A2 Version - Auto precharge mode only (1 Clk + 7.5 ns)
        tWRp      : TIME    := 15.0 ns;     -- A2 Version - Precharge mode only (15 ns)

        tAH       : TIME    :=  0.8 ns;
        tAS       : TIME    :=  1.5 ns;
        tCH       : TIME    :=  2.5 ns;
        tCL       : TIME    :=  2.5 ns;
        tCK       : TIME    :=  7.0 ns;
        tDH       : TIME    :=  0.8 ns;
        tDS       : TIME    :=  1.5 ns;
        tCKH      : TIME    :=  0.8 ns;
        tCKS      : TIME    :=  1.5 ns;
        tCMH      : TIME    :=  0.8 ns;
        tCMS      : TIME    :=  1.5 ns;

        addr_bits : INTEGER := 13;
        data_bits : INTEGER := 16;
        col_bits  : INTEGER :=  9;
        index     : INTEGER :=  0;
	fname     : string := "sdram.srec"	-- File to read from
    );
    PORT (
        Dq    : INOUT STD_LOGIC_VECTOR (data_bits - 1 DOWNTO 0) := (OTHERS => 'Z');
        Addr  : IN    STD_LOGIC_VECTOR (addr_bits - 1 DOWNTO 0) := (OTHERS => '0');
        Ba    : IN    STD_LOGIC_VECTOR := "00";
        Clk   : IN    STD_LOGIC := '0';
        Cke   : IN    STD_LOGIC := '1';
        Cs_n  : IN    STD_LOGIC := '1';
        Ras_n : IN    STD_LOGIC := '1';
        Cas_n : IN    STD_LOGIC := '1';
        We_n  : IN    STD_LOGIC := '1';
        Dqm   : IN    STD_LOGIC_VECTOR (1 DOWNTO 0) := "00"
    );
  END component;


  signal a_valid:           std_logic;
  signal a_data_out:        std_logic_vector(wordSize-1 downto 0);
  signal a_address:         unsigned(ADDRESS_HIGH-1 downto 2);
  signal a_strobe:          std_logic :='0';
  signal   a_enable:          std_logic :='0';
  signal   a_stall:           std_logic;
  signal   b_valid:           std_logic;
  signal   b_data_out:        std_logic_vector(wordSize-1 downto 0);
  signal   b_data_in:         std_logic_vector(wordSize-1 downto 0);
  signal   b_address:         std_logic_vector(ADDRESS_HIGH-1 downto 2);
  signal   b_strobe:          std_logic :='0';
  signal  b_we:              std_logic;
  signal   b_wmask:           std_logic_vector(3 downto 0);
  signal   b_enable:          std_logic :='0';
  signal   b_stall:           std_logic;
  signal   flush:           std_logic;
    -- Master wishbone interface

  signal   m_wb_ack_i:        std_logic;
  signal   m_wb_dat_i:        std_logic_vector(wordSize-1 downto 0);
  signal   m_wb_dat_o:        std_logic_vector(wordSize-1 downto 0);
  signal  m_wb_adr_o:        std_logic_vector(maxAddrBit downto 0);
  signal   m_wb_cyc_o:        std_logic;
  signal   m_wb_stb_o:        std_logic;
  signal   m_wb_stall_i:      std_logic;
  signal   m_wb_we_o:         std_logic;



  signal wb_clk: std_logic := '0';
  signal wb_rst: std_logic := '0';
  signal iter, biter: integer := 0;

  constant period: time := 10 ns;
  signal ready: std_logic;
  signal sysclk_sram_we: std_logic;

  signal a_r_address: std_logic_vector(ADDRESS_HIGH-1 downto 2);
  signal b_r_address: std_logic_vector(ADDRESS_HIGH-1 downto 2);
begin

  wb_clk <= not wb_clk after period/2;
  sysclk_sram_we <= transport wb_clk after 3 ns;

  process
  begin
    wait for 2 ns;
    wb_rst<='1';
    wait for 80 ns;
    wb_rst<='0';
    ready<='1';
    wait;
  end process;



  process(wb_clk)
    variable ar: std_logic_vector(wordSize-1 downto 0);
  begin
    if rising_edge(wb_clk) then
    if ready='1' then
    case iter is
      when 0 =>
        a_address <= (others => '0');
        a_r_address <= (others => '0');
        a_strobe <= '1';
        a_enable <= '1';
        iter <= iter + 1;
      when 1 =>
        if a_stall='0' then
          a_address <= a_address + 1;
        end if;
        if a_valid='1' then
            if a_data_out(ADDRESS_HIGH-3 downto 0) /= a_r_address then
              ar := (others => '0');
              ar(ADDRESS_HIGH-3 downto 0):=a_r_address;
              report "ERROR A, got 0x"  & hstr(a_data_out) & " expected 0x" & hstr(ar) severity error;
            end if;
          a_r_address <= a_r_address +1;

        end if;

      
      when others =>


    end case;
    else
      -- Reset values ?
      a_strobe <= '0';
    end if;
    end if;
  end process;




  process(wb_clk)
    variable br: std_logic_vector(wordSize-1 downto 0);
  begin
    if rising_edge(wb_clk) then
    if ready='1' then
    case biter is
      when 0 =>
        biter <= biter + 1;

      when 1 =>
        b_address <= "000000000000000000010000";
        b_r_address <= "000000000000000000010000";
        b_strobe <= '1';
        b_enable <= '1';
        b_we <= '1';
        b_data_in <= x"deadbeef";
        biter <= biter + 1;
      when 2 =>
        if b_stall='0' then
          b_address <= b_address + 1;
        end if;
        if b_valid='1' then
            if b_data_out(ADDRESS_HIGH-3 downto 0) /= b_r_address then
              br := (others => '0');
              br(ADDRESS_HIGH-3 downto 0):=b_r_address;
              report "ERROR B, got 0x" & hstr(b_data_out) & " expected 0x" & hstr(br) severity error;
            end if;
          b_r_address <= b_r_address +1;

        end if;

      
      when others =>


    end case;
    else
      -- Reset values ?
      b_strobe <= '0';
    end if;
    end if;
  end process;













  uut:zpuino_dcache
  port map (
    wb_clk_i          => wb_clk,
    wb_rst_i          => wb_rst,
    -- Port A (read-only)
    a_valid           => a_valid,
    a_data_out        => a_data_out,
    a_address         => std_logic_vector(a_address),
    a_strobe          => a_strobe,
    a_enable          => a_enable,
    a_stall           => a_stall,

    -- Port B (read-write)
    b_valid           => b_valid,
    b_data_out        => b_data_out,
    b_data_in         => b_data_in,
    b_address         => b_address,
    b_strobe          => b_strobe,
    b_we              => b_we,
    b_wmask           => b_wmask,
    b_enable          => b_enable,
    b_stall           => b_stall,

    flush             => flush,
    -- Master wishbone interface

    m_wb_ack_i        => m_wb_ack_i,
    m_wb_dat_i        => m_wb_dat_i,
    m_wb_dat_o        => m_wb_dat_o,
    m_wb_adr_o        => m_wb_adr_o,
    m_wb_cyc_o        => m_wb_cyc_o,
    m_wb_stb_o        => m_wb_stb_o,
    m_wb_stall_i      => m_wb_stall_i,
    m_wb_we_o         => m_wb_we_o
  );



  sram_inst: sdram_ctrl
    port map (
      wb_clk_i    => wb_clk,
  	 	wb_rst_i    => wb_rst,
      wb_dat_o    => m_wb_dat_i,
      wb_dat_i    => m_wb_dat_o,
      wb_adr_i    => m_wb_adr_o(maxIObit downto minIObit),
      wb_we_i     => m_wb_we_o,
      wb_cyc_i    => m_wb_cyc_o,
      wb_stb_i    => m_wb_stb_o,
      wb_sel_i    => (others => '1'),--m_wb_sel_o,
      wb_ack_o    => m_wb_ack_i,
      wb_stall_o  => m_wb_stall_i,

      clk_off_3ns => sysclk_sram_we,
    DRAM_ADDR   => DRAM_ADDR(11 downto 0),
    DRAM_BA     => DRAM_BA,
    DRAM_CAS_N  => DRAM_CAS_N,
    DRAM_CKE    => DRAM_CKE,
    DRAM_CLK    => DRAM_CLK,
    DRAM_CS_N   => DRAM_CS_N,
    DRAM_DQ     => DRAM_DQ,
    DRAM_DQM    => DRAM_DQM,
    DRAM_RAS_N  => DRAM_RAS_N,
    DRAM_WE_N   => DRAM_WE_N

    );
    DRAM_ADDR(12) <= '0';

  sdram: mt48lc16m16a2
    GENERIC MAP  (
        addr_bits  => 12,
        data_bits  => 16,
        col_bits   => 8,
        index      => 0,
      	fname      => "sdram.srec"
    )
    PORT MAP (
        Dq    => DRAM_DQ,
        Addr  => DRAM_ADDR(11 downto 0),
        Ba    => DRAM_BA,
        Clk   => DRAM_CLK,
        Cke   => DRAM_CKE,
        Cs_n  => DRAM_CS_N,
        Ras_n => DRAM_RAS_N,
        Cas_n => DRAM_CAS_N,
        We_n  => DRAM_WE_N,
        Dqm   => DRAM_DQM
    );
end sim;

