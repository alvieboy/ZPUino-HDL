/*
 * ZPUino programmer
 * Copyright (C) 2010-2011 Alvaro Lopes (alvieboy@alvie.com)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "flash.h"
#include <stdio.h>
#include "transport.h"
#include "programmer.h"
#include <string.h>

flash_info_t *find_flash(unsigned int manufacturer,unsigned int product, unsigned int density)
{
	flash_info_t *flash = &flash_list[0];
	while (flash && flash->name) {
		//fprintf(stderr,"TESTING %s\n", flash->name);
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
extern flash_driver_t atmel_flash;


flash_info_t flash_list[] =
{
	/* Dummy flash driver, for direct upload */
	{ 0xAA, 0xAA, 0xAA, 256, 256, 65536, "Direct", NULL },
	{ 0x20, 0x20, 0x15, 256, 65536, 32, "M25P16", &m25p_flash },
	{ 0x20, 0x20, 0x16, 256, 65536, 64, "M25P32", &m25p_flash },
	{ 0xBF, 0x25, 0x8D, 256, 4096, 128, "SST25VF040B", &sst25vf_flash },
	{ 0x1F, 0x25, 0x00, 264, 2112, 512, "AT45DB081D", &atmel_flash }, /* Note: we use blocks here, not sectors */
	{ 0xC2, 0x20, 0x17, 256, 65536, 128, "MX25L6445E", &m25p_flash },
	{ 0xEF, 0x40, 0x14, 256, 65536, 16, "W25Q80BV", &m25p_flash },
	{ 0, 0, 0, 0, 0, 0, NULL, NULL }
};
