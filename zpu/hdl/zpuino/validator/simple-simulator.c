
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/signal.h>
#include <sys/time.h>
unsigned int _usp=0x7FF8;
unsigned char _memory[32768];
unsigned int _upc=0;

extern unsigned int execute();

unsigned int io_load(unsigned int address)
{
//	printf("IO load, address 0x%08x\n", address);
	return 0;
}

void io_store(unsigned int address, unsigned int val)
{
 //   printf("IO store, address 0x%08x, val 0x%08x\n", address,val);
}

static struct timeval start,end;
static struct timeval diff;
unsigned int count=0;

void sign(int s)
{
    double secs;
	gettimeofday(&end,NULL);
	timersub(&end,&start,&diff);
	secs = (double)diff.tv_sec;
	secs += (double)(diff.tv_usec)/1000000.0;

	printf("%u ticks in %f seconds\n", count,secs);
	printf("Frequency: %fMHz\n",(double)count/(secs*1000000.0));
	exit(-1);
}

int main(int argc,char **argv)
{
	int infile = open(argv[1],O_RDONLY);
	read(infile,_memory,32768);
	close(infile);
	signal(SIGINT,&sign);
	gettimeofday(&start,NULL);
	execute();
}
