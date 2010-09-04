library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library work;
use work.zpu_config.all;
use work.zpupkg.all;
use work.zpuinopkg.all;

entity zpuino_timers is
  port (
    clk:      in std_logic;
	 	areset:   in std_logic;
    read:     out std_logic_vector(wordSize-1 downto 0);
    write:    in std_logic_vector(wordSize-1 downto 0);
    address:  in std_logic_vector(2 downto 0);
    we:       in std_logic;
    re:       in std_logic;

    busy:     out std_logic;
    interrupt:out std_logic
  );
end entity zpuino_timers;


architecture behave of zpuino_timers is

signal TSC_q: unsigned(31 downto 0);

signal tmr0_cnt_q: unsigned(15 downto 0);
signal tmr0_cmp_q: unsigned(15 downto 0);
signal tmr0_en_q: std_logic;
signal tmr0_dir_q: std_logic;
signal tmr0_ccm_q: std_logic;
signal tmr0_ien_q: std_logic;

begin

  -- Read
  process(address,TSC_q)
  begin
    read <= (others => '0');
    case address is
      when "000" =>
        read <= std_logic_vector(TSC_q);
      when "001" =>
        read(0) <= tmr0_en_q;
        read(1) <= tmr0_ccm_q;
        read(2) <= tmr0_dir_q;
        read(3) <= tmr0_ien_q;
      when "010" =>
        read(15 downto 0) <= std_logic_vector(tmr0_cnt_q);
      when "011" =>
        read(15 downto 0) <= std_logic_vector(tmr0_cmp_q);
      when others =>
      
    end case;
  end process;


  TSCgen: process(clk)
  begin
    if rising_edge(clk) then
      if areset='1' then
        TSC_q <= (others => '0');
      else
        TSC_q <= TSC_q + 1;
      end if;
    end if;
  end process;

  -- Timer 0
  process(clk)
  begin
    if rising_edge(clk) then
      if areset='1' then
        tmr0_en_q <= '0';
        tmr0_ccm_q <= '0';
        tmr0_dir_q <= '1';
        tmr0_ien_q <= '1';
        tmr0_cmp_q <= (others => '1');
      else
        if we='1' then
          case address is
            when "001" =>
              tmr0_en_q <= write(0);
              tmr0_ccm_q <= write(1);
              tmr0_dir_q <= write(2);
              tmr0_ien_q <= write(3);
            when "011" =>
              tmr0_cmp_q <= unsigned(write(15 downto 0));
            when others =>
          end case;
        end if;
      end if;
    end if;
  end process;

  -- Timer 0 count
  process(clk)
  begin
    if rising_edge(clk) then
      if areset='1' then
        tmr0_cnt_q <= (others => '0');
        interrupt <= '0';
      else
        interrupt <= '0';
        if we='1' and address="010" then
          tmr0_cnt_q <= unsigned(write(15 downto 0));
        else
          if tmr0_en_q='1' then -- Timer enabled..
            if tmr0_cnt_q=tmr0_cmp_q and tmr0_ien_q='1' then
              interrupt <= '1';
            end if;

            if tmr0_cnt_q=tmr0_cmp_q and tmr0_ccm_q='1' then
                -- Clear on compare match
              tmr0_cnt_q<=(others => '0');
            else
              -- count up or down
              if tmr0_dir_q='1' then
                tmr0_cnt_q <= tmr0_cnt_q + 1;
              else
                tmr0_cnt_q <= tmr0_cnt_q - 1;
              end if;
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;

end behave;
