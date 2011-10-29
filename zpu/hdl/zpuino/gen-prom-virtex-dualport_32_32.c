#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

unsigned char roms[8][2048];
unsigned char data[16384];



/*
                       01234567 01234567 01234567 01234567 
                       |        |        |        |        
                       0        0        0        0        
                        1        1        1        1
                       */
int getbit(unsigned char *p, int index)
{
	unsigned char c = *p;
	c>>=index;
	return c&1;
}

int setbit(unsigned char *p, int index, int value)
{
	value<<=index;
	*p = *p | value;
	return 0;
}

int setrombit(int rom, int index, int value)
{
	int loc = index/8;
	int off = index%8;

	value<<=off;
	roms[rom][loc]  =  roms[rom][loc] | value;
	return 0;
}


int getdatabit(int index)
{
	int loc = index/8;
	int off= index%8;
	return getbit(&data[loc],off);
}

int main(int argc, char **argv)
{
	int fd;
	int i,z,t;
	if ((fd=open(argv[1], O_RDONLY))<0) {
		perror("open");
		return -1;
	}

	memset(data,0,sizeof(data));

	for (i=0;i<8; i++) {
		memset(roms[i],0,sizeof(roms[i]));
	}

	while (read(fd,data,16384)>0) {};
	close(fd);

	for (i=0;i<16384; i++) {
		for (z=0;z<8; z++) {
			setrombit(z,i, getdatabit(i*8+z));
		}

	}
	printf("library IEEE; \n"
		   "use IEEE.std_logic_1164.all;\n"
		   "use IEEE.std_logic_unsigned.all;\n"

		   "library UNISIM;\n"
		   "use UNISIM.vcomponents.all;\n"

		   "entity dp_rom_32_32 is \n"
		   "port (ADDRA: in std_logic_vector(13 downto 2);\n"
		   "      CLK : in std_logic;\n"
		   "      ENA:   in std_logic;\n"
		   "      WEA: in std_logic; -- to avoid a bug in Xilinx ISE\n"
		   "      DOA: out STD_LOGIC_VECTOR (31 downto 0);\n"
		   "      ADDRB: in std_logic_vector(13 downto 2);\n"
		   "      DIA: in STD_LOGIC_VECTOR (31 downto 0); -- to avoid a bug in Xilinx ISE\n"
		   "      WEB: in std_logic;\n"
		   "      ENB:   in std_logic;\n"
		   "      DOB: out STD_LOGIC_VECTOR (31 downto 0);\n"
		   "      DIB: in STD_LOGIC_VECTOR (31 downto 0));\n"
		   "end dp_rom_32_32;\n");

	printf("architecture behave of dp_rom_32_32 is\n");


	for (i=0;i<8;i++) {

		printf("signal ram_%d_DOB: std_logic_vector(3 downto 0);\n", i);
		printf("signal ram_%d_DIB: std_logic_vector(3 downto 0);\n", i);
		printf("signal ram_%d_DOA: std_logic_vector(3 downto 0);\n", i);
		printf("signal ram_%d_DIA: std_logic_vector(3 downto 0);\n", i);
	}

	printf("\nbegin\n");

	// Map outputs and inputs for 4-bit mode.
	/*
	 01234567 01234567 01234567 01234567
	 |        |        |        |
	 0        0        0        0
	 1        1        1        1
	 */

	for (i=0;i<32;i++) {
		printf("DOB(%d) <= ram_%d_DOB(%d);\n",i,i%8,(31-i)/8);
	}
	for (i=0;i<32;i++) {
		printf("DOA(%d) <= ram_%d_DOA(%d);\n",i,i%8,(31-i)/8);
	}
	for (i=0;i<32;i++) {
		printf("ram_%d_DIA(%d) <= DIA(%d);\n",i%8,(31-i)/8,i);
	}
	for (i=0;i<32;i++) {
		printf("ram_%d_DIB(%d) <= DIB(%d);\n",i%8,(31-i)/8,i);
	}

	for (i=0;i<8;i++) {
		printf("RAM_%d_inst : RAMB16_S4_S4 \n"
			   "generic map ( \n"
			   //" WRITE_MODE => \"WRITE_FIRST\",\n"
			   ,i);
		for (t=0; t<64; t++) {
			printf("INIT_%02X => X\"",t);
			for (z=0; z<32; z++) {
				printf("%02x", roms[i][(31-z)+t*32]);
			}
			printf("\"");
			if (t<63) printf(",\n");
			else {
				printf(")\n");
				printf("port map ( \n"
					   "DOA => ram_%d_DOA, -- 4-bit Data Output \n"
					   "ADDRA => ADDRA, -- 14-bit Address Input \n"
					   "CLKA => CLK, -- Clock \n"
					   "DIA => ram_%d_DIA, -- 4-bit Data Input \n"
					   "ENA => ENA, -- RAM Enable Input \n"
					   "WEA => WEA, -- Write Enable Input \n"
					   "DOB => ram_%d_DOB, -- 4-bit Data Output \n"
					   "ADDRB => ADDRB, -- 12-bit Address Input \n"
					   "CLKB => CLK, -- Clock \n"
					   "SSRA => '0', \n"
					   "SSRB => '0', \n"
					   "DIB => ram_%d_DIB, -- 4-bit Data Input \n"
					   "ENB => ENB, -- RAM Enable Input \n"
					   "WEB => WEB -- Write Enable Input \n"
					   ");\n",
					   i, // DOA
					   //i, // DOA
					   //((i+1)*4)-1, // DIA
					   //(i*4), // DIA
                       i, // DIA
					   i, // DOB
					   i // DIB
					  );
			}
		}
		//printf("%d\n", getbit(&roms[i][0],0));
	}
	printf("end behave;\n");

	return 0;
}

