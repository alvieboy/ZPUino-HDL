library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
library work;
use work.zpu_config.all;
use work.wishbonepkg.all;

entity wb_bootloader is
  port (
    syscon:     in wb_syscon_type;
    wb1i:       in wb_mosi_type;
    wb1o:       out wb_miso_type;
    wb2i:       in wb_mosi_type;
    wb2o:       out wb_miso_type
  );
end wb_bootloader;


architecture behave of wb_bootloader is

  component bootloader_dp_32 is
  port (
    CLK:              in std_logic;
    WEA:  in std_logic;
    ENA:  in std_logic;
    MASKA:    in std_logic_vector(3 downto 0);
    ADDRA:         in std_logic_vector(11 downto 2);
    DIA:        in std_logic_vector(31 downto 0);
    DOA:         out std_logic_vector(31 downto 0);
    WEB:  in std_logic;
    ENB:  in std_logic;
    ADDRB:         in std_logic_vector(11 downto 2);
    DIB:        in std_logic_vector(31 downto 0);
    MASKB:    in std_logic_vector(3 downto 0);
    DOB:         out std_logic_vector(31 downto 0)
  );
  end component bootloader_dp_32;

  signal ack: std_logic;
  signal en:  std_logic;
  signal ack2: std_logic;
  signal en2:  std_logic;

begin

  wb1o.stall <= '0';
  wb2o.stall <= '0';
  wb1o.ack <= ack;
  wb2o.ack <= ack2;

  en  <= wb1i.cyc and wb1i.stb;
  en2 <= wb2i.cyc and wb2i.stb;

  process(syscon.clk)
  begin
    if rising_edge(syscon.clk) then
      if syscon.rst='1' then
        ack <= '0';
        ack2 <= '0';
      else
        ack <= en;
        ack2 <= en2 and not ack2;
      end if;
    end if;
  end process;


  rom: bootloader_dp_32
  port map (
    CLK         => syscon.clk,
    WEA         => '0',
    ENA         => en,
    MASKA       => (others => '1'),
    ADDRA       => wb1i.adr(11 downto 2),
    DIA         => (others => DontCareValue),
    DOA         => wb1o.dat,
    WEB         => '0',
    ENB         => en2,
    ADDRB       => wb2i.adr(11 downto 2),
    DIB         => (others => DontCareValue),
    MASKB       => (others => '1'),
    DOB         => wb2o.dat
  );

end behave;
