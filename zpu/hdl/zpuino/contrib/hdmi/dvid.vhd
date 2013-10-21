--------------------------------------------------------------------------------
-- Engineer:      Mike Field <hamster@snap.net.nz>
-- Description:   Converts VGA signals into DVID bitstreams.
--
--                'clk' and 'clk_n' should be 5x clk_pixel.
--
--                'blank' should be asserted during the non-display 
--                portions of the frame
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
Library UNISIM;
use UNISIM.vcomponents.all;

entity dvid is
    Port ( clk       : in  STD_ULOGIC;
           --clk_n     : in  STD_ULOGIC;
           clk_pixel : in  STD_ULOGIC;
           clk2x     : in std_ulogic;
           pll_locked: in std_ulogic;
           red_p     : in  STD_LOGIC_VECTOR (7 downto 0);
           green_p   : in  STD_LOGIC_VECTOR (7 downto 0);
           blue_p    : in  STD_LOGIC_VECTOR (7 downto 0);
           blank     : in  STD_LOGIC;
           guard     : in  STD_LOGIC;
           startp    : in  STD_LOGIC;
           hsync     : in  STD_LOGIC;
           vsync     : in  STD_LOGIC;
           red_s     : out STD_ULOGIC;
           green_s   : out STD_ULOGIC;
           blue_s    : out STD_ULOGIC;
           clock_s   : out STD_ULOGIC);
end dvid;

architecture Behavioral of dvid is
   COMPONENT TDMS_encoder
   generic (
      CHANNEL : integer range 0 to 2 := 0
   );
   PORT(
      clk     : IN  std_logic;
      data    : IN  std_logic_vector(7 downto 0);
      c       : IN  std_logic_vector(1 downto 0);
      blank   : IN  std_logic;
      guard   : IN  std_logic;
      encoded : OUT std_logic_vector(9 downto 0)
      );
   END COMPONENT;

   signal encoded_red, encoded_green, encoded_blue : std_logic_vector(9 downto 0);
   signal latched_red, latched_green, latched_blue : std_logic_vector(9 downto 0) := (others => '0');
   signal shift_red,   shift_green,   shift_blue   : std_logic_vector(9 downto 0) := (others => '0');
   
   signal shift_clock   : std_logic_vector(9 downto 0) := "0000011111";

   
   constant c_red       : std_logic_vector(1 downto 0) := (others => '0');
   signal   c_green     : std_logic_vector(1 downto 0);
   signal   c_blue      : std_logic_vector(1 downto 0);

  component ser10 is
  port (
    clk:    in std_ulogic;
    --nclk:    in std_ulogic;
    locked: in std_ulogic;
    clkdiv: in std_ulogic;
    serdesstrobe: in std_ulogic;
    datain: in std_logic_vector(9 downto 0);
    dataout: out std_ulogic
  );
  end component ser10;

  signal ioclk: std_ulogic;
  signal serdesstrobe: std_ulogic;

  signal clk_n: std_ulogic;
begin   
   c_blue <= vsync & hsync;

   c_green <= "10" when startp='1' else "00";
   
   TDMS_encoder_red:   TDMS_encoder GENERIC MAP ( CHANNEL => 2 ) PORT MAP(clk => clk_pixel, data => red_p,   c => c_red,   blank => blank, guard => guard, encoded => encoded_red);
   TDMS_encoder_green: TDMS_encoder GENERIC MAP ( CHANNEL => 1 ) PORT MAP(clk => clk_pixel, data => green_p, c => c_green, blank => blank, guard => guard, encoded => encoded_green);
   TDMS_encoder_blue:  TDMS_encoder GENERIC MAP ( CHANNEL => 0 ) PORT MAP(clk => clk_pixel, data => blue_p,  c => c_blue,  blank => blank, guard => guard, encoded => encoded_blue);

  oldddr: if false generate

   ODDR2_red   : ODDR2 generic map( DDR_ALIGNMENT => "C0", INIT => '0', SRTYPE => "ASYNC") 
      port map (Q => red_s,   D0 => shift_red(0),   D1 => shift_red(1),   C0 => clk, C1 => clk_n, CE => '1', R => '0', S => '0');
   
   ODDR2_green : ODDR2 generic map( DDR_ALIGNMENT => "C0", INIT => '0', SRTYPE => "ASYNC") 
      port map (Q => green_s, D0 => shift_green(0), D1 => shift_green(1), C0 => clk, C1 => clk_n, CE => '1', R => '0', S => '0');

   ODDR2_blue  : ODDR2 generic map( DDR_ALIGNMENT => "C0", INIT => '0', SRTYPE => "ASYNC") 
      port map (Q => blue_s,  D0 => shift_blue(0),  D1 => shift_blue(1),  C0 => clk, C1 => clk_n, CE => '1', R => '0', S => '0');

   ODDR2_clock : ODDR2 generic map( DDR_ALIGNMENT => "C0", INIT => '0', SRTYPE => "ASYNC") 
      port map (Q => clock_s, D0 => shift_clock(0), D1 => shift_clock(1), C0 => clk, C1 => clk_n, CE => '1', R => '0', S => '0');


   process(clk_pixel)
   begin
      if rising_edge(clk_pixel) then 
            latched_red   <= encoded_red;
            latched_green <= encoded_green;
            latched_blue  <= encoded_blue;
      end if;
   end process;

   process(clk)
   begin
      if rising_edge(clk) then 
         if shift_clock = "0000011111" then
            shift_red   <= latched_red;
            shift_green <= latched_green;
            shift_blue  <= latched_blue;
         else
            shift_red   <= "00" & shift_red  (9 downto 2);
            shift_green <= "00" & shift_green(9 downto 2);
            shift_blue  <= "00" & shift_blue (9 downto 2);
         end if;
         shift_clock <= shift_clock(1 downto 0) & shift_clock(9 downto 2);
      end if;
   end process;

  end generate;

  newserdes: if true generate

  -- New, OSERDES based

  ipll: BUFPLL
    generic map (
      DIVIDE => 5
    )
    port map (
      IOCLK        => ioclk,
      LOCK         => OPEN,
      SERDESSTROBE => serdesstrobe,

      GCLK         => clk2x,
      LOCKED       => pll_locked,
      PLLIN        => clk

    );

  osclk: ser10 port map ( clk => ioclk,   locked => pll_locked, serdesstrobe => serdesstrobe, clkdiv => clk2x, datain => "0000011111", dataout => clock_s );
  osred: ser10 port map ( clk => ioclk,   locked => pll_locked, serdesstrobe => serdesstrobe, clkdiv => clk2x, datain => encoded_red, dataout => red_s );
  osgreen: ser10 port map ( clk => ioclk, locked => pll_locked, serdesstrobe => serdesstrobe, clkdiv => clk2x, datain => encoded_green, dataout => green_s );
  osbluc: ser10 port map ( clk => ioclk,  locked => pll_locked, serdesstrobe => serdesstrobe, clkdiv => clk2x, datain => encoded_blue, dataout => blue_s );

  end generate;

       
end Behavioral;
