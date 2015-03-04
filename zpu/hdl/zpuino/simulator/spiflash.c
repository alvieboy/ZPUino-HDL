#include "spiflash.h"
#include <inttypes.h>
#include <stdio.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include "crc16.h"
#include <netinet/in.h>
#include "zpuinointerface.h"
#include "gpio.h"
#include <errno.h>

flash_info_t flash_list[] =
{
	{ 0x20, 0x20, 0x15, 256, 65536, 32, "M25P16"},
	{ 0xBF, 0x25, 0x8D, 256, 4096, 128, "SST25VF040B"},
	{ 0x1F, 0x25, 0x00, 264, 2112, 512, "AT45DB081D"},
	{ 0, 0, 0, 0, 0, 0, NULL }
};

flash_info_t *currentflash = &flash_list[1];

typedef enum {
	COMMAND,
	SHIFT1,
	SHIFT2,
	SHIFT3,
	SHIFT4,
	SHIFT5,
	PROCESS
} state_t;

static state_t state;
int selected;
unsigned int outreg;
unsigned int inreg;
unsigned int savereg;
static uint8_t cmd;
unsigned char *mapped;
unsigned char *mapped_orig;
int mapfd;
size_t mapped_size;
const char *binfile=NULL;
const char *extrafile=NULL;
unsigned spi_select_pin = 40;

static int in_aai_mode=0;

#define FLASH_SIZE_BYTES ((4*1024*1024)/8)

#define READ_FAST 0x0B
#define SST_DISABLE_WREN 0x04
#define IDENTIFY 0x9F
#define READ_STATUS 0x05
#define WRITE_ENABLE 0x06
#define SECTOR_ERASE 0xD8
#define SST_SECTOR_ERASE 0x20
#define PAGE_PROGRAM 0x02
#define SST_AAI_PROGRAM 0xAD

//#define FLASHID 0xBF258D

int spiflash_mapbin(const char *name, const char *extra)
{
	struct stat st;
	unsigned char sig[8];

	mapfd = open(name,O_RDWR);
	if (mapfd<0) {
		fprintf(stderr,"SPI: cannot open '%s': %s\n",
				name, strerror(errno));
		return -1;
	}
	if (fstat(mapfd,&st)<0) {
		perror("stat");
		close(mapfd);
		return -1;
	}

	// Peek at flash.

	if (read(mapfd,sig,sizeof(sig))<sizeof(sig)) {
		perror("read");
		close(mapfd);
		return -1;
	}

	if (memcmp(sig,"ZPUFLASH",8)!=0) {
		unsigned char c;
		unsigned char *end;

		lseek(mapfd,0,SEEK_SET);
		fprintf(stderr,"File %s is not a flash file, emulating in memory\n", name);

		//mapped = (unsigned char *)mmap(NULL, FLASH_SIZE_BYTES, PROT_READ|PROT_WRITE, MAP_ANONYMOUS, -1, 0);
        mapped = malloc(FLASH_SIZE_BYTES);
		if (NULL==mapped) {
			perror("mmap");
			close(mapfd);
			return -1;
		}
		mapped_size=FLASH_SIZE_BYTES;


		unsigned char *d = (unsigned char*)mapped;
		fprintf(stderr,"Sketch size: %lu\n", st.st_size);
		d[0] = st.st_size>>10;
		d[1] = st.st_size>>2;

		d+=4;

		// Program flash

		//void crc16_write_data(unsigned int address,unsigned int val);
		crc16_write_poly(0x0, 0x8408);
		crc16_write_data(0x0,0xffff);
		//void crc16_write_accumulate(unsigned int address,unsigned int val);

		while (read(mapfd,&c,1)==1) {
			crc16_write_accumulate(0x0,c);
			*d++=c;
		}

		end = d;

		d = (unsigned char*)mapped;
		d+=2;

		*((unsigned short*)d) = htons(crc16_read_data(0x0));
		printf("Wrote sketch file (0x%04x words, %04x CRC)\n",
			   ntohs( *((unsigned short*)(&mapped[0])) ),
			   ntohs( *((unsigned short*)(&mapped[2])))
			  );

		if (extrafile) {
			/* Append extra file */
			int efd = open(extrafile,O_RDONLY);
			if (efd<0) {
				perror("open");
				return -1;
			}
			fprintf(stderr,"SPI: Reading extra data to address %08x\n", (end-mapped));
			int r = read(efd, end, FLASH_SIZE_BYTES - (end-mapped));
			fprintf(stderr,"SPI: read %d bytes\n",r);
			close(efd);
		}


	} else {


		// Ensure enough space
        /*
		if (st.st_size<FLASH_SIZE_BYTES) {
			if (ftruncate(mapfd,FLASH_SIZE_BYTES)<0) {
				perror("Cannot extend 'flash' ?");
				abort();
			}
			st.st_size=FLASH_SIZE_BYTES;
		}
		*/
		mapped_size=st.st_size - 8;
		if (mapped_size != FLASH_SIZE_BYTES) {
			fprintf(stderr,"Invalid flash file size. Expecting %d, got %d\n",FLASH_SIZE_BYTES,mapped_size);
			return -1;
		}

		mapped_orig = (unsigned char *)mmap(NULL, mapped_size,PROT_READ|PROT_WRITE,MAP_SHARED,mapfd, 0);

		if (MAP_FAILED==mapped) {
			perror("mmap");
			close(mapfd);
			return -1;
		}
		mapped = mapped_orig + 8; // Skip signature

	}
	return 0;
}

static void shiftout(uint8_t val)
{
	outreg<<=8;
	outreg|=val;
}
static void shiftin(uint8_t val)
{
	inreg<<=8;
	inreg|=val;
}

void spi_execute(unsigned int v)
{
	//fprintf(stderr,"Execute %02x\n",cmd);
	savereg &= 0xffffff;

	switch(cmd) {
	case READ_FAST:
		//printf("Reading address 0x%08x\n",savereg);
		if (savereg>mapped_size) {
			fprintf(stderr,"SPI: out of bounds %08x (mapped %08x)\n", savereg, mapped_size);
			shiftout(0);
		}
		else {
			shiftout(mapped[savereg]);
		}
		//fprintf(stderr,"outreg now: 0x%08x\n",outreg);
		savereg++;
		break;
	case SECTOR_ERASE:
    case SST_SECTOR_ERASE:
		printf("SPI: erasing sector at %06x\n",savereg&0xffffff);
		state = COMMAND;
		break;
	case PAGE_PROGRAM:
	case SST_AAI_PROGRAM:
		//printf("SPI write data: %06x <= 0x%02x\n",savereg,v);
        in_aai_mode=1;
		mapped[savereg]=v;
		savereg++;
	}
}

void spiflash_reset()
{
	state=COMMAND;
	selected=0;
}

void spiflash_select()
{
	if (!selected) {
		//printf("SPI select\n");
		state=COMMAND;
	}
	selected=1;
}

void spiflash_deselect()
{
	/*
	 if (selected)
	 printf("SPI deselected\n");
	 */
	state = COMMAND;
	selected=0;
}

void spiflash_write(unsigned int v)
{
	v&=0xff;
	//fprintf(stderr,"SPI write: 0x%02x, state %d\n",v,state);
	switch (state) {
	case COMMAND:
		cmd = v;
		switch(cmd) {
		case READ_FAST:
			state = SHIFT1;
			break;
		case IDENTIFY:
			state = SHIFT1;
			break;
		case READ_STATUS:
			state = SHIFT1;
			break;
		case WRITE_ENABLE:
			state = SHIFT1;
			break;
		case SECTOR_ERASE:
		case SST_SECTOR_ERASE:
			state = SHIFT1;
			break;
		case PAGE_PROGRAM:
			state = SHIFT1;
			break;
		case SST_AAI_PROGRAM:
			if (in_aai_mode) {
				state = PROCESS;
			} else {
				state=SHIFT1;
			}
            break;
		case SST_DISABLE_WREN:
            in_aai_mode=0;
			state = COMMAND;
			break;
		default:
			fprintf(stderr,"Invalid SPI command 0x%02x\n",v);
			//abort();
		}
		break;

	case SHIFT1:
		shiftin(v);
		if (cmd==IDENTIFY)
			shiftout( currentflash->manufacturer );
		else if (cmd==READ_STATUS)
			shiftout(0x2);
		state = SHIFT2;
		break;
	case SHIFT2:
		shiftin(v);
		if (cmd==IDENTIFY)
			shiftout( currentflash->product );
		state = SHIFT3;
		break;

	case SHIFT3:
		shiftin(v);
		if (cmd==IDENTIFY)
			shiftout( currentflash->density );

		state = SHIFT4;
		break;
	case SHIFT4:
		savereg = inreg;
		shiftin(v);
		if (cmd==READ_FAST) {
			state = SHIFT5;
		} else {
			state = PROCESS;
			spi_execute(v);
		}
		break;

	case SHIFT5:
		// Dummy shiftin(v);
		state = PROCESS;
		spi_execute(v);
		break;
	case PROCESS:
		spi_execute(v);

		break;
	}
}

unsigned int spiflash_read()
{
    return outreg;
}


unsigned int spi_read_ctrl(unsigned int address)
{
	return 0;
}

unsigned int spi_read_data(unsigned int address)
{
	unsigned int r = spiflash_read();
	return r;
}

unsigned int spi_read_data16(unsigned int address)
{
	spiflash_read();
	unsigned int r = spiflash_read();
	return r;
}

unsigned int spi_read_data24(unsigned int address)
{
	spiflash_read();
	spiflash_read();
	unsigned int r = spiflash_read();
	return r;
}
unsigned int spi_read_data32(unsigned int address)
{
	spiflash_read();
	spiflash_read();
	spiflash_read();
	unsigned int r = spiflash_read();
	return r;
}

void spi_write_ctrl(unsigned int address,unsigned int val)
{
}

void spi_write_data(unsigned int address,unsigned int val)
{
	spiflash_write(val);
}

void spi_write_data16(unsigned int address,unsigned int val)
{
	spiflash_write(val>>8);
	spiflash_write(val);

}

void spi_write_data24(unsigned int address,unsigned int val)
{
	spiflash_write(val>>16);
	spiflash_write(val>>8);
	spiflash_write(val);
}

void spi_write_data32(unsigned int address,unsigned int val)
{
	spiflash_write(val>>24);
	spiflash_write(val>>16);
	spiflash_write(val>>8);
	spiflash_write(val);
}

unsigned spi_io_read_handler(unsigned address)
{
	MAPREGR(0,spi_read_ctrl);
	MAPREGR(1,spi_read_data);
	MAPREGR(3,spi_read_data16);
	MAPREGR(5,spi_read_data24);
	MAPREGR(7,spi_read_data32);
	ERRORREG();
	return 0;
}

void spi_io_write_handler(unsigned address, unsigned value)
{
	MAPREGW(0,spi_write_ctrl);
	MAPREGW(1,spi_write_data);
	MAPREGW(3,spi_write_data16);
	MAPREGW(5,spi_write_data24);
	MAPREGW(7,spi_write_data32);
	ERRORREG();
}

static zpuino_device_args_t args[] =
{
	{ "binfile", ARG_STRING, &binfile },
	{ "extrafile", ARG_STRING, &extrafile },
	{ "selectpin", ARG_INTEGER, &spi_select_pin },
	ENDARGS
};

static int initialize_device(int argc, char **argv)
{
	zpuino_device_parse_args(args,argc,argv);

	if (binfile) {
		if (spiflash_mapbin(binfile, extrafile)<0) {
			return -1;
		}
	} else {
		fprintf(stderr,"SPI: No binfile specified.!");
		return -1;
	}



	return 0;
}

void spi_select_pin_changed(unsigned pin, int value, void *data)
{
//	fprintf(stderr,"SPI select %d\n",value);
	if (value!=0) {
		spiflash_deselect();
	} else {
		spiflash_select();
	}
}

int spi_post_init()
{
	// Attach to GPIO
	zpuino_device_t *gpiodev = zpuino_get_device_by_name("gpio");
	gpio_class_t *gpioclass;

	if (NULL==gpiodev) {
		fprintf(stderr,"Cannot find device \"gpio\", cannot attach SPI select line");
		return -1;
	}

	gpioclass = gpiodev->class;
	fprintf(stderr,"SPI: using %d as SPI select pin\n", spi_select_pin);
	gpioclass->add_pin_notify( spi_select_pin, &spi_select_pin_changed, NULL );

	return 0;
}

static zpuino_device_t dev = {
	.name = "spi",
	.init = initialize_device,
	.read = spi_io_read_handler,
	.write = spi_io_write_handler,
	.post_init = spi_post_init
};

static void ZPUINOINIT spiflash_init()
{
	zpuino_register_device(&dev);
}
