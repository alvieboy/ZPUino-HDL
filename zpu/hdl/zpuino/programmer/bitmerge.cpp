#include "bitfile.h"
#include "bitrev.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>


int main(int argc,char **argv)
{
	BitFile bf;

	if (argc<2)
		return -1;

	FILE *bin = fopen(argv[1],"r");
	if (NULL==bin) {
		fprintf(stderr,"Cannot open %s: %s\n", argv[1]);
	}

	bf.readFile(bin, STYLE_BIT);

    unsigned bytelen = bf.getLength()/8;
	fprintf(stderr,"Bit file for %s, len %d\n",bf.getPartName(), bytelen);

	FILE  *binout = fopen("teste.bin","w");

	/* Reverse */

	unsigned char *nbuf = (unsigned char*)malloc(bytelen);

	int i ;
	for (i=0; i<bf.getLength()/8; i++)
		nbuf[i] = bitRevTable[bf.getData()[i]];



	fwrite(nbuf, bytelen, 1,  binout);
	free(nbuf);
	fclose(binout);
}
