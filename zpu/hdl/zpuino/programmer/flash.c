#include "flash.h"
#include <stdio.h>
#include "transport.h"
#include "programmer.h"
#include <string.h>

flash_info_t *find_flash(unsigned int manufacturer,unsigned int product, unsigned int density)
{
	flash_info_t *flash = &flash_list[0];
	while (flash && flash->name) {
		if (flash->manufacturer==manufacturer &&
			flash->product == product &&
			flash->density == density)
			return flash;
		flash++;
	}
	return NULL;
}

extern flash_driver_t m25p_flash;
extern flash_driver_t sst25vf_flash;

flash_info_t flash_list[] =
{
	{ 0x20, 0x20, 0x15, 256, 65536, "M25P16", &m25p_flash },
	{ 0xBF, 0x25, 0x8D, 256, 4096, "SST25VF040B", &sst25vf_flash },
	{ 0, 0, 0, 0, 0, NULL, NULL }
};
