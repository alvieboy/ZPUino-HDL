library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.zpu_config.all;
use work.zpupkg.all;
use work.zpuinopkg.all;

entity zpuino_rgbctrl is
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
    id:       out slot_id;

    displayclk: in std_logic;
    -- RGB outputters

    R:        out std_logic_vector(1 downto 0);
    G:        out std_logic_vector(1 downto 0);
    B:        out std_logic_vector(1 downto 0);

    COL:      out std_logic_vector(3 downto 0);

    CLK:      out std_logic;
    STB:      out std_logic;
    OE:       out std_logic
  );
end entity zpuino_rgbctrl;


architecture behave of zpuino_rgbctrl is

  constant WITDH: integer := 32;
  --constant HEIGHT: integer := 16;

  signal clken: std_logic;

  subtype pwmtype is unsigned(4 downto 0); -- 32 values.

  type rgbpwm is array (0 to 3) of pwmtype;

  type tworgbpwm is array(0 to 1) of rgbpwm;

  signal transfer: std_logic;
  signal in_transfer: std_logic := '0';



  subtype rgbtype is std_logic_vector(2 downto 0);
  type shifteddatatype is array(WITDH-1 downto 0) of rgbtype;

  type dualshifteddatatype is array(0 to 1) of shifteddatatype;

  signal shiftout, shiftdata: dualshifteddatatype;

  type shtype is (
    idle,shift,clock,strobe
  );
  signal shstate: shtype;

  signal transfer_count: integer;

  -- Memory
  subtype memwordtype is std_logic_vector(31 downto 0);
  type memtype is array(0 to (32*16)) of memwordtype;

  shared variable mem: memtype := (others => x"3def3def");
  signal ack_transfer: std_logic := '0';

  signal mraddr: unsigned(8 downto 0) := (others => '0');
  signal mrdata: std_logic_vector(31 downto 0);
  signal mren: std_logic;
  signal cpwm: unsigned (4 downto 0) := (others => '0');

  signal column: unsigned(4 downto 0) := (others => '0');
  signal row: unsigned(5 downto 0) := (others => '0');

  subtype colorvaluetype is unsigned(4 downto 0);
  type utype is array(0 to 3) of colorvaluetype;

  type fillerstatetype is (
    compute,
    preparesend,
    send
  );

  signal fillerstate: fillerstatetype := compute;

  signal debug_compresult: std_logic_vector(2 downto 0);
  signal memvalid: std_logic := '0';

begin


  process(displayclk)
  begin
    if rising_edge(displayclk) then
      if mren='1' then
        mrdata <= mem( to_integer(mraddr) );
      end if;
    end if;
  end process;

  mraddr (8 downto 5) <= column(3 downto 0);
  mraddr (4 downto 0) <= row(4 downto 0);

  -- This is an odd way for processing the PWM. Perhaps
  -- we can reorganize the memory ?


  process(displayclk)
    variable ucomp: utype;
    variable mword: unsigned(15 downto 0);
    variable compresult: std_logic_vector(2 downto 0);
  begin
    if rising_edge(displayclk) then

      memvalid <= mren;

      case fillerstate is
        when compute =>

          mren <= '1';
          if mren='1' and row(5)='0' then
           row <= row + 1;
          end if;

          if memvalid='1' then
            -- We have valid data;
            if (row(5)='1') then
              --fillerstate <= preparesend;
              fillerstate <= send;
              mren<='0';
              row(5)<='0';
              transfer<='1';
              column <= column + 1 ;
            end if;

        

            -- Validate if PWM bit for this LED should be '1' or '0'
    
            genpwm: for i in 0 to 1 loop
              -- We need to decompose into the individual components
              mword := unsigned(mrdata((16*(i+1))-1 downto 16*i));
    
              ucomp(2) := mword(4 downto 0);
              ucomp(1) := mword(9 downto 5);
              ucomp(0) := mword(14 downto 10);
              -- Compare output for each of them
              comparepwm: for j in 0 to 2 loop
                if (ucomp(j)>=cpwm) then
                  compresult(j):='1';
                else
                  compresult(j):='0';
                end if;
                -- At this point we have the comparation. Shift it into the correct
                -- registers.
    
              end loop;


              shiftdata(i)(31 downto 1) <= shiftdata(i)(30 downto 0);
              shiftdata(i)(0) <= compresult;
            end loop;
    
            if row(5)='1' and column(4)='1' then
              -- Advance pwm counter
              cpwm <= cpwm + 1;
              column(4)<='0';
            end if;
          end if;

        when preparesend =>
 --         transfer<='1';
--          column <= column + 1 ;
          fillerstate <= send;

        when send =>
          if ack_transfer='1' then
            mren<='1';
            fillerstate<=compute;
            transfer<='0';
          end if;
  
      end case;
    end if;

    debug_compresult <= compresult;

  end process;

  -- 32x32 leds. if we use a whole 16-bit for each....
  -- we can read two RGB per clock. ..



  process(wb_clk_i)
  begin
    
  end process;

  -- Main outputter process.

  process(displayclk)
  begin
    if rising_edge(displayclk) then
      STB<='0';
      CLK<='0';
      ack_transfer<='0';
      case shstate is
        when idle =>
          if transfer='1' then
            -- Load shift registers.
            shiftout <= shiftdata;
            in_transfer<='1';
            transfer_count <= WITDH-1;
            shstate<=shift;
            ack_transfer <='1';
          end if;

        when shift =>

          -- Shift data out.

          for i in 0 to 1 loop -- Array number
            for n in 1 to WITDH-1 loop -- Number of leds
              for c in 0 to 2 loop -- Color number
                shiftout(i)(n-1)(c) <= shiftout(i)(n)(c);
              end loop;
            end loop;
          end loop;
          shstate<=clock;

        when clock =>

          transfer_count <= transfer_count - 1;

          CLK<='1';
          if transfer_count=0 then
            shstate <= strobe;
          else
            shstate <= shift;
          end if;
        when strobe =>
          STB <= '1';
          shstate <= idle;

      end case;

    end if;

  end process;

  -- Assign outputs
  ol: for i in 0 to 1 generate
    R(i) <= shiftout(i)(0)(0);
    G(i) <= shiftout(i)(0)(1);
    B(i) <= shiftout(i)(0)(2);
  end generate;

end behave;










