
-- VHDL Instantiation Created from source file zpuino_io_audiomixer.vhd -- 10:07:35 04/26/2012
--
-- Notes: 
-- 1) This instantiation template has been automatically generated using types
-- std_logic and std_logic_vector for the ports of the instantiated module
-- 2) To use this template to instantiate this entity, cut-and-paste and then edit

	COMPONENT zpuino_io_audiomixer
	PORT(
		clk : IN std_logic;
		rst : IN std_logic;
		ena : IN std_logic;
		data_in1 : IN std_logic_vector(17 downto 0);
		data_in2 : IN std_logic_vector(17 downto 0);
		data_in3 : IN std_logic_vector(17 downto 0);          
		audio_out : OUT std_logic
		);
	END COMPONENT;

	Inst_zpuino_io_audiomixer: zpuino_io_audiomixer PORT MAP(
		clk => ,
		rst => ,
		ena => ,
		data_in1 => ,
		data_in2 => ,
		data_in3 => ,
		audio_out => 
	);


