#include <inttypes.h>

void crc16_update(uint16_t *crc, uint8_t data)
{
	data ^= *crc&0xff;
	data ^= data << 4;
	*crc = ((((uint16_t)data << 8) | ((*crc>>8)&0xff)) ^ (uint8_t)(data >> 4)
		   ^ ((uint16_t)data << 3));
}
