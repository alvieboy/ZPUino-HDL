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
#include <stdlib.h>

static int atmel_wait_ready(connection_t conn)
{
	buffer_t *b;
	int status;

	if (get_programmer_version() > 0x0102) {
		b = sendreceivecommand(conn, BOOTLOADER_CMD_WAITREADY, NULL, 0, 1000);

		if (NULL==b)
			return -1;

		status = b->buf[1];

		buffer_free(b);
	} else {
		// Programmer does not know about ATMEL flash types.
		unsigned char wbuf[5];

		do {
			wbuf[0] = 0; // Tx bytes
			wbuf[1] = 1; // Tx bytes
			wbuf[2] = 0; // Rx bytes
			wbuf[3] = 1; // Rx bytes
			wbuf[4] = 0x57;

			b = sendreceivecommand(conn, BOOTLOADER_CMD_RAWREADWRITE, wbuf, sizeof(wbuf), 1000);
			if (NULL==b)
				return -1;

			status = b->buf[3];
		} while (!(status&0x80));

		buffer_free(b);
	}
    return status;
}

static int atmel_erase_sector(flash_info_t *flash, connection_t conn, unsigned int sector)
{
	buffer_t *b;
	unsigned char wbuf[8];

	wbuf[0] = 0; // Tx bytes
	wbuf[1] = 4; // Tx bytes
	wbuf[2] = 0; // Rx bytes
	wbuf[3] = 0; // Tx bytes

	wbuf[4] = 0x50; // Block erase.
	sector<<=12;

	wbuf[5] = (sector>>16) & 0xff;
	wbuf[6] = (sector>>8) & 0xff;
	wbuf[7] = (sector) & 0xff;

	b = sendreceivecommand(conn, BOOTLOADER_CMD_RAWREADWRITE, wbuf, sizeof(wbuf), 1000);
	if (NULL==b)
		return -1;

	buffer_free(b);

	if (atmel_wait_ready(conn)<0)
		return -1;

	return 0;
}

static int atmel_enable_writes(flash_info_t *flash, connection_t conn)
{
	return 0;
}

static buffer_t *atmel_read_page(flash_info_t *flash, connection_t conn, unsigned int page)
{
	unsigned int addr = page << 9;//* flash->pagesize;
	unsigned char wbuf[9];
	buffer_t *b;

	atmel_wait_ready(conn);

	wbuf[0] = 0;
	wbuf[1] = 5; // Tx bytes

	wbuf[2] = flash->pagesize >> 8; // Rx bytes
	wbuf[3] = flash->pagesize & 0xff;

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

static int atmel_program_page(flash_info_t *flash, connection_t conn, unsigned int page, const unsigned char *buf,size_t size)
{
	unsigned char *wbuf;
	unsigned int addr = page << 9;//* flash->pagesize;
	buffer_t *b;

    wbuf = malloc( flash->pagesize + 8);

    unsigned short txsize = flash->pagesize + 4;

	wbuf[0] = txsize>>8;
	wbuf[1] = txsize&0xff;
	wbuf[2] = 0;
    wbuf[3] = 0;

	wbuf[4] = 0x84; // Load data into buffer 1
	wbuf[5] = 0;
	wbuf[6] = 0;
	wbuf[7] = 0;

	memcpy(&wbuf[8], buf, size);

	b = sendreceivecommand(conn, BOOTLOADER_CMD_RAWREADWRITE, wbuf, 8 + flash->pagesize, 5000);

	if (NULL==b) {
		fprintf(stderr,"Cannot write page buffer!\n");
		free(wbuf);
		return -1;
	}

	buffer_free(b);

	wbuf[4] = 0x88; // Write buffer to memory
	wbuf[5] = (addr >> 16) & 0xff;
	wbuf[6] = (addr >> 8) & 0xff;
	wbuf[7] = (addr) & 0xff;

	//memcpy(&wbuf[8], buf, size);

	b = sendreceivecommand(conn, BOOTLOADER_CMD_RAWREADWRITE, wbuf, 8, 5000);

	if (NULL==b) {
		fprintf(stderr,"Cannot program page\n");
		free(wbuf);
		return -1;
	}

	buffer_free(b);
	free(wbuf);

	if (atmel_wait_ready(conn)<0)
		return -1;

	return 0;
}

flash_driver_t atmel_flash = {
	.erase_sector  = &atmel_erase_sector,
	.enable_writes = &atmel_enable_writes,
	.read_page     = &atmel_read_page,
	.program_page  = &atmel_program_page
};
