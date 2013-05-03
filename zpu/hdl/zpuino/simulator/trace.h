#ifndef __TRACE_H__
#define __TRACE_H__

struct trace_entry
{
	unsigned pc;
	unsigned char opcode;
	unsigned sp;
	unsigned tos, nos;
	unsigned tick;
};

extern struct trace_entry *tracebuffer;

void trace_append(unsigned int pc, unsigned int sp, unsigned int top);
void trace_init(unsigned size);
void trace_dump();

#endif

