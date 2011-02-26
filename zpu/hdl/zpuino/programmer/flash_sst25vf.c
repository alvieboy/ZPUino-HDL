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

static int sst25vf_erase_sector(flash_info_t *flash, connection_t conn, unsigned int sector)
{
	buffer_t *b;
	unsigned char wbuf[8];

	wbuf[0] = 0; // Tx bytes
	wbuf[1] = 4; // Tx bytes
	wbuf[2] = 0; // Rx bytes
	wbuf[3] = 0; // Tx bytes

	sector *= 4096;

	wbuf[4] = 0x20; // Sector erase
	wbuf[5] = (sector>>16) & 0xff;
	wbuf[6] = (sector>>8) & 0xff;
	wbuf[7] = (sector) & 0xff;

	b = sendreceivecommand(conn, BOOTLOADER_CMD_WAITREADY, NULL, 0, 30000);

	if (NULL==b)
		return -1;

	buffer_free(b);

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


#define SST_STATUS_BUSY 1
#define SST_STATUS_WEL  2
#define SST_STATUS_BP0  4
#define SST_STATUS_BP1  8
#define SST_STATUS_BP2  16
#define SST_STATUS_BP3  32
#define SST_STATUS_AAI  64
#define SST_STATUS_BPL  128

static int sst25vf_enable_writes(flash_info_t *flash, connection_t conn)
{
	buffer_t *b;
	unsigned char wbuf[6];
	unsigned char status;
	unsigned char newstatus;

	// Read status first

	b = sendreceivecommand(conn, BOOTLOADER_CMD_WAITREADY, NULL, 0, 1000);

	if (NULL==b)
		return -1;

	status = newstatus = b->buf[1];

	// Check for protection bits

	if (status & SST_STATUS_BP0 ||
		status & SST_STATUS_BP1 ||
		status & SST_STATUS_BP2 ||
		status & SST_STATUS_BP3) {

//		printf("Flash is protected\n");
		if (status & SST_STATUS_BPL) {
			fprintf(stderr,"Cannot disable flash protection bits, aborting\n");
			return -1;
		}
		newstatus &= !(SST_STATUS_BP0|SST_STATUS_BP1|SST_STATUS_BP2|SST_STATUS_BP3);
	}

	buffer_free(b);

	if (status ^ newstatus) {

		// Enable write new status register

		wbuf[0] = 0;
		wbuf[1] = 1; // Tx bytes
		wbuf[2] = 0;
		wbuf[3] = 0; // Rx bytes
		wbuf[4] = 0x50; // Enable Write status register
		b = sendreceivecommand(conn, BOOTLOADER_CMD_RAWREADWRITE, wbuf, 5, 1000);
		if (NULL==b)  {
			fprintf(stderr,"Cannot write enable status register ??\n");
			return -1;
		}
		buffer_free(b);

		// Write status register
		wbuf[0] = 0;
		wbuf[1] = 2; // Tx bytes
		wbuf[2] = 0;
		wbuf[3] = 0; // Rx bytes
		wbuf[4] = 0x01; // Write status register
		wbuf[5] = newstatus;
		//printf("Sending new status %02x\n",newstatus);
		b = sendreceivecommand(conn, BOOTLOADER_CMD_RAWREADWRITE, wbuf, 6, 1000);
		if (NULL==b)  {
			fprintf(stderr,"Cannot write status register ??\n");
			return -1;
		}
		buffer_free(b);

		b = sendreceivecommand(conn, BOOTLOADER_CMD_WAITREADY, NULL, 0, 1000);

		if (NULL==b)
			return -1;

		/*
		 status = b->buf[1];
		 printf("New status: %02x\n",status);
         */
		buffer_free(b);
	}

	if (!(status & SST_STATUS_WEL)) {
		wbuf[0] = 0;
		wbuf[1] = 1; // Tx bytes
		wbuf[2] = 0;
		wbuf[3] = 0; // Rx bytes
		wbuf[4] = 0x06; // Enable Write

		b = sendreceivecommand(conn, BOOTLOADER_CMD_RAWREADWRITE, wbuf, 5, 1000);

		if (NULL==b) {
			fprintf(stderr,"Cannot enable write???\n");
			return -1;
		}
		buffer_free(b);
	}

	// Ensure WEL is up

	b = sendreceivecommand(conn, BOOTLOADER_CMD_WAITREADY, NULL, 0, 1000);

	if (NULL==b)
		return -1;

	if (b->buf[1]&SST_STATUS_WEL)
		return 0;

	fprintf(stderr,"Could not enable writes!\n");
	return -1;
}

static buffer_t *sst25vf_read_page(flash_info_t *flash, connection_t conn, unsigned int page)
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

extern unsigned short version;


static int sst25vf_program_page_aai(connection_t conn, unsigned int page, const unsigned char *buf,size_t size)
{
	unsigned char wbuf[256 + 5];
	unsigned int addr = page * 256;
	buffer_t *b;

	if (size!=256)
		return -1;

	wbuf[0] = 0x01;
	wbuf[1] = 0x00; // 256 bytes

	wbuf[2] = (addr >> 16) & 0xff;
	wbuf[3] = (addr >> 8) & 0xff;
	wbuf[4] = (addr) & 0xff;

	memcpy( &wbuf[5], buf, size);

	b = sendreceivecommand(conn, BOOTLOADER_CMD_SSTAAIPROGRAM, wbuf, sizeof(wbuf), 5000);

	if (NULL==b) {
		fprintf(stderr,"Cannot program page\n");
		return -1;
	}

	buffer_free(b);

	return 0;
}

static int sst25vf_program_page(flash_info_t *flash, connection_t conn, unsigned int page, const unsigned char *buf,size_t size)
{
	unsigned char wbuf[256 + 8];
	unsigned int addr = page * 256;
	buffer_t *b;
	unsigned int psize = 6;
	//int status;

	if (size!=256)
		return -1;


	if (version>=0x0102)
		return sst25vf_program_page_aai(conn,page,buf,size);

	wbuf[0] = 0x00;
	wbuf[1] = psize;
	wbuf[2] = 0;
	wbuf[3] = 0;

	wbuf[4] = 0xAD; // AAI programming
	wbuf[5] = (addr >> 16) & 0xff;
	wbuf[6] = (addr >> 8) & 0xff;
	wbuf[7] = (addr) & 0xff;

	do {
		size-=2;

		memcpy(&wbuf[ 4 + psize - 2 ], buf, 2);

		b = sendreceivecommand(conn, BOOTLOADER_CMD_RAWREADWRITE, wbuf, psize + 4, 5000);

		if (NULL==b) {
			fprintf(stderr,"Cannot program page\n");
			return -1;
		}

		buffer_free(b);
        /*
		do {
			status = sst25vf_get_status(fd);
			if (status==-1)
				return -1;
		} while (status & SST_STATUS_BUSY);
        */
		psize = 3;
		wbuf[1] = psize; // 2 bytes at a time

		buf+=2;

	} while (size);

	// Disable AAI

	wbuf[0] =0 ;
	wbuf[1] =1 ;
	wbuf[2] =0 ;
	wbuf[3] =0 ;
	wbuf[4] =0x4 ;

	b = sendreceivecommand(conn,BOOTLOADER_CMD_RAWREADWRITE,wbuf,5,1000);
	if (NULL==b)
		return -1;
	buffer_free(b);

	return 0;
}


flash_driver_t sst25vf_flash = {
	.erase_sector  = &sst25vf_erase_sector,
	.enable_writes = &sst25vf_enable_writes,
	.read_page     = &sst25vf_read_page,
	.program_page  = &sst25vf_program_page
};
