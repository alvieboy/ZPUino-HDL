#include "trace.h"
#include <byteswap.h>
#include "defs.h"
#include <malloc.h>

static unsigned tracebufsize;
static unsigned tracelow=0, tracehigh=0;
extern unsigned char _memory[], _stack[];

extern unsigned zpuino_get_tick_count();

struct trace_entry *tracebuffer;

void trace_append(unsigned int pc, unsigned int sp, unsigned int top)
{
	struct trace_entry *entry = &tracebuffer[tracehigh];
	tracehigh++;
	if (tracehigh>=tracebufsize) {
		tracehigh=0;
		tracelow++;
	}
	if (tracelow==tracehigh) {
		tracelow++;
	}
	unsigned int *spalign  = (unsigned int*)&_stack[0];
	entry->pc = pc;
	entry->opcode = _memory[pc];
	entry->sp = sp;
	entry->tos = top;
	entry->nos = bswap_32(spalign[ (( ( sp & (STACK_SIZE-1) ) >>2) + 1 )] );
    entry->tick = zpuino_get_tick_count();

}

void trace_init(unsigned size)
{
	tracebuffer = malloc(size*sizeof(struct trace_entry));
    tracebufsize=size;
}

void trace_dump()
{

	while (tracelow!=tracehigh) {
		struct trace_entry *trace = &tracebuffer[tracelow];

		printf("0x%07X 0x%02X 0x%08X 0x%08X 0x%08X 0x?u 0x%016x\n",
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



}

