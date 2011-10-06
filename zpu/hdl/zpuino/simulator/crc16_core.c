#include "crc16.h"
#include <inttypes.h>
#include <stdio.h>

static unsigned int crc,crc_dly1,crc_dly2;
static unsigned int poly;

void crc16_update(uint8_t data)
{
	uint8_t i;
	crc ^= data;
	for (i = 0; i < 8; ++i)
	{
		if (crc & 1)
			crc = (crc >> 1) ^ poly;
		else
			crc = (crc >> 1);
	}
}

void crc16_reset(unsigned int value)
{
	crc = value;
}
unsigned int crc16_read_data(unsigned int address)
{
//	printf("CRC: read %04x\n",crc);
	return crc;
}

unsigned int crc16_read_data_dly1(unsigned int address)
{
//	printf("CRC: read %04x\n",crc);
	return crc_dly1;
}

unsigned int crc16_read_data_dly2(unsigned int address)
{
//	printf("CRC: read %04x\n",crc);
	return crc_dly2;
}

unsigned int crc16_read_poly(unsigned int address)
{
	return poly;
}

void crc16_write_data(unsigned int address,unsigned int val)
{
	crc = val;
}
void crc16_write_poly(unsigned int address,unsigned int val)
{
	poly = val;
}

void crc16_write_accumulate(unsigned int address,unsigned int val)
{
	crc_dly2 = crc_dly1;
	crc_dly1 = crc;
	crc16_update(val&0xff);
 //   printf("CRC: update %02x, will read %04x\n",val&0xff,crc);
}
