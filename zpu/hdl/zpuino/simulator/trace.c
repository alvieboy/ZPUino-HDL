#include "trace.h"
#include <byteswap.h>
#include "defs.h"
#include <malloc.h>
#include <stdlib.h>

static unsigned tracebufsize;
static unsigned tracelow=0, tracehigh=0;
extern unsigned char _memory[], _stack[];

extern unsigned zpuino_get_tick_count();

struct trace_entry *tracebuffer;

void trace_append(unsigned int pc, unsigned int sp, unsigned int top)
{
	struct trace_entry *entry = &tracebuffer[tracehigh];
	//fprintf(stderr,"L %d h %d\n",tracelow,tracehigh);
	tracehigh++;
	if (tracehigh>=tracebufsize) {
		tracehigh=0;
		tracelow++;
	}
	if (tracelow==tracehigh) {
		tracelow++;
	}
	if (tracelow>=tracebufsize)
		tracelow=0;

	unsigned int *spalign  = (unsigned int*)&_stack[0];
	entry->pc = pc;
	entry->opcode = _memory[pc];
	entry->sp = sp;
	entry->tos = top;
	entry->nos = bswap_32(spalign[ (( ( sp & (STACK_SIZE-1) ) >>2) + 1 )] );
	entry->tick = zpuino_get_tick_count();
	if (entry->tick>=tracebufsize-10)
		abort();
#if 0
	/* Slowdown */
	{
		int i;
		for (i=0;i<32;i++) {
			__asm__ volatile ("pause\n");
		}
	}
#endif
}

void trace_init(unsigned size)
{
	tracebuffer = malloc(size*sizeof(struct trace_entry));
	tracebufsize = size;
}

static char makechar(unsigned v) {
	if (v<' ')
		return ' ';
	if (v>127)
		return '?';
	return v;
}

extern unsigned _usp;

void mem_dump()
{
    int is_stack = 0;
    unsigned stack_offset=0;
	FILE *tf = fopen("mem.txt","w");
	if (!tf)
		return;
	

	unsigned *_raw_mem = (unsigned*)&_memory[0];
	unsigned spoffset = _usp & ~(STACK_SIZE-1);
	fprintf(tf,"Stack pointer at 0x%08x (from 0x%08x)\n", spoffset, _usp);
	int i;
	for (i=0;i<MEMSIZE/4;i++) {
		unsigned v = bswap_32(_raw_mem[i]);
		is_stack=0;
		if ( ((i<<2)& ~(STACK_SIZE-1)) == spoffset) {

			unsigned *_raw_stack = (unsigned*)&_stack[0];

			stack_offset = i & ((STACK_SIZE-1)>>2);

			unsigned sread = _raw_stack[ stack_offset ];


			v= bswap_32(sread);
            is_stack=1;
		}
		
		char a = makechar(v >> 24);
		char b = makechar((v >> 16)&0xff);
		char c = makechar((v >> 8)&0xff);
		char d = makechar((v)&0xff);
		if (!is_stack) {
			fprintf(tf, "0x%08x 0x%08x %c %c %c %c\n", i<<2, v,a,b,c,d);
		} else {
			fprintf(tf, "0x%08x 0x%08x %c %c %c %c STACK %d\n", i<<2, v,a,b,c,d, stack_offset);
		}
	}
	fclose(tf);
}

void trace_dump()
{
	FILE *tf = fopen("trace.txt","a");

	if (tracelow!=tracehigh)
		mem_dump();

	while (tracelow!=tracehigh) {
		struct trace_entry *trace = &tracebuffer[tracelow];

		fprintf(tf,"0x%07X 0x%02X 0x%08X 0x%08X 0x%08X 0x?u 0x%016x\n",
				trace->pc,
				trace->opcode,
				trace->sp,
				trace->tos,
				trace->nos,
				trace->tick
			   );
		tracelow++;
		tracelow%=tracebufsize;
	}

    tracelow=tracehigh;

}

