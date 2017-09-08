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
#include <math.h>
#include "boards.h"
#include "hdlc.h"

#ifdef __linux__
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <sys/socket.h>
#include <errno.h>
#include <termios.h>
#include <sys/ioctl.h>
#include <sys/select.h>

#define O_BINARY 0
#endif

#define SKETCHSIGNATURE 0x310AFADE

unsigned int verbose = 0;

static char *binfile=NULL;
static char *extradata=NULL;
static char *serialport=NULL;
static int is_simulator=0;
static int unprotect_flash=0;
static int only_read=0;
static int verify=0;
static int ignore_limit=0;
static int upload_only=0;
static int user_offset=-1;
static int32_t max_speed=-1;
static flash_info_t custom_flash;
static speed_t serial_speed = DEFAULT_SPEED;
static speed_t initial_serial_speed = DEFAULT_INITIAL_SPEED;
static unsigned int serial_speed_int = 0;
static int dry_run = 0;
static int serial_reset = 0;

unsigned short version;

static unsigned int size_bytes=0;
static unsigned int pages=0;
static uint32_t spioffset;
static uint32_t spioffset_page;
static uint32_t spioffset_sector;
static uint32_t codesize;
static unsigned int board;

static uint32_t supported_ops = 0;
const char *custom_flash_name="Custom Flash";

extern void crc16_update(uint16_t *crc, uint8_t data);

unsigned short get_programmer_version()
{
	return version;
}

int parse_int(const char *data, unsigned int *target)
{
    unsigned long l;
    char *endp;
    l = strtoul(data,&endp,0);
    if (data==NULL || (*endp)!='\0')
        return -1;
    *target = l;
    return 0;
}

static int parse_custom_flash(const char *const_info)
{
    if (custom_flash.driver!=NULL) {
        /* Already set up */
        fprintf(stderr,"Custom flash driver already specified!");
        return -1;
    }
    char *info = strdup(const_info);

    // Split args. Format is:
    // m25p_flash:0x6E:0x00:0x16:256:65536:128
    char *toks[7];
    unsigned i = 0;
    toks[i++] = strtok(info,":");
    while ((toks[i]=strtok(NULL,":"))!=NULL) {
        i++;
        if (i>7)
            break;
    }
    if (i!=7) {
        fprintf(stderr,"Invalid number of arguments %d for custom flash (-F) option\n",
                i);
        return -1;
    }
    // Find driver
    flash_driver_t *driver;
    driver = find_flash_driver(toks[0]);

    if (driver==NULL) {
        fprintf(stderr,"Flash driver '%s' not found\n", toks[0]);
    }

    i=1;

    if (parse_int(toks[i],&custom_flash.manufacturer)!=0) {
        printf("Invalid manufacturer code '%s'\n", toks[i]);
        return -1;
    }
    i++;

    if (parse_int(toks[i],&custom_flash.product)!=0) {
        printf("Invalid product code '%s'\n", toks[i]);
        return -1;
    }
    i++;

    if (parse_int(toks[i],&custom_flash.density)!=0) {
        printf("Invalid density '%s'\n", toks[i]);
        return -1;
    }
    i++;

    if (parse_int(toks[i],&custom_flash.pagesize)!=0) {
        printf("Invalid page size '%s'\n", toks[i]);
        return -1;
    }
    i++;

    if (parse_int(toks[i],&custom_flash.sectorsize)!=0) {
        printf("Invalid sector size '%s'\n", toks[i]);
        return -1;
    }
    i++;
    if (parse_int(toks[i],&custom_flash.totalsectors)!=0) {
        printf("Invalid total sectors '%s'\n", toks[i]);
        return -1;
    }
    i++;
    custom_flash.name = custom_flash_name;
    return 0;
}

int parse_arguments(int argc,char **const argv)
{
	unsigned spd;
	int p;

	while (1) {
            switch ((p=getopt(argc,argv,"PRDvtb:d:re:o:ls:S:UF:"))) {
		case '?':
			return -1;
		case 'v':
			verbose++;
			break;
		case 't':
			verify=1;
			break;
		case 's':
			serial_speed_int = atoi(optarg);
			if (conn_parse_speed(serial_speed_int,&serial_speed)<0)
				return -1;
			break;
		case 'S':
			spd = atoi(optarg);
			if (conn_parse_speed(spd,&initial_serial_speed)<0)
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
		case 'P':
			unprotect_flash=1;
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
		case 'e':
			extradata = optarg;
			break;
		case 'U':
			upload_only=1;
                        break;
            case 'F':
                if ( parse_custom_flash(optarg) <0)
                    return -1;
                break;

                default:
			return 0;
		}
	}
}

void comms_error()
{
	fprintf(stderr,"Cannot get programmer version, aborting\n");
	fprintf(stderr,"\nCould not contact ZPUino embedded programmer.\n");
	fprintf(stderr,"Most common reasons for this error are:\n\n");
	fprintf(stderr,"a) You are not specifying the correct port. The port currently selected is '%s'\n",
		serialport);
	fprintf(stderr,"b) The FPGA board is not programmed with a valid ZPUino bitfile.\n");
	fprintf(stderr,"c) The board is not properly powered.\n");
	fprintf(stderr,"\nPlease review all of above - if problem persists please contact support.\n");

}

int help(char *name)
{
	printf("This is ZPUino programmer, version " VERSION "\n\n");
	printf("Usage: %s -d <serialdevice> [OPTIONS]\n",name);
	printf("\nOptions:\n");
	printf("  -r\t\tPerform only sector read (use with -o)\n");
	printf("  -D\t\tDry-run. Don't actually do anything\n");
	printf("  -o offset\tUse specified offset within flash\n");
	printf("  -b binfile\tBinary file to program\n");
	printf("  -e datafile\tData file to program after binary\n");
	printf("  -l\t\tIgnore programming limit sent by bootloader\n");
	printf("  -R\t\tPerform serial reset before programming\n");
	printf("  -U\t\tUpload only, do not program flash\n");
	printf("  -t\t\tTest/verify flash after programming\n");
        printf("  -s speed\tUse specified serial port speed (default: 1000000, auto fallback)\n");
        printf("  -S speed\tUse specified initial serial port speed (default: 115200)\n");
        printf("  -F finfo\tUse specified custom flash info\n");
        printf("  -P unProtect flash before programming\n");
        printf("  -v\t\tIncrease verbosity\n\n");
        printf("For custom flash info (option -F) you will have to provide\n"
               "information regarding the flash chip using the following format:\n"
               "  driver:vid:pid:density:pagesize:sectorsize:totalsectors\n"
               "Example: \n"
               "  micron:0x6E:0x00:0x16:256:65536:128\n"
               ),

        list_flash_drivers();
	return -1;
}

buffer_t *handle();
buffer_t *process(unsigned char *buffer, size_t size);

static char errorbuffer[128];

const char *get_error_as_string(unsigned char c)
{
    switch (c) {
    case 0xff:
        sprintf(errorbuffer,"Unspecified error");
        break;
    case 0x01:
        sprintf(errorbuffer,"Sector is protected");
        break;
    default:
        sprintf(errorbuffer,"Unknown error 0x%02x",(unsigned)c);
        break;
    }
    return errorbuffer;
}


int set_baudrate(connection_t conn, unsigned int baud_int, unsigned int freq, int max_speed)
{
	/* Request new baudrate */
	buffer_t *b;
	unsigned int divider;
	unsigned char txbuf[4];
	int retries = 30;
	speed_t speed;

        if (baud_int==0) {
            /* Automatic baud rate selection */
            unsigned int *baudrates = conn_get_baudrates();
            while (*baudrates) {
                baud_int = *baudrates;

                if ((max_speed>0) && (baud_int>max_speed))
                    continue;

                divider = ((freq/baud_int)/16)-1;
                unsigned int real_baud =  (freq/16)/(divider+1);
                unsigned int real_baud2 =  (freq/16)/(divider+2);

                /* Check error */
                double error = fabs(100.0 - (double)baud_int/((double)real_baud/100.0));
                double error2 = fabs(100.0 - (double)baud_int/((double)real_baud2/100.0));

                if (error<3.0) {
                    printf("Using baudrate %d (error %f%%)\n", baud_int, error);
                    break;
                } else if (error2<3.0) {
                    divider++;
                    printf("Using baudrate %d (error %f%%)\n", baud_int, error2);
                    break;
                } else {
                    if (verbose>2) {
                        printf("Skipping baudrate %d: error is %f%% %f%% (%d %d)\n", baud_int, error,error2,
                               real_baud, real_baud2);
                    }
                }
                baudrates++;
            }
        } else {
            /* TODO: also do computation based on error here */
            if ((max_speed>0) && (baud_int>max_speed)) {
                fprintf(stderr,"Cannot set baudrate of %d (maximum is %d)\n", baud_int, max_speed);
                return -1;
            }

            divider = ((freq/baud_int)/16)-1;
        }

	txbuf[0] = divider>>24;
	txbuf[1] = divider>>16;
	txbuf[2] = divider>>8;
        txbuf[3] = divider;


        if (verbose>1) {
		printf("Settting baudrate divider to %u\n",divider);
	}
	b = sendreceivecommand(conn,BOOTLOADER_CMD_SETBAUDRATE, txbuf,4,500);
	if (b)
		buffer_free(b);

        conn_parse_speed(baud_int,&speed);
	conn_set_speed(conn, speed);

	while (retries>0) {
		/* Reset */
		conn_prepare(conn);
		if (verbose>2) {
			printf("Connecting at new speed (%u)...\n",baud_int);
		}
		b = sendreceivecommand(conn,BOOTLOADER_CMD_VERSION,NULL,0,500);
		if (b)
			break;
		retries--;
	}
	if (b) {
		buffer_free(b);
		return 0;
	}
	return -1;
}


static buffer_t *sendreceivecommand_i(connection_t fd, unsigned char cmd,
                                      unsigned char *txbuf, size_t size, int timeout, int validate)
{
    buffer_t *ret=NULL;
    unsigned char *txbuf2;

    txbuf2 = malloc( size + 1 );
    txbuf2[0] = cmd;
    if (size>0) {
        memcpy(&txbuf2[1], txbuf,size);
    }
    do {
        ret = conn_transmit(fd,txbuf2,size+1,timeout);

        if (NULL==ret) {
            free(txbuf2);
            return ret;
        }

        if (ret->buf[0] != REPLY(cmd)) {
            if (verbose>0) {
                printf("Invalid reply 0x%02x to command 0x%02x\n",
                       ret->buf[0],REPLY(cmd));
            }
            buffer_free(ret);
        } else {
            // Advance it past control field. Already done.
            //ret->buf++;
            free(txbuf2);
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
	struct sockaddr_in sock;
	char *dstart;
	char *pstart;
	int s;
	int yes=1;

	dstart=strchr(device,':');
	if (NULL==dstart)
		return -1;
	dstart++;

	pstart=strchr(dstart,'/');
	if (NULL==pstart)
		return -1;
	*pstart=0;
	pstart++;

	if (strcmp(dstart,"tcp")!=0) {
		fprintf(stderr,"Invalid protocol '%s'. Only 'tcp' is supported\n", dstart);
		return -1;
	}

	memset(&sock,0,sizeof(sock));
	sock.sin_family=AF_INET;
	sock.sin_port=htons(atoi(pstart));

	//strcpy( &sock.sun_path[1], dstart );

	s = socket(AF_INET, SOCK_STREAM,IPPROTO_TCP);
	if (s<0)
		return s;

	if (connect(s, (struct sockaddr*)&sock,sizeof(sock))<0) {
		perror("Cannot connect");
		return -1;
	}
	fcntl(s, F_SETFL, fcntl(s, F_GETFL) |O_NONBLOCK);
	setsockopt(s, SOL_SOCKET, TCP_NODELAY, &yes,sizeof(yes));
	*conn =  s;
	conn_setsimulator(1);
	return 0;
#endif
}

int open_device(char *device,connection_t *conn)
{
	if (is_simulator)
		return open_simulator_device(device,conn);
	else
		return conn_open(device,initial_serial_speed,conn);
}


void buffer_free(buffer_t *b)
{
	if (b) {
            if (b->abuf)
                free(b->abuf);
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

#define UPLOAD_BLOCK_SIZE 255

int do_upload(connection_t conn, const
			  unsigned char *buf)
{
	/*struct stat st;
	const unsigned int blocksize=512;
	unsigned char dbuf[4];
	unsigned int address = 0x1000;
	int fin;
	unsigned int size,pos;
	unsigned char *prog;
    
	*/

	unsigned int address = 0x0000;
	unsigned char dbuf[ UPLOAD_BLOCK_SIZE + 5 ];
	unsigned int to_go = size_bytes;
	const unsigned char *source;
	buffer_t *b = NULL;

	if (NULL==buf) {
		fprintf(stderr,"Nothing to upload!\n");
		return -1;
	}

	source = &buf[4]; // Skip board ID + CRC

	b = sendreceivecommand(conn, BOOTLOADER_CMD_ENTERPGM, NULL,0, 1000 );

	if (NULL==b) {
		fprintf(stderr,"Cannot enter programming mode\n");
		return -1;
	}

	buffer_free(b);

	while (to_go) {
		unsigned bsize = to_go > UPLOAD_BLOCK_SIZE ? UPLOAD_BLOCK_SIZE : to_go;
		dbuf[0] = (address>>24)&0xff;
		dbuf[1] = (address>>16)&0xff;
		dbuf[2] = (address>>8)&0xff;
		dbuf[3] = (address)&0xff;

		dbuf[4] = bsize & 0xff;

		memcpy( &dbuf[5], source, bsize);
		if (verbose>1)
			printf("Sending %d bytes, address 0x%08x\n",bsize,address);
		b = sendreceivecommand(conn, BOOTLOADER_CMD_PROGMEM, dbuf, 5 + bsize, 0 );
		if (NULL==b) {
			fprintf(stderr,"Error programming memory\n");
			return -1;
		}
		buffer_free(b);
		source+=bsize;
		to_go -= bsize;
		address+=bsize;
	}
	if (verbose>1) {
		printf("Starting sketch\n");
	}
	b = sendreceivecommand(conn,BOOTLOADER_CMD_START,dbuf,0,5000);
	if (NULL==b)
		return -1;
	buffer_free(b);

	return 0;
}

static unsigned char *load_binfile(flash_info_t *flash)
{
	unsigned char *buf=NULL;
	struct stat st,est;

	int fin = open(binfile,O_RDONLY|O_BINARY);
	if (fin<0) {
		perror("Cannot open input file");
		return NULL;
	}

	int ein=-1;
	if (extradata) {
		ein = open(extradata,O_RDONLY|O_BINARY);
		if (ein<0) {
			perror("Cannot open extra input file");
			return NULL;
		}
		//fprintf(stderr,"Loaded extra data file\n");
	}

	// STAT

	fstat(fin,&st);
	if (ein>0) {
		fstat(ein,&est);
	}

	unsigned binsize = st.st_size;
	unsigned realbinsize = st.st_size;

	if (ein>0) {
		binsize += est.st_size;
	}

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
			close(fin);
			return NULL;
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
	if (ein>0) {
		/*fprintf(stderr,"Loading extra %d bytes at 0x%08x\n",
		 est.st_size,
		 bufp+st.st_size);
		 */
		read(ein,bufp+st.st_size, est.st_size);
	}

	/* Validate sketch */
	if (version > 0x0106 && user_offset == -1)
	{
		uint32_t p = bufp[0]<<24 |
			bufp[1]<<16 |
			bufp[2]<<8 |
			bufp[3];

		if (p != SKETCHSIGNATURE) {
			fprintf(stderr,"File '%s' does not appear to be a sketch: 0x%08x != 0x%08x", binfile,
					p, SKETCHSIGNATURE);
			close(fin);
			return NULL;
		}

		/* Validate board */
		p = bufp[4]<<24 |
			bufp[5]<<16 |
			bufp[6]<<8 |
			bufp[7];

		if (p != board) {
			fprintf(stderr,"Board mismatch!!!.\n");
			const char *b1 = getBoardById(board);
			fprintf(stderr,"Board is:      0x%08x '%s'\n", board,b1);
			b1 = getBoardById(p);
			fprintf(stderr,"Sketch is for: 0x%08x '%s'\n", p,b1);
			close(fin);
			return NULL;
		}
	}

	// Compute checksum if needed

	if (version>0x0104 && user_offset==-1) {
		uint8_t *sketchsize = &buf[0];
		uint8_t *crc = &buf[2];
		uint16_t tcrc = 0xffff;

		unsigned i;

		if(verbose>1) {
			fprintf(stderr,"Computing sketch CRC (%i)\n", aligned_toword_size);
		}
		sketchsize[0] = (size_words>>8) & 0xff;
		sketchsize[1] = size_words & 0xff;

		// Go, compute cksum
		for (i=0;i<aligned_toword_size;i++) {
			crc16_update(&tcrc,bufp[i]);
			if(verbose>3 && (i%32)==0) {
				fprintf(stderr,"CRC: %d %04x\n", i, tcrc);
			}
		}
		if(verbose>1) {
			fprintf(stderr,"Final CRC: %04x\n",tcrc);
		}
		crc[0] = (tcrc>>8) & 0xff;
		crc[1] = tcrc & 0xff;
	}
	return buf;
}

uint32_t get_supported_ops()
{
    return supported_ops;
}

int is_op_supported(unsigned char op)
{
    return !!( supported_ops & (1<<op) );
}



int main(int argc, char **argv)
{
    unsigned char buffer[8192];
    uint32_t extrasize = 0;
    unsigned char *buf=NULL;
    int success=1;

    uint32_t freq;
    struct timeval start,end,delta, erase_end, erase_delta, program_delta;
    connection_t conn;

    flash_info_t *flash;
    int retries;


    struct stat st, est;
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
        retries = 1000;
    }
    // Link up
    if (verbose>2) {
        printf("Connecting...\n");
    }
    main_setup(conn);

    if (hdlc_connect(conn, retries)<0) {
        comms_error();
        conn_close(conn);
        return -1;
    }

    printf("Connected. Contacting bootloader.\n");

    while (retries>0) {
        /* Reset */
        conn_prepare(conn);
        if (verbose>2) {
            printf("Connecting...\n");
        }
        b = sendreceivecommand(conn,BOOTLOADER_CMD_VERSION,NULL,0,500);
        if (b)
            break;
        retries--;
    }

    if (b) {

        if (verbose>0)
            printf("Got programmer version %u.%u\n",b->buf[1],b->buf[2]);

        version = ((unsigned short)b->buf[1]<<8) | b->buf[2];

        version = ((unsigned short)b->buf[1]<<8) | b->buf[2];
        if (b->buf[1]<2) {
            printf("Incompatible bootloader. Only versions >= 2.0 are supported by this programmer.");
            conn_close(conn);
            return -1;
        }
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
        if (version>=0x0106) {
            freq = b->buf[9];
            freq<<=8;
            freq += b->buf[10];
            freq<<=8;
            freq += b->buf[11];
            freq<<=8;
            freq += b->buf[12];
            //printf("CPU frequency: %u Hz\n",freq);
        }
        if (verbose>0) {
            printf("CODE size: %u\n",codesize);
        }

        if (version>=0x0107) {
            const char *boardname;
            board = b->buf[13];
            board<<=8;
            board += b->buf[14];
            board<<=8;
            board += b->buf[15];
            board<<=8;
            board += b->buf[16];

            boardname = getBoardById(board);
            printf("Board: %s @ %u Hz (0x%08x)\n", boardname, freq, board);
        }
        if (b->size > 24) {
            supported_ops = ((uint32_t)b->buf[21])<<24;
            supported_ops += ((uint32_t)b->buf[22])<<16;
            supported_ops += ((uint32_t)b->buf[23])<<8;
            supported_ops += ((uint32_t)b->buf[24]);
            if (verbose>2) {
                printf("Supported ops: 0x%08x\n", supported_ops);
            }
        } else {
            // Default ops: up to BOOTLOADER_CMD_START
            supported_ops = ((1<<BOOTLOADER_CMD_START) -1) ^ 0x1;
        }
        if (b->size > 28) {
            max_speed =  ((uint32_t)b->buf[25])<<24;
            max_speed += ((uint32_t)b->buf[26])<<16;
            max_speed += ((uint32_t)b->buf[27])<<8;
            max_speed += ((uint32_t)b->buf[28]);
            if (verbose>2) {
                printf("Max speed: %dbps\n", max_speed);
            }
            max_speed=-1;
        } else {
            // Default ops: up to BOOTLOADER_CMD_START
            max_speed = -1;
        }
    } else {
        comms_error();
        conn_close(conn);
        return -1;
    }

    buffer_free(b);

    gettimeofday(&start,NULL);
#if 0
    /* Upload only does not care about flash chips */
    if (!upload_only) {

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

//        buffer_free(b);

    } else {
        /* We still need a "dummy" flash driver for direct upload */
        flash = find_flash(0xAA,0xAA,0xAA);
    }
#endif

//    buffer_free(b);

//    gettimeofday(&start,NULL);

    if(unprotect_flash) {
        if (verbose>2) {
            fprintf(stderr,"Unprotecting flash\n");
        }
        b = sendreceivecommand(conn, BOOTLOADER_CMD_UNLOCK, NULL,0, 1000 );
        if (b) {
            buffer_free(b);
        } else {
            fprintf(stderr,"Cannot enter program mode\n");
            conn_close(conn);
            return -1;
        }

    }

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

    /* Upload only does not care about flash chips */
    if (!upload_only) {

        if (user_offset>=0) {
            printf("Using user-specified offset 0x%08x\n",user_offset);
            spioffset=user_offset;
        }

        b = sendreceivecommand(conn,BOOTLOADER_CMD_IDENTIFY,buffer,0,1000);

        if (b) {
            if (verbose>0)
                printf("SPI flash information: 0x%02x 0x%02x 0x%02x, status 0x%02x\n", b->buf[1],b->buf[2],b->buf[3],b->buf[4]);
            flash = NULL;
            /* Find flash */
            if (custom_flash.driver) {
                if ( (custom_flash.manufacturer == b->buf[1]) &&
                    (custom_flash.product == b->buf[2]) &&
                    (custom_flash.density == b->buf[3])) {
                    flash = &custom_flash;
                }
            } else {
                flash = find_flash(b->buf[1],b->buf[2],b->buf[3]);
            }
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
    } else {
        /* We still need a "dummy" flash driver for direct upload */
        flash = find_flash(0xAA,0xAA,0xAA);
    }

    // Get file
    if (binfile) {
        buf = load_binfile(flash);
        if (NULL==buf) {
            conn_close(conn);
            return -1;
        }
    }


    // Switch to correct baud rate
    if (set_baudrate(conn,serial_speed_int,freq,max_speed)<0) {
        fprintf(stderr,"No suitable baudrate found, aborting\n");
        conn_close(conn);
        return -1;
    }

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

    if (upload_only) {
        int r = do_upload(conn, buf);
        conn_close(conn);
        // make this better
        if (r!=0)
            success=0;
        goto report_out;
    }

    // compute sector erase

    unsigned int sectors = ALIGN(size_bytes,flash->sectorsize) / flash->sectorsize;
    unsigned int saddr = spioffset_sector;

    /* Ensure all data will fit on flash */
    if (saddr + sectors > flash->totalsectors) {
        fprintf(stderr,"Sorry, data will not fit on flash.\n");
        fprintf(stderr,"Total sectors are %d, and we need %d\n", flash->totalsectors,
                saddr+sectors);
        conn_close(conn);
        return -1;
    }


    if (only_read) {
        return read_flash(conn,flash,spioffset/flash->pagesize);
    }

    if (verbose>0) {
        printf("Need to erase %d sectors\n",sectors);
    }

    if (flash->driver->erase_range != NULL) {
        printf("Erasing sector ranges %d to %d...\r",saddr, saddr+sectors-1);
        fflush(stdout);
        if (!dry_run) {
            if (flash->driver->erase_range(flash,conn, saddr, sectors)<0)
                return -1;
        }
    } else {
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
    }

    if (verbose>0)
        printf("\ndone.\n");

    gettimeofday(&erase_end, NULL);

    //exit(0);

    saddr = spioffset_page;
    unsigned char *sptr = buf;

    while (pages--) {
#if 0
        if (!dry_run) {
            if (flash->driver->enable_writes(flash,conn)<0) {
                fprintf(stderr,"Cannot enable writes ?\n");
                return -1;
            }
        }
#endif
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

    if (verbose>0) {
        if (verify)
            printf("\ndone. Verifying...\n");
        else
            printf("\ndone.\n");

    }

    pages = size_bytes/flash->pagesize;
    sptr = buf;
    saddr = spioffset_page;

    if (dry_run) {
        if (verbose>0)
            printf("Skipping verification due to dry run\n");
    } else if (verify) {
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
                success=0;
                pages=0;
            }

            buffer_free(b);
            sptr+=flash->pagesize;
            saddr++;
        }
        if (verbose>0)
            printf("\nVerification done.\n");
    }

    b = sendreceivecommand(conn, BOOTLOADER_CMD_LEAVEPGM, NULL,0, 5000 );
    if (b) {
        buffer_free(b);
    } else {
        fprintf(stderr,"Cannot leave program mode");
        conn_close(conn);
        return -1;
    }
    conn_close(conn);

report_out:
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

    // Get erase delta

#ifdef __linux__
    timersub(&erase_end,&start,&erase_delta);
#else
    erase_delta.tv_sec = erase_end.tv_sec - start.tv_sec;
    erase_delta.tv_usec = erase_end.tv_usec - start.tv_usec;
    if (erase_delta.tv_usec<0) {
        erase_delta.tv_sec-=1;
        erase_delta.tv_usec += 1000000;
    }
#endif

#ifdef __linux__
    timersub(&end,&erase_end,&program_delta);
#else
    program_delta.tv_sec = end.tv_sec - erase_end.tv_sec;
    program_delta.tv_usec = end.tv_usec - erase_end.tv_usec;
    if (program_delta.tv_usec<0) {
        program_delta.tv_sec-=1;
        program_delta.tv_usec += 1000000;
    }
#endif


    printf("%s completed %s in %.02f seconds (%.02fs erase, %.02fs program)\n",

           upload_only?"Upload":"Programming",
           success?"successfully":"WITH ERRORS",
           (double)delta.tv_sec + (double)delta.tv_usec/1000000.0,
           (double)erase_delta.tv_sec + (double)erase_delta.tv_usec/1000000.0,
           (double)program_delta.tv_sec + (double)program_delta.tv_usec/1000000.0
          );
#ifdef WIN32
    //freemakeargv(argv);
#endif

    return 0;
}
