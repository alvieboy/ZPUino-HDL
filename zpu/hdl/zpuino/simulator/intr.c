#include "zpuinointerface.h"
#include <stdio.h>

extern int do_interrupt;
int interrupt_enabled=0;

static int int_lines[32] = {0};

void zpuino_request_interrupt(int line)
{
   // printf("Interrupting\n");
	if (interrupt_enabled) {
		do_interrupt = 1;
		interrupt_enabled=0;
	} else {
		int_lines[line] = 1;
	}
}

void zpuino_enable_interrupts()
{
	interrupt_enabled=1;
	int i;
	for (i=0; i< (sizeof(int_lines)/sizeof(int));i++) {
		if (int_lines[i]) {
			int_lines[i]=0;
			printf("Propagate interrupt line %d\n",i);
			interrupt_enabled=0;
		}
	}
}

unsigned intr_read_status(unsigned address)
{
	return (unsigned)interrupt_enabled;
}

unsigned intr_read_mask(unsigned address)
{
	return 0xffffffff;
}


unsigned intr_io_read_handler(unsigned address)
{
	//printf("INTR read @ 0x%08x\n",address);
	MAPREGR(0,intr_read_status);
	MAPREGR(1,intr_read_mask);
	ERRORREG();
	return 0;
}

unsigned intr_write_status(unsigned address,unsigned value)
{
	do_interrupt=0;
	interrupt_enabled = value&1;
	return 0;
}

unsigned intr_write_mask(unsigned address,unsigned value)
{
	return 0;
}

unsigned intr_write_ctrl(unsigned address,unsigned value)
{
	return 0;
}

void intr_io_write_handler(unsigned address, unsigned value)
{
	//printf("INTR write 0x%08x @ 0x%08x\n",value,address);
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

