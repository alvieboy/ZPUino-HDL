
-- VHDL Instantiation Created from source file zpuino_io_YM2149.vhd -- 10:06:59 04/26/2012
--
-- Notes: 
-- 1) This instantiation template has been automatically generated using types
-- std_logic and std_logic_vector for the ports of the instantiated module
-- 2) To use this template to instantiate this entity, cut-and-paste and then edit

	COMPONENT zpuino_io_YM2149
	PORT(
		wb_clk_i : IN std_logic;
		wb_rst_i : IN std_logic;
		wb_dat_i : IN std_logic_vector(31 downto 0);
		wb_adr_i : IN std_logic_vector(26 downto 2);
		wb_we_i : IN std_logic;
		wb_cyc_i : IN std_logic;
		wb_stb_i : IN std_logic;          
		wb_dat_o : OUT std_logic_vector(31 downto 0);
		wb_ack_o : OUT std_logic;
		wb_inta_o : OUT std_logic;
		data_out : OUT std_logic_vector(7 downto 0)
		);
	END COMPONENT;

	Inst_zpuino_io_YM2149: zpuino_io_YM2149 PORT MAP(
		wb_clk_i => ,
		wb_rst_i => ,
		wb_dat_i => ,
		wb_dat_o => ,
		wb_adr_i => ,
		wb_we_i => ,
		wb_cyc_i => ,
		wb_stb_i => ,
		wb_ack_o => ,
		wb_inta_o => ,
		data_out => 
	);


