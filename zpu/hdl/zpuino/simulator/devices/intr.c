#include "zpuinointerface.h"
#include <stdio.h>

unsigned intr_io_read_handler(unsigned address)
{
	//printf("INTR read @ 0x%08x\n",address);
	return 0;
}

void intr_io_write_handler(unsigned address, unsigned value)
{
	//printf("INTR write 0x%08x @ 0x%08x\n",value,address);
}

int initialize_device(int argc,char **argv)
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

zpuino_device_t *get_device() {
	return &dev;
}
