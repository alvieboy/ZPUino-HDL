-----------------------------------------------------------------------------
--	Filename:	gh_Dff.vhd
--
--	Description:
--		a D Flip-Flop
--
--	Copyright (c) 2005 by George Huber 
--		an OpenCores.org Project
--		free to use, but see documentation for conditions 
--
--	Revision 	History:
--	Revision 	Date       	Author    	Comment
--	-------- 	---------- 	--------	-----------
--	1.0      	09/03/05  	G Huber 	Initial revision
--	2.0     	10/06/05  	G Huber 	name change to avoid conflict
--	        	          	         	  with other libraries
--	2.1      	05/21/06  	S A Dodd 	fix typo's
-----------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity gh_DFF is
	 port(
		 D    : in STD_LOGIC;
		 CLK  : in STD_LOGIC;
		 rst  : in STD_LOGIC;
		 Q    : out STD_LOGIC
	     );
end gh_DFF;

architecture a of gh_DFF is
begin

process(CLK,rst)
begin
	if (rst = '1') then
		Q <= '0';
	elsif (rising_edge(CLK)) then
		Q <= D;
	end if;
end process;

end a;
