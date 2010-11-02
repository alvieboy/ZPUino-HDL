
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
  //  printf("IO store, address 0x%08x, val 0x%08x\n", address,val);
}

static struct timeval start,end;
static struct timeval diff;
unsigned int count=0;

void trace(unsigned int pc, unsigned int sp, unsigned int top)
{
	printf("0x%04X 0x%02X 0x%08X 0x%08X 0x%08X\n", pc,
		   _memory[pc], sp,
		   top,
		   *(unsigned int*)&_memory[sp+4]);
}

unsigned int cflip(unsigned int r)
{
    register unsigned int v = r; // 32-bit word to reverse bit order

	// swap odd and even bits
	v = ((v >> 1) & 0x55555555) | ((v & 0x55555555) << 1);
	// swap consecutive pairs
	v = ((v >> 2) & 0x33333333) | ((v & 0x33333333) << 2);
	// swap nibbles ...
	v = ((v >> 4) & 0x0F0F0F0F) | ((v & 0x0F0F0F0F) << 4);
	// swap bytes
	v = ((v >> 8) & 0x00FF00FF) | ((v & 0x00FF00FF) << 8);
	// swap 2-byte long pairs
	v = ( v >> 16             ) | ( v               << 16);
	return v;
}

const unsigned char BitReverseTable256[256] =
{
#   define R2(n)     n,     n + 2*64,     n + 1*64,     n + 3*64
#   define R4(n) R2(n), R2(n + 2*16), R2(n + 1*16), R2(n + 3*16)
#   define R6(n) R4(n), R4(n + 2*4 ), R4(n + 1*4 ), R4(n + 3*4 )
    R6(0), R6(2), R6(1), R6(3)
};

unsigned int cflip2(unsigned int v)
{

	register unsigned int c; // c will get v reversed

	// Option 1:
	c = (BitReverseTable256[v & 0xff] << 24) |
		(BitReverseTable256[(v >> 8) & 0xff] << 16) |
		(BitReverseTable256[(v >> 16) & 0xff] << 8) |
		(BitReverseTable256[(v >> 24) & 0xff]);
	return c;
}

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
