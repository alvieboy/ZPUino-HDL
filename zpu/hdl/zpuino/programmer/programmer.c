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

#include <stdio.h>
#include <sys/time.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
#include "flash.h"
#include "transport.h"
#include "programmer.h"
#include <unistd.h>

#ifdef __linux__
#include <sys/un.h>
#include <sys/socket.h>
#include <errno.h>
#include <termios.h>
#include <sys/ioctl.h>
#include <sys/select.h>
#endif

unsigned int verbose = 0;

static char *binfile=NULL;
static char *serialport=NULL;
static int is_simulator=0;
static int only_read=0;
static int ignore_limit=0;
static int upload_only=0;
static int user_offset=-1;
static speed_t serial_speed = DEFAULT_SPEED;
static int dry_run = 0;
static int serial_reset = 0;

unsigned short version;

extern void crc16_update(uint16_t *crc, uint8_t data);

unsigned short get_programmer_version()
{
	return version;
}


int parse_arguments(int argc,char **const argv)
{
	int p;
	while (1) {
		switch ((p=getopt(argc,argv,"RDvb:d:ro:ls:U"))) {
		case '?':
			return -1;
		case 'v':
			verbose++;
			break;
		case 's':
			if (conn_parse_speed(optarg,&serial_speed)<0)
				return -1;
			break;
		case 'b':
			binfile = optarg;
			break;
		case 'r':
			only_read=1;
			break;
		case 'R':
			serial_reset=1;
			break;
		case 'l':
			ignore_limit=1;
			break;
		case 'D':
			dry_run=1;
			break;
		case 'o':
			user_offset=atoi(optarg);
			break;
		case 'd':
			serialport = optarg;
			if (strncmp(serialport,"socket:",7)==0)
				is_simulator=1;
			break;
		case 'U':
			upload_only=1;
			break;
		default:
			return 0;
		}
	}
}

int help(char *name)
{
	printf("Usage: %s -d <serialdevice> [OPTIONS]\n",name);
	printf("\nOptions:\n");
	printf("  -r\t\tPerform only sector read (use with -o)\n");
	printf("  -D\t\tDry-run. Don't actually do anything\n");
	printf("  -o offset\tUse specified offset within flash\n");
	printf("  -b binfile\tBinary file to program\n");
	printf("  -l\t\tIgnore programming limit sent by bootloader\n");
	printf("  -R\t\tPerform serial reset before programming\n");
    printf("  -U\t\tUpload only, do not program flash\n");
	printf("  -s speed\tUse specified serial port speed (default: 1000000)\n");
	printf("  -v\t\tIncrease verbosity\n");
	return -1;
}

buffer_t *handle();
buffer_t *process(unsigned char *buffer, size_t size);

int set_baudrate(connection_t conn, speed_t baud)
{
	/* Request new baudrate */
    buffer_t *b;
	unsigned char txbuf;
	int retries = 30;
	speed_t speed;
#ifdef WIN32
	txbuf = 1;
	speed = 250000;
#else
	txbuf = 2;
	speed = 1000000;
#endif

	sendreceive(conn,&txbuf,1,300);
	conn_set_speed(conn, speed);

	while (retries>0) {
		/* Reset */
		conn_prepare(conn);
		if (verbose>2) {
			printf("Connecting at new speed...\n");
		}
		b = sendreceivecommand(conn,BOOTLOADER_CMD_VERSION,NULL,0,200);
		if (b)
			break;
		retries--;
	}
	if (b) {
		buffer_free(b);
		return -1;
	}
	return 0;
}


static buffer_t *sendreceivecommand_i(connection_t fd, unsigned char cmd, unsigned char *txbuf, size_t size, int timeout, int validate)
{
	//unsigned char tmpbuf[32];
	//struct timeval tv;
	//int rd;
	buffer_t *ret=NULL;
	unsigned char *txbuf2;
	//int retries=3;


	txbuf2=malloc( size + 1);
	txbuf2[0] = cmd;
	if (size) {
		memcpy(&txbuf2[1], txbuf,size);
	}
	do {
		ret = conn_transmit(fd,txbuf2,size+1,timeout);
		if (NULL==ret)
			return ret;

		if (ret->buf[0] != REPLY(cmd)) {
			if (verbose>0) {
				printf("Invalid reply 0x%02x to command 0x%02x\n",
					   ret->buf[0],REPLY(cmd));
			}
			buffer_free(ret);
		} else {
			return ret;
		}
	} while(1);
}

buffer_t *sendreceivecommand(connection_t conn, unsigned char cmd, unsigned char *txbuf, size_t size, int timeout)
{
	return sendreceivecommand_i(conn,cmd,txbuf,size,timeout,1);
}

buffer_t *sendreceive(connection_t conn, unsigned char *txbuf, size_t size, int timeout)
{
	return sendreceivecommand_i(conn,txbuf[0],txbuf+1,size-1,timeout,0);
}



int open_simulator_device(const char *device,connection_t *conn)
{
#ifndef __linux__
	return -1;
#else
	struct sockaddr_un sock;
	char *dstart;
	int s;

	dstart=strchr(device,':');
	if (NULL==dstart)
		return -1;
	dstart++;

	memset(&sock,0,sizeof(sock));
	sock.sun_family=AF_UNIX;
	strcpy( &sock.sun_path[1], dstart );

	s = socket(AF_UNIX, SOCK_SEQPACKET, 0);
	if (s<0)
		return s;

	if (connect(s, (struct sockaddr*)&sock,sizeof(sock))<0) {
		perror("Cannot connect");
		return -1;
	}
	fcntl(s, F_SETFL, fcntl(s, F_GETFL) |O_NONBLOCK);
	*conn =  s;
	return 0;
#endif
}

int open_device(char *device,connection_t *conn)
{
	if (is_simulator)
		return open_simulator_device(device,conn);
	else
		return conn_open(device,serial_speed,conn);
}


void buffer_free(buffer_t *b)
{
	if (b) {
		if (b->buf)
			free(b->buf);
		free(b);
	}
}
/*
static int flash_read_status(fd)
{
	buffer_t *b;
	unsigned char wbuf[6];
	wbuf[0] = BOOTLOADER_CMD_RAWREADWRITE;
	wbuf[1] = 0; // Tx bytes
	wbuf[2] = 1; // Tx bytes
	wbuf[3] = 0; // Rx bytes
	wbuf[4] = 1; // Rx bytes
	wbuf[5] = 0x05; // Read status register

	b = sendreceive(fd, wbuf, sizeof(wbuf), 30000);
	if (NULL==b)
		return -1;

	buffer_free(b);
	return 0;
}
*/
void dump_buffer(unsigned char *start,size_t size)
{
	unsigned int i;
	for (i=0;i<size;i++) {
		printf("%02x ", start[i]);
	}
	printf("\n");
}

int read_flash(connection_t conn, flash_info_t *flash, size_t page)
{
	buffer_t *b = flash->driver->read_page(flash,conn,page);

	if (verbose>0)
		printf("Reading page nr %d (offset 0x%08x)\n",page,page*flash->pagesize);
	if (b) {
		unsigned int i;
		for (i=3;i<b->size;i++) {
			printf("%02x ", b->buf[i]);
		}
        printf("\n");
		buffer_free(b);
	}
	return 0;
}

int do_upload(connection_t conn)
{
	struct stat st;
	const unsigned int blocksize=512;
	unsigned char dbuf[blocksize + 4];
	unsigned int address = 0x1000;
	int fin;
	unsigned int size;

	if (binfile) {
		fin = open(binfile,O_RDONLY);
		if (fin<0) {
			perror("Cannot open input file");
			return -1;
		}

		// STAT

		fstat(fin,&st);
		size = st.st_size;
	} else {
		fprintf(stderr,"Cannot upload without a binary file\n");
		return -1;
	}

	if (verbose>0) {
		printf("Uploading sketch, %d bytes\n",size);
	}

	do {
		unsigned int blk = size>blocksize?blocksize:size;

		if (read(fin,dbuf + 4, blk)<0)
		{
			perror("read");
			return -1;
		}
		dbuf[0] = address>>8;
		dbuf[1] = address&0xff;
		dbuf[2] = blk>>8;
		dbuf[3] = blk & 0xff;

		buffer_t *b = sendreceivecommand(conn, BOOTLOADER_CMD_PROGMEM, dbuf, 512 + 4, 500 );
		if (b==NULL) {
			fprintf(stderr,"Error programming memory\n");
			close(fin);
			return -1;
		}
		size-=blk;
	} while (size);
	close(fin);
	return 0;

}

int main(int argc, char **argv)
{
	unsigned char buffer[8192];
	uint32_t spioffset;
	uint32_t spioffset_page;
	uint32_t spioffset_sector;
	uint32_t codesize;
	struct timeval start,end,delta;
	connection_t conn;

	flash_info_t *flash;
	int retries;

	unsigned int size_bytes=0;
	unsigned int pages=0;
	unsigned char *buf=NULL;

	struct stat st;
	buffer_t *b;

#ifdef WIN32
	char **winargv;
	char *win_command_line = GetCommandLine();
	argc = makeargv(win_command_line,&winargv);
    /*
	printf("ARGC: %d\n",argc);
	{
		int i;
		for (i=0;i<argc;i++) {
			printf("ARGV %d: '%s'\n",i, winargv[i]);
		}
	}
    */
	if (parse_arguments(argc,winargv)<0) {
		return help(winargv[0]);
	}

#else

	if (parse_arguments(argc,argv)<0) {
		return help(argv[0]);
	}

#endif

	setvbuf(stderr,0,_IONBF,0);
	setvbuf(stdout,0,_IONBF,0);

	if ((NULL==binfile&&only_read==0) || NULL==serialport) {
		return help(argv[0]);
	}

	if (open_device(serialport,&conn)<0) {
		fprintf(stderr,"Could not open port, exiting...\n");
		return -1;
	}
	retries = 10;

	if (serial_reset) {
		conn_reset(conn);
	} else {
		fprintf(stderr,"Press RESET now\n");
	}
	while (retries>0) {
		/* Reset */
		conn_prepare(conn);
		if (verbose>2) {
			printf("Connecting...\n");
		}
		b = sendreceivecommand(conn,BOOTLOADER_CMD_VERSION,NULL,0,200);
		if (b)
			break;
		retries--;
	}

	if (b) {
		if (verbose>0)
			printf("Got programmer version %u.%u\n",b->buf[1],b->buf[2]);

		version = ((unsigned short)b->buf[1]<<8) | b->buf[2];

		spioffset = b->buf[3];
		spioffset<<=8;
		spioffset += b->buf[4];
		spioffset<<=8;
		spioffset += b->buf[5];

		if (verbose>0)
			printf("SPI offset: %u\n",spioffset);

		codesize = b->buf[6];
		codesize<<=8;
		codesize += b->buf[7];
		codesize<<=8;
		codesize += b->buf[8];

		if (verbose>0)
			printf("CODE size: %u\n",codesize);

	} else {
		fprintf(stderr,"Cannot get programmer version, aborting\n");
		conn_close(conn);
		return -1;
	}

	buffer_free(b);

	/* Upload only does not care about flash chips */
	if (!upload_only) {

		gettimeofday(&start,NULL);

		if (user_offset>=0) {
			printf("Using user-specified offset 0x%08x\n",user_offset);
			spioffset=user_offset;
		}

		b = sendreceivecommand(conn,BOOTLOADER_CMD_IDENTIFY,buffer,0,1000);

		if (b) {
			if (verbose>0)
				printf("SPI flash information: 0x%02x 0x%02x 0x%02x, status 0x%02x\n", b->buf[1],b->buf[2],b->buf[3],b->buf[4]);

			/* Find flash */
			flash = find_flash(b->buf[1],b->buf[2],b->buf[3]);

			if (NULL==flash) {
				fprintf(stderr,"Unknown flash type, exiting\n");
				conn_close(conn);
				buffer_free(b);
				return -1;
			}
			if (verbose>0)
				printf("Detected %s flash\n", flash->name);
		} else {
			fprintf(stderr,"Cannot identify flash\n");
			conn_close(conn);
			return -1;
		}

		/* Align offset */
		spioffset_page = spioffset / flash->pagesize;
		spioffset_sector = spioffset / flash->sectorsize;

		if (verbose>0) {
			printf("Will program sector %d (page %d), original offset 0x%08x\n", spioffset_sector,spioffset_page,spioffset);
		}

		/* Ensure SPI offset is aligned */
		if (!only_read) {
			if (spioffset % flash->pagesize!=0) {
				fprintf(stderr,"Cannot program flash on non-page boundaries!\n");
				conn_close(conn);
				return -1;
			}
			if (spioffset % flash->sectorsize!=0) {
				fprintf(stderr,"Cannot program flash on non-sector boundaries!\n");
				conn_close(conn);
				return -1;
			}
		}

		buffer_free(b);

		// Get file
		if (binfile) {
			int fin = open(binfile,O_RDONLY);
			if (fin<0) {
				perror("Cannot open input file");
				return -1;
			}

			// STAT

			fstat(fin,&st);

			unsigned binsize = st.st_size;

			if (version>0x0104 && user_offset==-1) {
				// Add placeholders for size and CRC
				binsize += sizeof(uint32_t);
			}

			size_bytes = ALIGN(binsize,flash->pagesize);
			pages = size_bytes/flash->pagesize;

			unsigned int aligned_toword_size = ALIGN(st.st_size,sizeof(uint32_t));
			unsigned int size_words = aligned_toword_size/sizeof(uint32_t);

			if (verbose>0)
				printf("Need to program %u %u bytes (%d pages)\n",
					   (unsigned) binsize,
					   size_bytes,
					   pages);

			/* Ensure there's enough space */
			if (ignore_limit) {
				printf("Ignoring space limit for programming\n");

			} else {
				if (aligned_toword_size > codesize) {
					fprintf(stderr,"Cannot program file: it's %u bytes, limit is %u\n",
							(unsigned)aligned_toword_size,codesize);
					conn_close(conn);
					close(fin);
					return -1;
				}
			}

			buf = calloc(1,size_bytes);

			unsigned char *bufp = buf;

			if (version>0x0104 && user_offset==-1) {
				// Move pointer up, so we can write sketchsize and CRC
				bufp += sizeof(uint32_t);
			}

			if(verbose>2) {
				fprintf(stderr,"Reading data, %lu bytes\n",st.st_size);
			}

			read(fin,bufp,st.st_size);
			close(fin);

			// Compute checksum if needed

			if (version>0x0104 && user_offset==-1) {
				uint16_t *sketchsize = (uint16_t*)buf;
				uint16_t *crc = (uint16_t*)(buf+sizeof(uint16_t));
				uint16_t tcrc = 0xffff;

				unsigned i;

				if(verbose>2) {
					fprintf(stderr,"Computing sketch CRC (%i)\n", aligned_toword_size);
				}

				*sketchsize = cpu_to_le16(size_words);
				// Go, compute cksum
				for (i=0;i<aligned_toword_size;i++) {
					crc16_update(&tcrc,bufp[i]);
					if(verbose>3 && (i%32)==0) {
						fprintf(stderr,"CRC: %d %04x\n", i, tcrc);
					}
				}
				if(verbose>2) {
					fprintf(stderr,"Final CRC: %04x\n",tcrc);
				}
				*crc = cpu_to_le16(tcrc);
			}
		}
	}
	// Switch to correct baud rate
	set_baudrate(conn,serial_speed);

	if (upload_only) {
		int r = do_upload(conn);
		conn_close(conn);
		return r;
	}

	// compute sector erase

	unsigned int sectors = ALIGN(size_bytes,flash->sectorsize) / flash->sectorsize;
	unsigned int saddr = spioffset_sector;
	if(verbose>2) {
		fprintf(stderr,"Entering program mode\n");
	}
	b = sendreceivecommand(conn, BOOTLOADER_CMD_ENTERPGM, NULL,0, 1000 );
	if (b) {
		buffer_free(b);
	} else {
		fprintf(stderr,"Cannot enter program mode\n");
		conn_close(conn);
		return -1;
	}

	if (only_read) {
		return read_flash(conn,flash,spioffset/flash->pagesize);
	}

	if (verbose>0) {
		printf("Need to erase %d sectors\n",sectors);
	}

	while (sectors--) {
		if (!dry_run)
			if (flash->driver->enable_writes(flash,conn)<0)
				return -1;

		if (verbose>0) {
			printf("Erasing sector %d at 0x%08x...\r",saddr, saddr*flash->sectorsize);
			fflush(stdout);
		}

		if (!dry_run && flash->driver->erase_sector(flash, conn, saddr)<0) {
			fprintf(stderr,"\nSector erase failed!\n");
			return -1;
		}


		saddr++;
	}

	if (verbose>0)
		printf("\ndone.\n");

	//exit(0);

	saddr = spioffset_page;
	unsigned char *sptr = buf;

	while (pages--) {
		if (!dry_run)
			if (flash->driver->enable_writes(flash,conn)<0) {
				fprintf(stderr,"Cannot enable writes ?\n");
				return -1;
			}

		if (verbose>0) {
			printf("Programing page %d at 0x%08x\r",saddr, saddr * flash->pagesize);
			fflush(stdout);
		}

		if (!dry_run)
			if (flash->driver->program_page(flash, conn, saddr, sptr,flash->pagesize)<0) {
				fprintf(stderr,"\nCannot program page!\n");
				return -1;
			}

		sptr+=flash->pagesize;

		saddr++;
	}

	if (verbose>0)
		printf("\ndone. Verifying...\n");

	pages = size_bytes/flash->pagesize;
	sptr = buf;
	saddr = spioffset_page;

	if (dry_run) {
		if (verbose>0)
			printf("Skipping verification due to dry run\n");
	} else {
		while (pages--) {
			if (verbose>0) {
				printf("Verifying page %d at 0x%08x...\r",saddr, saddr * flash->pagesize);
				fflush(stdout);
			}
			b = flash->driver->read_page(flash, conn, saddr);

			if (NULL==b) {
				fprintf(stderr,"\nCannot read page?\n");
				return -1;
			}

			if (memcmp(sptr,&b->buf[3], flash->pagesize)!=0) {
				fprintf(stderr,"\nVerification failed at 0x%08x!\n",saddr * flash->pagesize);
				// Dump
				dump_buffer(&b->buf[3], flash->pagesize);
				dump_buffer(sptr, flash->pagesize);

				pages=0;
			}

			buffer_free(b);
			sptr+=flash->pagesize;
			saddr++;
		}
		if (verbose>0)
			printf("\nVerification done.\n");
	}

	b = sendreceivecommand(conn, BOOTLOADER_CMD_LEAVEPGM, NULL,0, 1000 );
	if (b) {
		buffer_free(b);
	} else {
		fprintf(stderr,"Cannot leave program mode");
		conn_close(conn);
		return -1;
	}
	conn_close(conn);

	gettimeofday(&end,NULL);
#ifdef __linux__
	timersub(&end,&start,&delta);
#else
	delta.tv_sec = end.tv_sec - start.tv_sec;
	delta.tv_usec = end.tv_usec - start.tv_usec;
	if (delta.tv_usec<0) {
		delta.tv_sec-=1;
		delta.tv_usec += 1000000;
	}
#endif

	printf("Programming completed successfully in %.02f seconds.\n", (double)delta.tv_sec + (double)delta.tv_usec/1000000.0);

#ifdef WIN32
	freemakeargv(argv);
#endif

	return 0;
}
