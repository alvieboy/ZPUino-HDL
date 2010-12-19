#include <stdio.h>
#include <termios.h>
#include <sys/ioctl.h>
#include <sys/time.h>
#include <fcntl.h>
#include <sys/select.h>
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
#endif

static unsigned char *packet;
static size_t packetoffset;
static int syncSeen=0;
static int unescaping=0;
static unsigned int verbose = 0;
static char *binfile=NULL;
static char *serialport=NULL;
static int is_simulator=0;
static int only_read=0;
static int ignore_limit=0;
static int user_offset=-1;
static int serial_speed = B1000000;
static int dry_run = 0;
static int serial_reset = 0;

unsigned short version;

unsigned short get_programmer_version()
{
	return version;
}


static int set_speed(char *value)
{
	int v = atoi(value);
	switch (v) {
	case 1000000:
		serial_speed = B1000000;
		break;
	case 115200:
		serial_speed = B115200;
		break;
	default:
		printf("Baud rate '%s' not supported\n",value);
		return -1;
	}
	return 0;
}

int parse_arguments(int argc,char **const argv)
{
	while (1) {
		switch (getopt(argc,argv,"RDvb:d:ro:ls:")) {
		case '?':
			return -1;
		case 'v':
			verbose++;
			break;
		case 's':
			if (set_speed(optarg)<0)
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
	printf("  -s speed\tUse specified serial port speed (default: 1000000)\n");
	printf("  -v\t\tIncrease verbosity\n");
}

void crc16_update(uint16_t *crc, uint8_t data)
{
	data ^= *crc&0xff;
	data ^= data << 4;
	*crc = ((((uint16_t)data << 8) | ((*crc>>8)&0xff)) ^ (uint8_t)(data >> 4)
		   ^ ((uint16_t)data << 3));
}

void writeEscaped(unsigned char c, unsigned char **dest)
{
	if (c==HDLC_frameFlag || c==HDLC_escapeFlag) {
		*(*dest)=HDLC_escapeFlag;
		(*dest)++;
		*(*dest)=(c ^ HDLC_escapeXOR);
	} else
		*(*dest)=c;
	(*dest)++;
}

int sendpacket(int fd, unsigned char *buffer, size_t size)
{
	unsigned char txbuf[1024];
	unsigned char *txptr = &txbuf[0];

	uint16_t crc = 0xFFFF;
	size_t i;

	*txptr++=HDLC_frameFlag;
	if (verbose>2) {
		printf("Send packet, size %u\n",size);
	}
	for (i=0;i<size;i++) {
		crc16_update(&crc,buffer[i]);
		writeEscaped(buffer[i],&txptr);
	}

	writeEscaped( (crc>>8)&0xff, &txptr);
	writeEscaped( crc&0xff, &txptr);

	*txptr++= HDLC_frameFlag;

	if(verbose>2) {
		printf("Tx:");
		for (i=0; i<txptr-(&txbuf[0]); i++) {
			printf(" 0x%02x", txbuf[i]);
		}
		printf("\n");
	}
	return write(fd, txbuf, txptr-(&txbuf[0]));
}

buffer_t *handle();
buffer_t *process(unsigned char *buffer, size_t size);


static buffer_t *sendreceivecommand_i(int fd, unsigned char cmd, unsigned char *txbuf, size_t size, int timeout, int validate)
{
	fd_set rfs;
	unsigned char tmpbuf[32];
	struct timeval tv;
	int rd;
    buffer_t *ret=NULL;
	unsigned char *txbuf2;
	int retries=3;


	txbuf2=malloc( size + 1);
	txbuf2[0] = cmd;
	if (size) {
		memcpy(&txbuf2[1], txbuf,size);
	}
    sendpacket(fd,txbuf2,size+1);


	do {
		FD_ZERO(&rfs);
		FD_SET(fd, &rfs);
		tv.tv_sec = timeout / 1000;
		tv.tv_usec = (timeout % 1000) * 1000;

		switch (select(fd+1,&rfs,NULL,NULL,&tv)) {
		case -1:
			return NULL;
		case 0:
			// Timeout
			if (!(--retries))
				return NULL;
			else
				// Resend
				sendpacket(fd,txbuf2,size+1);

		default:
			rd = read(fd,tmpbuf,sizeof(tmpbuf));
			if (rd>0) {
				if (verbose>2) {
					int i;
					printf("Rx:");
					for (i=0; i<rd; i++) {
						printf(" 0x%02x",tmpbuf[i]);
					}
					printf("\n");
				}
				ret = process(tmpbuf,rd);
				if (ret) {
					if (!validate) {

						free(txbuf2);
						return ret;
					}
					/* Check return */
					if (ret->size<1) {
						buffer_free(ret);
						free(txbuf2);

						return NULL;
					}
					// Check explicit CRC error
					if (ret->buf[0] == 0xff) {
						/* Resend */
						if (verbose>0) {
							printf("Reported CRC error %02x%02x / %02x%02x\n",
								   ret->buf[1],
								   ret->buf[2],
								   ret->buf[3],
								   ret->buf[4]);
						}
						sendpacket(fd,txbuf2,size+1);
                        continue;
					}

					if (ret->buf[0] != REPLY(cmd)) {
						if (verbose>0) {
							printf("Invalid reply 0x%02x to command 0x%02x\n",
								   ret->buf[0],REPLY(cmd));
						}
						buffer_free(ret);
					}
					free(txbuf2);
					return ret;
				}
			} else {
				if (errno==EINTR || errno==EAGAIN)
					continue;
				fprintf(stderr,"Cannot read from connection (%d) errno %d: %s\n",rd,errno,strerror(errno));
				return NULL;
			}
		}
	} while (1);
}

buffer_t *sendreceivecommand(int fd, unsigned char cmd, unsigned char *txbuf, size_t size, int timeout)
{
	return sendreceivecommand_i(fd,cmd,txbuf,size,timeout,1);
}
buffer_t *sendreceive(int fd, unsigned char *txbuf, size_t size, int timeout)
{
	return sendreceivecommand_i(fd,txbuf[0],txbuf+1,size-1,timeout,0);
}

int open_serial_device(char *device)
{
	struct termios termset;
	int fd;
	int status;

	fd = open(device, O_RDWR|O_NOCTTY|O_NONBLOCK|O_EXCL);
	if (fd<0) {
		perror("open");
		return -1;
	}

	if (verbose>2)
		printf("Opened device '%s'\n", device);

	tcgetattr(fd, &termset);
	termset.c_iflag = IGNBRK;

	termset.c_oflag &= ~OPOST;
	termset.c_lflag &= ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN);
	termset.c_cflag &= ~(CSIZE | PARENB| HUPCL);
	termset.c_cflag |= CS8;
	termset.c_cc[VMIN]=1;
	termset.c_cc[VTIME]=5;

	cfsetospeed(&termset,serial_speed);
	cfsetispeed(&termset,serial_speed);

	tcsetattr(fd,TCSANOW,&termset);

	ioctl(fd, TIOCMGET, &status); 

	status |= ( TIOCM_DTR | TIOCM_RTS );

	ioctl(fd, TIOCMSET, &status);
	fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) |O_NONBLOCK);

	return fd;
}

void do_serial_reset(int fd)
{
	struct termios termset;
	unsigned char reset[] = { 0, 0xFF, 0 };

	tcgetattr(fd, &termset);
	cfsetospeed(&termset,B300);
	cfsetispeed(&termset,B300);
	tcsetattr(fd,TCSANOW,&termset);

	// Send reset sequence

	write(fd, reset,sizeof(reset));
	tcflush(fd, TCOFLUSH);

	// delay a bit. It takes about 80ms to get sequence into board
	usleep(80000);

	cfsetospeed(&termset,serial_speed);
	cfsetispeed(&termset,serial_speed);

	tcsetattr(fd,TCSANOW,&termset);
}


int open_simulator_device(const char *device)
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
	return s;
#endif
}

int open_device(char *device)
{
	if (is_simulator)
		return open_simulator_device(device);
	else
		return open_serial_device(device);
}

buffer_t *handle()
{
    buffer_t*ret = NULL;
	unsigned short crc = 0xFFFF;
    unsigned short pcrc;
	int i;

	if (packetoffset<3) {
		if (verbose>0)
			printf("Short packet\n");
		goto out;
	}

	for (i=0; i<packetoffset-2; i++) {
		crc16_update(&crc,packet[i]);
	}
	pcrc = packet[packetoffset-2] << 8;
    pcrc += packet[packetoffset-1];

	if (crc!=pcrc) {
		if (verbose>0) {
			printf("CRC error, expected 0x%02x, got 0x%02x\n",
				   crc,
				   pcrc);
		}
        goto out;
	}

	ret = malloc(sizeof (buffer_t) );
	if (ret==NULL)
		goto out;

	ret->buf = malloc(packetoffset-2);
	ret->size = packetoffset-2;
	memcpy(ret->buf, packet, ret->size);
	if (verbose>2)
		printf("Got packet size %d\n",ret->size);
out:
	free(packet);
	packet = NULL;
    packetoffset = 0;
    return ret;
}

buffer_t *process(unsigned char *buffer, size_t size)
{
	size_t s;
	unsigned int i;
	for (s=0;s<size;s++) {
		i = buffer[s];

		if (syncSeen) {
			if (i==HDLC_frameFlag) {
				syncSeen=0;
				return handle();

			} else if (i==HDLC_escapeFlag) {
				unescaping=1;
			} else if (packetoffset<1024) {
				if (unescaping) {
					unescaping=0;
					i^=HDLC_escapeXOR;
				}
				packet[packetoffset++]=i;
			} else {
				syncSeen=0;
				free(packet);
				packet = NULL;
			}
		} else {
			if (i==HDLC_frameFlag) {
				packet = malloc(1024);
				packetoffset=0;
				syncSeen=1;
				unescaping=0;
			}
		}
	}
	return NULL;
}

void buffer_free(buffer_t *b)
{
	if (b) {
		if (b->buf)
			free(b->buf);
		free(b);
	}
}

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

void dump_buffer(unsigned char *start,size_t size)
{
	unsigned int i;
	for (i=0;i<size;i++) {
		printf("%02x ", start[i]);
	}
	printf("\n");
}

int read_flash(int fd, flash_info_t *flash, size_t page)
{
	buffer_t *b = flash->driver->read_page(flash,fd,page);

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

int main(int argc, char **argv)
{
	unsigned char buffer[8192];
	uint32_t spioffset;
	uint32_t spioffset_page;
	uint32_t spioffset_sector;
	uint32_t codesize;
	struct timeval start,end,delta;

	flash_info_t *flash;
	int retries;

	struct stat st;
	buffer_t *b;
	int cnt;

	if (parse_arguments(argc,argv)<0) {
		return help(argv[0]);
	}

	if ((NULL==binfile&&only_read==0) || NULL==serialport) {
		return help(argv[0]);
	}

	int fd = open_device(serialport);
	if (fd<0) {
		return -1;
	}

	retries = 100;
	if (serial_reset) {
		do_serial_reset(fd);
	} else {
		fprintf(stderr,"Press RESET now\n");
	}
	while (retries>0) {
		/* Reset */
		buffer[0] = HDLC_frameFlag;
		buffer[1] = HDLC_frameFlag;
		write(fd,buffer,2);

		b = sendreceivecommand(fd,BOOTLOADER_CMD_VERSION,NULL,0,200);
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
		close(fd);
		return -1;
	}

	buffer_free(b);

	gettimeofday(&start,NULL);

	if (user_offset>=0) {
		printf("Using user-specified offset 0x%08x\n",user_offset);
		spioffset=user_offset;
	}

	b = sendreceivecommand(fd,BOOTLOADER_CMD_IDENTIFY,buffer,0,1000);

	if (b) {
		if (verbose>0)
			printf("SPI flash information: 0x%02x 0x%02x 0x%02x, status 0x%02x\n", b->buf[1],b->buf[2],b->buf[3],b->buf[4]);

		/* Find flash */
		flash = find_flash(b->buf[1],b->buf[2],b->buf[3]);

		if (NULL==flash) {
			fprintf(stderr,"Unknown flash type, exiting\n");
			close(fd);
			buffer_free(b);
			return -1;
		}
		if (verbose>0)
			printf("Detected %s flash\n", flash->name);
	} else {
		fprintf(stderr,"Cannot identify flash\n");
		close(fd);
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
			close(fd);
			return -1;
		}
		if (spioffset % flash->sectorsize!=0) {
			fprintf(stderr,"Cannot program flash on non-sector boundaries!\n");
			close(fd);
			return -1;
		}
	}

	unsigned int size_bytes;
	unsigned int pages;
	unsigned char *buf;

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

		size_bytes = ALIGN(st.st_size,flash->pagesize);
		pages = size_bytes/flash->pagesize;

		if (verbose>0)
			printf("Need to program %d %d bytes (%d pages)\n",st.st_size,size_bytes,pages);

		/* Ensure there's enough space */
		if (ignore_limit) {
			printf("Ignoring space limit for programming\n");

		} else {
			if (st.st_size > codesize) {
				fprintf(stderr,"Cannot program file: it's %u bytes, limit is %u\n", st.st_size,codesize);
				close(fd);
				close(fin);
				return -1;
			}
		}

		buf = malloc(size_bytes);
		read(fin,buf,size_bytes);
		close(fin);
	}
	// compute sector erase

	unsigned int sectors = ALIGN(size_bytes,flash->sectorsize) / flash->sectorsize;
	unsigned int saddr = spioffset_sector;

	b = sendreceivecommand(fd, BOOTLOADER_CMD_ENTERPGM, NULL,0, 1000 );
	if (b) {
		buffer_free(b);
	} else {
		fprintf(stderr,"Cannot enter program mode\n");
		close(fd);
		return -1;
	}

	if (only_read) {
		return read_flash(fd,flash,spioffset/flash->pagesize);
	}

	if (verbose>0) {
		printf("Need to erase %d sectors\n",sectors);
	}

	while (sectors--) {
		if (!dry_run)
			if (flash->driver->enable_writes(flash,fd)<0)
				return -1;

		if (verbose>0) {
			printf("Erasing sector at 0x%08x...\r",saddr);
			fflush(stdout);
		}

		if (!dry_run && flash->driver->erase_sector(flash, fd, saddr)<0) {
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
			if (flash->driver->enable_writes(flash,fd)<0) {
				fprintf(stderr,"Cannot enable writes ?\n");
				return -1;
			}

		if (verbose>0) {
			printf("Programing page %d at 0x%08x\r",saddr, saddr * flash->pagesize);
			fflush(stdout);
		}

		if (!dry_run)
			if (flash->driver->program_page(flash, fd, saddr, sptr,flash->pagesize)<0) {
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
			b = flash->driver->read_page(flash, fd, saddr);

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

	b = sendreceivecommand(fd, BOOTLOADER_CMD_LEAVEPGM, NULL,0, 1000 );
	if (b) {
		buffer_free(b);
	} else {
		fprintf(stderr,"Cannot leave program mode");
		close(fd);
		return -1;
	}

	//if (verbose>0)

	gettimeofday(&end,NULL);

	timersub(&end,&start,&delta);

	printf("Programming completed successfully in %.02f seconds.\n", (double)delta.tv_sec + (double)delta.tv_usec/1000000.0);

	return 0;
}
