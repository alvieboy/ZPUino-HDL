#include <stdio.h>
#include <termios.h>
#include <sys/ioctl.h>
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

static unsigned char *packet;
static size_t packetoffset;
static int syncSeen=0;
static int unescaping=0;
static unsigned int verbose = 0;
static char *binfile=NULL;
static char *serialport=NULL;


int parse_arguments(int argc,char **const argv)
{
	while (1) {
		switch (getopt(argc,argv,"vb:d:")) {
		case '?':
			return -1;
		case 'v':
			verbose++;
			break;
		case 'b':
			binfile = optarg;
			break;
		case 'd':
			serialport = optarg;
            break;
		default:
			return 0;
		}
	}
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

	tv.tv_sec = timeout / 1000;
	tv.tv_usec = (timeout % 1000) * 1000;

	txbuf2=malloc( size + 1);
	txbuf2[0] = cmd;
	if (size) {
		memcpy(&txbuf2[1], txbuf,size);
	}
    sendpacket(fd,txbuf2,size+1);

	FD_ZERO(&rfs);
	FD_SET(fd, &rfs);

	do {
		switch (select(fd+1,&rfs,NULL,NULL,&tv)) {
		case -1:
			return NULL;
		case 0:
			// Timeout

			return NULL;
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


int open_device(char *device)
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

	cfsetospeed(&termset,B115200);
	cfsetispeed(&termset,B115200);

	tcsetattr(fd,TCSANOW,&termset);

	ioctl(fd, TIOCMGET, &status); 

	status |= ( TIOCM_DTR | TIOCM_RTS );

	ioctl(fd, TIOCMSET, &status);
	fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) |O_NONBLOCK);

	return fd;

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

int help(char *name)
{
	printf("Usage: %s -d <serialdevice> -b <binaryfile> [-v]\n",name);
}
int main(int argc, char **argv)
{
	unsigned char buffer[8192];
	uint32_t spioffset;
	uint32_t spioffset_page;
	uint32_t spioffset_sector;
	uint32_t codesize;
	flash_info_t *flash;
	int retries;

	struct stat st;
	buffer_t *b;
	int cnt;

	if (parse_arguments(argc,argv)<0) {
		return help(argv[0]);
	}

	if (NULL==binfile || NULL==serialport) {
        return help(argv[0]);
	}

	int fd = open_device(serialport);
	if (fd<0) {
		return -1;
	}

	retries = 100;
	fprintf(stderr,"Press RESET now\n");

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

	b = sendreceivecommand(fd,BOOTLOADER_CMD_IDENTIFY,buffer,0,1000);

	if (b) {
		if (verbose>0)
			printf("SPI flash information: 0x%02x 0x%02x 0x%02x, status 0x%02x\n", b->buf[1],b->buf[2],b->buf[3]);

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
	spioffset_page = spioffset % flash->pagesize;
	spioffset_sector = spioffset % flash->sectorsize;

	/* Ensure SPI offset is aligned */
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


	buffer_free(b);

	// Get file
	int fin = open(binfile,O_RDONLY);
	if (fin<0) {
		perror("Cannot open input file");
		return -1;
	}

	// STAT

	fstat(fin,&st);

	unsigned int size_bytes = ALIGN(st.st_size,flash->pagesize);
	unsigned int pages = size_bytes/flash->pagesize;

	if (verbose>0)
		printf("Need to program %d %d bytes (%d pages)\n",st.st_size,size_bytes,pages);

	/* Ensure there's enough space */
	if (st.st_size > codesize) {
		fprintf(stderr,"Cannot program file: it's %u bytes, limit is %u\n", st.st_size,codesize);
		close(fd);
		close(fin);
		return -1;
	}

	unsigned char *buf = malloc(size_bytes);
	read(fin,buf,size_bytes);
	close(fin);

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

	while (sectors--) {
		if (flash->driver->enable_writes(fd)<0)
			return -1;
		if (verbose>0)
			printf("Erasing sector at 0x%08x\r",saddr);
		if (flash->driver->erase_sector(fd, saddr)<0) {
			fprintf(stderr,"\nSector erase failed!\n");
			return -1;
		}
		saddr++;
	}
	fprintf(stderr,"\n");

	// program

	saddr = spioffset_page;
	unsigned char *sptr = buf;

	while (pages--) {
		if (flash->driver->enable_writes(fd)<0)
			return -1;
		if (verbose>0)
			fprintf(stderr,"Programing page at 0x%08x\r",saddr * flash->pagesize);
		if (flash->driver->program_page(fd, saddr, sptr,flash->pagesize)<0) {
			fprintf(stderr,"\nCannot program page!\n");
			return -1;
		}
		sptr+=flash->pagesize;
		saddr++;
	}

	if (verbose>0)
		printf("\nVerifying...\n");

	pages = size_bytes/flash->pagesize;
	sptr = buf;
	saddr = spioffset_page;

	while (pages--) {
		b = flash->driver->read_page(fd, saddr);

		if (NULL==b) {
			fprintf(stderr,"Cannot read page?\n");
			return -1;
		}

		if (memcmp(sptr,&b->buf[3], flash->pagesize)!=0) {
			fprintf(stderr,"Verification failed!\n");
		}

		buffer_free(b);
		sptr+=flash->pagesize;
		saddr++;
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
	printf("\nProgramming complete.\n");

	return 0;
}
