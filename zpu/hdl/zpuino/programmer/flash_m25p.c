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
#include "transport.h"
#include "programmer.h"
#include <stdio.h>
#include <string.h>

static int m25p_erase_sector(flash_info_t *flash, connection_t conn, unsigned int sector)
{
	buffer_t *b;
	unsigned char wbuf[8];

	wbuf[0] = 0; // Tx bytes
	wbuf[1] = 4; // Tx bytes
	wbuf[2] = 0; // Rx bytes
	wbuf[3] = 0; // Tx bytes

	/* Thanks BBenj for finding this bug! We need to shift sector position here ! */
	sector *= flash->sectorsize;

	wbuf[4] = 0xD8; // Sector erase
	wbuf[5] = (sector>>16) & 0xff;
	wbuf[6] = (sector>>8) & 0xff;
	wbuf[7] = (sector) & 0xff;

	b = sendreceivecommand(conn, BOOTLOADER_CMD_RAWREADWRITE, wbuf, sizeof(wbuf), 1000);
	if (NULL==b)
		return -1;

	buffer_free(b);

	b = sendreceivecommand(conn, BOOTLOADER_CMD_WAITREADY, NULL, 0, 30000);

	if (NULL==b)
		return -1;

	buffer_free(b);

	return 0;
}

static int m25p_enable_writes(flash_info_t *flash, connection_t conn)
{
	buffer_t *b;
	unsigned char wbuf[5];

	wbuf[0] = 0;
	wbuf[1] = 1; // Tx bytes
	wbuf[2] = 0;
	wbuf[3] = 0; // Rx bytes
	wbuf[4] = 0x06; // Enable Write

	b = sendreceivecommand(conn, BOOTLOADER_CMD_RAWREADWRITE, wbuf, sizeof(wbuf), 1000);

	if (NULL==b)
		return -1;

	buffer_free(b);

	return 0;
}

static buffer_t *m25p_read_page(flash_info_t *flash, connection_t conn, unsigned int page)
{
	unsigned int addr = page * 256;
	unsigned char wbuf[9];
	buffer_t *b;

	wbuf[0] = 0;
	wbuf[1] = 5; // Tx bytes

	wbuf[2] = 1; // Rx bytes
	wbuf[3] = 0;

    wbuf[4] = 0x0B;
	wbuf[5] = (addr >> 16) & 0xff;
	wbuf[6] = (addr >> 8) & 0xff;
	wbuf[7] = (addr) & 0xff;
	wbuf[8] = 0; /* Dummy */

	b = sendreceivecommand(conn, BOOTLOADER_CMD_RAWREADWRITE, wbuf, sizeof(wbuf), 1000);

	if (NULL==b) {
		fprintf(stderr,"Cannot read page\n");
		return NULL;
	}
	return b;
}

static int m25p_program_page(flash_info_t *flash, connection_t conn, unsigned int page, const unsigned char *buf,size_t size)
{
	unsigned char wbuf[256 + 8];
	unsigned int addr = page * 256;
	buffer_t *b;

	if (size!=256)
		return -1;

	wbuf[0] = 0x01;
	wbuf[1] = 0x04;
	wbuf[2] = 0;
    wbuf[3] = 0;

	wbuf[4] = 0x02; // Page program
	wbuf[5] = (addr >> 16) & 0xff;
	wbuf[6] = (addr >> 8) & 0xff;
	wbuf[7] = (addr) & 0xff;

	memcpy(&wbuf[8], buf, size);

	b = sendreceivecommand(conn, BOOTLOADER_CMD_RAWREADWRITE, wbuf, sizeof(wbuf), 5000);

	if (NULL==b) {
		fprintf(stderr,"Cannot program page\n");
		return -1;
	}

	buffer_free(b);

	b = sendreceivecommand(conn, BOOTLOADER_CMD_WAITREADY, NULL, 0, 1000);

	if (NULL==b)
		return -1;

	buffer_free(b);

	return 0;
}

flash_driver_t m25p_flash = {
	.erase_sector  = &m25p_erase_sector,
	.enable_writes = &m25p_enable_writes,
	.read_page     = &m25p_read_page,
	.program_page  = &m25p_program_page
};
