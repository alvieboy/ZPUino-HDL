library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.zpu_config.all;
use work.zpupkg.all;
use work.zpuinopkg.all;

entity zpuino_crc16 is
  port (
    clk:      in std_logic;
	 	areset:   in std_logic;
    read:     out std_logic_vector(wordSize-1 downto 0);
    write:    in std_logic_vector(wordSize-1 downto 0);
    address:  in std_logic_vector(10 downto 2);
    we:       in std_logic;
    re:       in std_logic;
    busy:     out std_logic;
    interrupt:out std_logic
  );
end entity zpuino_crc16;

architecture behave of zpuino_crc16 is

signal crc_q: std_logic_vector(15 downto 0);
signal crcA_q: std_logic_vector(15 downto 0);
signal crcB_q: std_logic_vector(15 downto 0);
signal poly_q: std_logic_vector(15 downto 0);
signal data_q: std_logic_vector(7 downto 0);
signal count_q: integer range 0 to 7;
signal ready_q: std_logic;

begin

busy<='1' when ready_q='0' and ( re='1' or we='1') else '0';
interrupt <= '0';

process(address,crc_q,poly_q)
begin
  case address is
    when "000000000" =>
      read(31 downto 16) <= (others => '0');
      read(15 downto 0) <= crc_q;
    when "000000001" =>
      read(31 downto 16) <= (others => '0');
      read(15 downto 0) <= poly_q;
    when "000000100" =>
      read(31 downto 16) <= (others => '0');
      read(15 downto 0) <= crcA_q;
    when "000000101" =>
      read(31 downto 16) <= (others => '0');
      read(15 downto 0) <= crcB_q;
    when others =>
      read <= (others => DontCareValue);
  end case;
end process;

process(clk)
begin
  if rising_edge(clk) then
    if areset='1' then
      poly_q <= x"A001";
      crc_q <= x"FFFF";
      ready_q <= '1';

    else
      if we='1' and ready_q='1' then
        case address(4 downto 2) is
          when "000" =>
            crc_q <= write(15 downto 0);
          when "001" =>
            poly_q <= write(15 downto 0);
          when "010" =>
            ready_q <= '0';
            count_q <= 0;
            data_q <= write(7 downto 0);
            crcA_q <= crc_q;
            crcB_q <= crcA_q;
          when others =>
        end case;
      end if;

      if ready_q='0' then
        if (crc_q(0) xor data_q(0))='1' then
          crc_q <= ( '0' & crc_q(15 downto 1)) xor poly_q;  
        else
          crc_q <= '0' & crc_q(15 downto 1);
        end if;
        data_q <= '0' & data_q(7 downto 1);
        if count_q=7 then
          count_q <= 0;
          ready_q <= '1';
        else
          count_q <= count_q + 1;
        end if;
      end if;

    end if;
  end if;
end process;

end behave;
