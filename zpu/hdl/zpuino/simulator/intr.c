#include "zpuinointerface.h"
#include <stdio.h>
#include <pthread.h>

extern int do_interrupt;
int interrupt_enabled=0;
int interrupt_enabled_request=0;
static unsigned interrupt_mask=0x00;
static unsigned int_line;

static int int_lines[32] = {0};
static pthread_mutex_t intrenlock = PTHREAD_MUTEX_INITIALIZER;

void poppc_instruction(void)
{
	pthread_mutex_lock(&intrenlock);
	/*
	 if (interrupt_enabled_request ^ interrupt_enabled)
	 fprintf(stderr,"Interrupt propagate %d -> %d\n", interrupt_enabled, interrupt_enabled_request);
     */
	interrupt_enabled = interrupt_enabled_request;
	pthread_mutex_unlock(&intrenlock);
}


void zpuino_request_interrupt(int line)
{
//	printf("Interrupting ?\n");
	pthread_mutex_lock(&intrenlock);

	if (interrupt_enabled && (interrupt_mask & (1<<line))) {
		interrupt_enabled=0;
		interrupt_enabled_request=0;
		do_interrupt = 1;
		int_line = line;
		fprintf(stderr,"Interrupting, line %d\n",line);
	} else {
		fprintf(stderr,"QUEUE Interrupting, line %d - en %d, mask %08x\n",line,interrupt_enabled,interrupt_mask);
		int_lines[line] = 1;                           
	}
	pthread_mutex_unlock(&intrenlock);
}

static void propagate()
{
	int i;
	if (interrupt_enabled==0)
		return;

	for (i=0; i< (sizeof(int_lines)/sizeof(int));i++) {
		if (int_lines[i] && (interrupt_mask&(1<<i))) {
			int_lines[i]=0;
			printf("Propagate interrupt line %d\n",i);
			interrupt_enabled=0;
			interrupt_enabled_request=0;
			do_interrupt=1;
			int_line=i;
			break;
		}
	}
   
}

void zpuino_enable_interrupts(int v)
{
	pthread_mutex_lock(&intrenlock);
	if (v==0)
		interrupt_enabled=0;

	interrupt_enabled_request=v;
	do_interrupt=0;
	propagate();
	pthread_mutex_unlock(&intrenlock);
}

unsigned intr_read_status(unsigned address)
{
	//fprintf(stderr, "INTR: en_req %d en %d, do %d, mask %08x\n", interrupt_enabled_request, interrupt_enabled, do_interrupt, interrupt_mask);
	return (unsigned)interrupt_enabled_request;
}

unsigned intr_read_mask(unsigned address)
{
	return interrupt_mask;
}

unsigned intr_read_line(unsigned address)
{
	return 1<<int_line;
}


unsigned intr_io_read_handler(unsigned address)
{
	//printf("INTR read @ 0x%08x\n",address);
	MAPREGR(0,intr_read_status);
	MAPREGR(1,intr_read_mask);
	MAPREGR(2,intr_read_line);
	ERRORREG();
	return 0;
}

extern unsigned int _upc;

unsigned intr_write_status(unsigned address,unsigned value)
{
	zpuino_enable_interrupts(value&1);
	return 0;
}

unsigned intr_write_mask(unsigned address,unsigned value)
{
	pthread_mutex_lock(&intrenlock);
	interrupt_mask=value;
	propagate();
	pthread_mutex_unlock(&intrenlock);

	return 0;
}

unsigned intr_write_ctrl(unsigned address,unsigned value)
{
	return 0;
}

void intr_io_write_handler(unsigned address, unsigned value)
{
	MAPREGW(0,intr_write_status);
	MAPREGW(1,intr_write_mask);
	MAPREGW(4,intr_write_ctrl);
	ERRORREG();
}

static int initialize_device(int argc,char **argv)
{
	return 0;
}

static zpuino_device_t dev = {
	.name = "intr",
	.init = initialize_device,
	.read = intr_io_read_handler,
	.write = intr_io_write_handler,
	.post_init = NULL,
	.class = NULL
};

static void ZPUINOINIT intr_init()
{
	zpuino_register_device(&dev);
}

