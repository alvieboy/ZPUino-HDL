#include "crc16.h"
#include <inttypes.h>
#include <stdio.h>
#include "zpuinointerface.h"

unsigned crc16_io_read_handler(unsigned address)
{
	MAPREGR(0,crc16_read_data);
	MAPREGR(1,crc16_read_poly);
	MAPREGR(4,crc16_read_data_dly1);
	MAPREGR(5,crc16_read_data_dly2);
	ERRORREG();
	return 0;
}

void crc16_io_write_handler(unsigned address, unsigned value)
{
	MAPREGW(0,crc16_write_data);
	MAPREGW(1,crc16_write_poly);
	MAPREGW(2,crc16_write_accumulate);
	ERRORREG();
}

static int initialize_device(int argc, char **argv)
{
	return 0;
}

static zpuino_device_t dev = {
	.name = "crc16",
	.init = initialize_device,
	.read = crc16_io_read_handler,
	.write = crc16_io_write_handler,
	.post_init = NULL,
	.class = NULL
};
/*
zpuino_device_t * ZPUINOINIT get_device() {
	return &dev;
	}
	*/
static void ZPUINOINIT crc16_init()
{
	zpuino_register_device(&dev);
}
