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

#ifndef __FLASH_H__
#define __FLASH_H__

#include "transport.h"
#include "programmer.h"

struct flash_driver_t;

typedef struct {
	unsigned int manufacturer;
	unsigned int product;
	unsigned int density;
	unsigned int pagesize;
	unsigned int sectorsize;
	unsigned int totalsectors;
	const char *name;
	struct flash_driver_t *driver;
} flash_info_t;

typedef struct flash_driver_t {
	int (*erase_sector)(flash_info_t *flash, connection_t conn, unsigned sector);
	int (*enable_writes)(flash_info_t *flash, connection_t conn);
	buffer_t *(*read_page)(flash_info_t *flash, connection_t conn, unsigned page);
	int (*program_page)(flash_info_t *flash, connection_t fd, unsigned page, const unsigned char *data, size_t size);
} flash_driver_t;



extern flash_info_t flash_list[];

flash_info_t *find_flash(unsigned int manufacturer,unsigned int product, unsigned int density);

#endif
