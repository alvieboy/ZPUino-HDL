library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library work;
use work.zpu_config.all;
use work.zpupkg.all;
use work.zpuinopkg.all;
use work.zpuino_config.all;
use work.wishbonepkg.all;

entity tracebuffer is
  port (
    syscon:   in wb_syscon_type;
    dbg_in:   in zpu_dbg_out_type;
    wbo:      out wb_miso_type;
    wbi:      in  wb_mosi_type
  );
end entity tracebuffer;

architecture behave of tracebuffer is

  signal enable_q: std_logic;
  signal ack_q:    std_logic;
  constant abits: integer := 12;
  constant ram_data_size: integer := dbg_in.pc'LENGTH + dbg_in.sp'LENGTH + dbg_in.stacka'LENGTH + dbg_in.opcode'LENGTH;

  signal debug_write_address: unsigned(abits-1 downto 0);
  signal debug_read_address: std_logic_vector(abits-1 downto 0);
  signal debug_in_data: std_logic_vector(ram_data_size-1 downto 0);
  signal debug_out_data: std_logic_vector(ram_data_size-1 downto 0);

  signal debug_write: std_logic;
begin

  debug_write<= enable_q and dbg_in.valid;
  
  traceram: generic_dp_ram 
  generic map (
    address_bits      => abits,
    data_bits         => ram_data_size
  )
  port map (
    clka              => syscon.clk,
    ena               => '1',
    wea               => debug_write,
    addra             => std_logic_vector(debug_write_address),
    dia               => debug_in_data,
    doa               => open,

    clkb              => syscon.clk,
    enb               => '1',
    web               => '0',
    addrb             => debug_read_address,
    dib               => (others => DontCareValue),
    dob               => debug_out_data
  );

  debug_read_address<=wbi.adr((abits-1+5) downto 5);

  process(syscon)
  begin
    if rising_edge(syscon.clk) then
      if syscon.rst='1' then
        debug_write_address<=(others => '0');
      else
        if enable_q='1' and debug_write='1' then
          debug_write_address <= debug_write_address + 1;
        end if;
      end if;
    end if;
  end process;

  debug_in_data <= dbg_in.pc & dbg_in.sp & dbg_in.stacka & dbg_in.opcode;

--  process(syscon.clk)
--  begin
--    if rising_edge(syscon.clk) then
 process (wbi.adr, debug_out_data, debug_write_address)
 begin
    wbo.dat <= (others => '0');--DontCareValue);
    case wbi.adr(4 downto 2) is
      when "000" =>
        wbo.dat(dbg_in.opcode'LENGTH-1 downto 0) <= debug_out_data(dbg_in.opcode'LENGTH-1 downto 0);
      when "001" =>
        wbo.dat(dbg_in.stacka'LENGTH-1 downto 0) <= debug_out_data((dbg_in.stacka'LENGTH+dbg_in.opcode'LENGTH)-1 downto dbg_in.opcode'LENGTH);
      when "010" =>
        wbo.dat(dbg_in.sp'LENGTH-1 downto 0) <= debug_out_data((dbg_in.sp'LENGTH+dbg_in.stacka'LENGTH+dbg_in.opcode'LENGTH)-1 downto (dbg_in.opcode'LENGTH+dbg_in.stacka'LENGTH));
      when "011" =>
        wbo.dat(dbg_in.pc'LENGTH-1 downto 0) <= debug_out_data((dbg_in.pc'LENGTH+dbg_in.sp'LENGTH+dbg_in.stacka'LENGTH+dbg_in.opcode'LENGTH)-1 downto (dbg_in.sp'LENGTH+dbg_in.opcode'LENGTH+dbg_in.stacka'LENGTH));
      when "111" =>
        wbo.dat(debug_write_address'LENGTH-1 downto 0)<= std_logic_vector(debug_write_address);
      when others =>
    end case;
    --end if;
  end process;

  process(syscon)
  begin
    if rising_edge(syscon.clk) then

      ack_q<='0';

      if wbi.cyc='1' and wbi.stb='1' then
        if ack_q='0' then
          ack_q<='1';
        end if;
      end if;

      if syscon.rst='1' then
      end if;
    end if;
  end process;

  wbo.ack <= ack_q;

  process(syscon)
  begin
    if rising_edge(syscon.clk) then
      if syscon.rst='1' then
        enable_q<='1';
      else
        if wbi.cyc='1' and wbi.stb='1' and wbi.we='1' then
          enable_q<=wbi.dat(0);
        end if;
      end if;
    end if;
  end process;


end behave;