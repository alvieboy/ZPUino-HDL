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
int mapfd;
size_t mapped_size;
const char *binfile=NULL;
unsigned spi_select_pin = 40;

#define FLASH_SIZE_BYTES ((1*1024*1024)/8)

#define READ_FAST 0x0B
#define IDENTIFY 0x9F
#define READ_STATUS 0x05
#define WRITE_ENABLE 0x06
#define SECTOR_ERASE 0xD8
#define PAGE_PROGRAM 0x02

int spiflash_mapbin(const char *name)
{
	struct stat st;
	unsigned char sig[8];

	mapfd = open(name,O_RDWR);
	if (mapfd<0) {
		perror("open");
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
		fprintf(stderr,"Sketch size: %u\n", st.st_size);
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

		d = (unsigned char*)mapped;
		d+=2;

		*((unsigned short*)d) = htons(crc16_read_data(0x0));
		printf("Wrote sketch file (0x%04x words, %04x CRC)\n",
				ntohs( *((unsigned short*)(&mapped[0])) ),
				ntohs( *((unsigned short*)(&mapped[2])))

			   );
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
		mapped_size=st.st_size;

		mapped = (unsigned char *)mmap(NULL, mapped_size,PROT_READ|PROT_WRITE,MAP_SHARED,mapfd,0);
		if (NULL==mapped) {
			perror("mmap");
			close(mapfd);
			return -1;
		}
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
	//	fprintf(stderr,"Reading address 0x%08x\n",savereg);
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
		printf("SPI: erasing sector at %06x\n",savereg&0xffffff);
		state = COMMAND;
		break;
	case PAGE_PROGRAM:
		//printf("SPI write: %06x\n",savereg);
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
		printf("SPI select\n");
		state=COMMAND;
	}
	selected=1;
}

void spiflash_deselect()
{
	if (selected)
		printf("SPI deselected\n");
	state = COMMAND;
	selected=0;
}

void spiflash_write(unsigned int v)
{
	v&=0xff;
//	fprintf(stderr,"SPI write: 0x%02x, state %d\n",v,state);
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
			state = SHIFT1;
			break;
		case PAGE_PROGRAM:
			state = SHIFT1;
			break;
		default:
			fprintf(stderr,"Invalid SPI command 0x%02x\n",v);
			//abort();
		}
		break;

	case SHIFT1:
		shiftin(v);
		if (cmd==IDENTIFY)
			shiftout(0x20);
		else if (cmd==READ_STATUS)
			shiftout(0x2);
		state = SHIFT2;
		break;
	case SHIFT2:
		shiftin(v);
		if (cmd==IDENTIFY)
			shiftout(0x20);
		state = SHIFT3;
		break;

	case SHIFT3:
		shiftin(v);
		if (cmd==IDENTIFY)
			shiftout(0x15);

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
	//fprintf(stderr,"SPI read, returning 0x%08x\n", r);
	return r;
}

void spi_write_ctrl(unsigned int address,unsigned int val)
{
}

void spi_write_data(unsigned int address,unsigned int val)
{
	spiflash_write(val);
}

unsigned spi_io_read_handler(unsigned address)
{
	MAPREGR(0,spi_read_ctrl);
#ifdef NEWSPIMULTISIZE
	MAPREGR(4,spi_read_data);
#else
	MAPREGR(1,spi_read_data);
#endif
	ERRORREG();
	return 0;
}

void spi_io_write_handler(unsigned address, unsigned value)
{
	MAPREGW(0,spi_write_ctrl);
#ifdef NEWSPIMULTISIZE
	MAPREGW(4,spi_write_data);
#else
	MAPREGW(1,spi_write_data);
#endif
	ERRORREG();
}

int initialize_device(int argc, char **argv)
{
	fprintf(stderr,"SPI Init, %d\n",argc);
	int i;
	for (i=0;i<argc;i++) {
		char *k = argv[i];
		char *v = makekeyvalue(k);
		if (strcmp(k,"binfile")==0) {
			binfile=v;
		}
	}

	if (binfile) {
		if (spiflash_mapbin(binfile)<0) {
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
	fprintf(stderr,"SPI select %d\n",value);
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

zpuino_device_t *get_device() {
    return &dev;
}
