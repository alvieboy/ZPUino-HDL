#include "crc16.h"
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <fcntl.h>

#define FLASH_SIZE_BYTES ((4*1024*1024)/8)

int help()
{
	return -1;
}

char *flashfilename="flash.bin";
char *binfile=NULL;
char *extrafile=NULL;

int parse_arguments(int argc,char **const argv)
{
	int p;
	while (1) {
		switch ((p=getopt(argc,argv,"b:e:o:"))) {
		case '?':
			return -1;
		case 'b':
			binfile=optarg;
			break;
		case 'e':
			extrafile=optarg;
			break;
		case 'o':
			flashfilename=optarg;
			break;
		}
	}
}



int main(int argc,char **argv)
{
	int outfd;

	if (parse_arguments(argc,argv)<0)
		return help();

	if (NULL==binfile)
		return help();

	// Open output file

	outfd=open(flashfilename,O_RDWR|O_CREAT|O_TRUNC,0666);
	if (outfd<0) {
		perror("open");
		return -1;
	}
	// Sig
	write(outfd,"ZPUFLASH",8);

	return 0;
}

